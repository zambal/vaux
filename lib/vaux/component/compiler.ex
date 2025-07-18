defmodule Vaux.Component.Compiler do
  @moduledoc false

  alias Vaux.Component.Compiler.{Expr, Node, Directive, State}

  @dialyzer {:no_improper_lists, [html_escape: 4, html_escape: 5]}
  @dialyzer {:no_return, raise_error: 2, raise_error: 3}
  @dialyzer {:no_match, concat: 2}
  @compile {:inline, raise_error: 2, raise_error: 3, to_binary: 1}

  @type result :: Macro.t() | [binary() | result()]

  defmacrop maybe_to_binary(expr) do
    if Application.get_env(:vaux, :render_to_binary, true) do
      quote do
        to_binary(unquote(expr))
      end
    else
      quote do
        unquote(expr)
      end
    end
  end

  @spec compile(String.t(), Keyword.t()) :: {result(), [atom()]}
  def compile(string, opts \\ []) do
    env = Keyword.get(opts, :env, %Macro.Env{})
    globals? = Keyword.get(opts, :inject_globals, false)
    string = String.trim(string)

    {:ok, root, _} =
      :vaux_htmerl_sax_utf8.string(string,
        user_state: Node.new("template", [], {env.file, env.line}, env.line),
        event_fun: &handle_event/3,
        fragment_mode: true
      )

    root = maybe_inject_globals(root, env, globals?)

    case compile_node(%State{env: env}, root) do
      %State{stack: [], acc: result, assigns_used: assigns} ->
        {maybe_to_binary(result), assigns}

      %State{stack: stack} ->
        raise Vaux.CompileError,
          file: env.file,
          line: env.line,
          description: "unexpected stack leftover after compile:\n\n#{inspect(stack)}\n"
    end
  end

  @doc false
  def to_binary(chunks) do
    {:<<>>, [], to_binary_parts(chunks)}
  end

  defp to_binary_parts([chunk | rest]) do
    [quote(do: unquote(chunk) :: binary) | to_binary_parts(rest)]
  end

  defp to_binary_parts([]), do: []
  defp to_binary_parts(bin), do: [quote(do: unquote(bin) :: binary)]

  @doc false
  def extract_globals(component, attrs) do
    fun =
      case component.__vaux__(:globals) do
        false ->
          fn _ -> false end

        true ->
          fn {name, _} ->
            name not in component.__vaux__(:fields) and Node.global_attribute?(name)
          end

        {:only, names} ->
          fn {name, _} ->
            name in names and name not in component.__vaux__(:fields) and Node.global_attribute?(name)
          end

        {:except, names} ->
          fn {name, _} ->
            name not in names and name not in component.__vaux__(:fields) and Node.global_attribute?(name)
          end
      end

    Enum.split_with(attrs, fun)
  end

  defp handle_event({:characters, ""}, _line, node) do
    node
  end

  defp handle_event({:characters, string}, line, %Node{env: env} = node) do
    content = Node.new(:characters, [], env, line, string)
    Node.add(node, content)
  end

  defp handle_event({:expr, string}, line, %Node{env: env} = node) do
    content = Node.new(:expr, [], env, line, string)
    Node.add(node, content)
  end

  defp handle_event({:startElement, _, tag, _, attrs}, line, node) do
    Node.new(tag, attrs, node, line)
  end

  defp handle_event({:endElement, _, tag, _}, _line, %Node{tag: tag, parent: parent} = node) do
    Node.add(parent, node)
  end

  defp handle_event(_event, _line, node) do
    node
  end

  defp maybe_inject_globals(%Node{content: [%Node{type: type} = globals_node | rest]} = node, _env, true)
       when type in [:element, :component] do
    %{node | content: [%{globals_node | global_attrs: true} | rest]}
  end

  defp maybe_inject_globals(node, env, globals?) do
    if globals? do
      description = "Global attributes can only be used if the template starts with an element or component"

      IO.warn(description,
        file: env.file,
        line: env.line,
        module: env.module,
        function: {:render, 2}
      )
    end

    node
  end

  defp compile_node(state, node) do
    node = setup_directive(node)
    state |> push_node(node) |> flush_expr()
  end

  defp compile_slot_node(state, %Node{line: line} = node, {:":let", expr_string}) do
    state = %State{stack: [%Expr{} = expr | rest]} = compile_node(state, node)
    {arg, state} = to_unsafe_quoted(expr_string, state.env.file, line, state)

    ast =
      quote do
        fn unquote(arg) -> unquote(maybe_to_binary(expr.ast)) end
      end

    %{state | stack: [%{expr | ast: ast} | rest]}
  end

  defp compile_slot_node(state, node, _) do
    state = %State{stack: [%Expr{} = expr | rest]} = compile_node(state, node)
    expr = %{expr | ast: maybe_to_binary(expr.ast)}
    %{state | stack: [expr | rest]}
  end

  defp setup_directive(%Node{dir: {:":case", string}} = node) do
    content = inject_case(node.content, string)
    %{node | dir: nil, content: content}
  end

  defp setup_directive(node), do: node

  defp push_node(_state, %Node{tag: "template", attrs: [_name], dir: {dir, _}, type: :slot} = node)
       when dir in ~w(:for :clause :else :cond)a do
    raise_error(node, "`#{dir}` can't be used on a named `template` element")
  end

  defp push_node(state, %Node{tag: "template", attrs: [name], type: :slot} = node) do
    temp_state =
      if node.keep do
        state
        |> State.new()
        |> State.concat("</" <> node.tag <> ">")
        |> compile_content(node.content)
        |> State.concat(">")
        |> compile_attributes(node.attrs, node)
        |> State.concat("<" <> node.tag)
      else
        compile_content(State.new(state), node.content)
      end

    expr = Expr.new(temp_state.acc, "template", node.dir, name, node.line)

    state
    |> State.merge_assigns_used(temp_state)
    |> State.push_stack(expr)
  end

  defp push_node(state, %Node{tag: "slot", type: :slot, binding: binding} = node) do
    slot_key =
      case node.attrs do
        [] -> :__slot__
        [key] -> key
      end

    state = State.add_assign(state, slot_key)

    fallback_content = compile_content(State.new(state), node.content)

    {slot, state} =
      case binding do
        {:":bind", expr_string} ->
          {expr, state} = to_unsafe_quoted(expr_string, state.env.file, node.line, state)

          {quote line: node.line do
             case Map.get(var!(state), unquote(slot_key)) do
               empty when empty in ["", nil, false] ->
                 unquote(maybe_to_binary(fallback_content.acc))

               content when is_function(content, 1) ->
                 content.(unquote(expr))

               content ->
                 content
             end
           end, state}

        _ ->
          {quote line: node.line do
             case Map.get(var!(state), unquote(slot_key)) do
               empty when empty in ["", nil, false] ->
                 unquote(maybe_to_binary(fallback_content.acc))

               content ->
                 content
             end
           end, state}
      end

    {slot, state} =
      if node.keep do
        temp_state =
          state
          |> State.new()
          |> State.concat("</" <> node.tag <> ">")
          |> State.concat(slot)
          |> State.concat(">")
          |> compile_attributes(node.attrs, node)
          |> State.concat("<" <> node.tag)

        {temp_state.acc, State.merge_assigns_used(state, temp_state)}
      else
        {slot, state}
      end

    expr = Expr.new(slot, "slot", node.dir, slot_key, node.line)

    state
    |> State.merge_assigns_used(fallback_content)
    |> State.push_stack(expr)
  end

  defp push_node(state, %Node{type: :component, binding: binding, line: line} = node) do
    {slot_content, state} =
      case find_named_slots(node.content) do
        {[], content} ->
          default_slot = compile_slot_content(State.new(state), content, binding, line)
          state = State.merge_assigns_used(state, default_slot)
          {[__slot__: default_slot.acc], state}

        {slots, content} ->
          default_slot = compile_slot_content(State.new(state), content, binding, line)
          state = State.merge_assigns_used(state, default_slot)

          slot_exprs =
            for %Node{binding: binding} = node <- slots, reduce: State.new(state) do
              state -> compile_slot_node(state, node, binding)
            end

          state = State.merge_assigns_used(state, slot_exprs)
          slots = Enum.map(slot_exprs.stack, &{&1.slot_key, &1.ast})

          {[{:__slot__, default_slot.acc} | slots], state}
      end

    {attrs, state} = quote_attributes(node.attrs, node.line, state)

    expr =
      call(node.tag, attrs, slot_content, node.line, state)
      |> Expr.new(node.tag, node.dir, nil, node.line)

    State.push_stack(state, expr)
  end

  defp push_node(state, %Node{tag: :expr, type: :content, content: value, line: line}) do
    {expr, state} = to_quoted(value, state.env.file, line, state)
    expr = Expr.new(expr, :expr, nil, nil, line)
    State.push_stack(state, expr)
  end

  defp push_node(state, %Node{tag: :characters, type: :content, content: value, line: line}) do
    expr = Expr.new(value, :characters, nil, nil, line)
    State.push_stack(state, expr)
  end

  defp push_node(state, %Node{type: :slot} = node) do
    temp_state =
      if node.keep do
        state
        |> State.new()
        |> State.concat("</" <> node.tag <> ">")
        |> compile_content(node.content)
        |> State.concat(">")
        |> compile_attributes(node.attrs, node)
        |> State.concat("<" <> node.tag)
      else
        state
        |> State.new()
        |> compile_content(node.content)
      end

    expr = Expr.new(temp_state.acc, node.tag, node.dir, nil, node.line)

    state
    |> State.merge_assigns_used(temp_state)
    |> State.push_stack(expr)
  end

  defp push_node(state, node) do
    temp_state =
      if Node.void_element?(node.tag) do
        # TODO: This error currently will never be raised, because htmlerl always self close void elements.
        # This results in confusing behaviour when trying to put content inside void elements 
        if node.content not in [nil, []] do
          raise_error(node, "content in void elements is not allowed")
        end

        State.new(state) |> State.concat("/>")
      else
        State.new(state) |> State.concat("</" <> node.tag <> ">") |> compile_content(node.content) |> State.concat(">")
      end

    temp_state =
      temp_state
      |> compile_attributes(node)
      |> State.concat("<" <> node.tag)

    expr = Expr.new(temp_state.acc, node.tag, node.dir, nil, node.line)

    state
    |> State.merge_assigns_used(temp_state)
    |> State.push_stack(expr)
  end

  defp flush_expr(%State{stack: [%Expr{dir: {:":cond", _}}, %Expr{dir: {:":cond", _}} | _]} = state) do
    state
  end

  defp flush_expr(
         %State{stack: [other, %Expr{ast: cond_ast, dir: {:":cond", expr_string}, line: line} | clauses]} = state
       ) do
    {test, state} = to_unsafe_quoted(expr_string, state.env.file, line, state)
    clause = Directive.cond_clause(test, cond_ast, line)
    {clauses, state} = compile_cond_clauses(clauses, [], state)

    clauses =
      case clauses do
        [] -> [clause, Directive.cond_fallback(line)]
        clauses -> [clause | clauses]
      end

    ast = Directive.cond(clauses, line)
    %{state | stack: [other]} |> State.concat(ast) |> flush_expr()
  end

  defp flush_expr(
         %State{stack: [%Expr{ast: clause_ast, dir: {:":clause", {case_string, clause_string}}, line: line} | clauses]} =
           state
       ) do
    {case_expr, state} = to_unsafe_quoted(case_string, state.env.file, line, state)
    {clause_pat, state} = to_unsafe_quoted(clause_string, state.env.file, line, state)
    clause = Directive.case_clause(clause_pat, clause_ast, line)
    {clauses, state} = compile_case_clauses(clauses, [], state)
    ast = Directive.case(case_expr, [clause | clauses], line)

    State.concat_and_flush(state, ast)
  end

  defp flush_expr(%State{stack: [%Expr{ast: for_ast, dir: {:":for", gen_string}, line: line}]} = state) do
    {generator, state} = to_unsafe_quoted(gen_string, state.env.file, line, state)
    ast = Directive.for(generator, for_ast, line)
    State.concat_and_flush(state, ast)
  end

  defp flush_expr(%State{stack: [%Expr{ast: if_ast, dir: {:":if", expr_string}, line: line}]} = state) do
    {test, state} = to_unsafe_quoted(expr_string, state.env.file, line, state)
    ast = Directive.if_else_fallback(test, if_ast, line)
    State.concat_and_flush(state, ast)
  end

  defp flush_expr(
         %State{
           stack: [
             %Expr{ast: if_ast, dir: {:":if", expr_string}, line: line},
             %Expr{ast: else_ast, dir: {:":else", _}}
           ]
         } = state
       ) do
    {test, state} = to_unsafe_quoted(expr_string, state.env.file, line, state)
    ast = Directive.if_else(test, if_ast, else_ast, line)
    State.concat_and_flush(state, ast)
  end

  defp flush_expr(%State{env: env, stack: [%Expr{dir: dir}, %Expr{dir: {:":else", _}, line: line}]} = state) do
    case dir do
      {:":cond", _} -> state
      _ -> raise_error(env.file, line, "missing `:if` or `:cond` before `:else`")
    end
  end

  defp flush_expr(%State{stack: [%Expr{ast: ast, dir: nil, slot_key: nil}]} = state) do
    State.concat_and_flush(state, ast)
  end

  defp flush_expr(%State{stack: [%Expr{tag: "slot", ast: ast, dir: nil}]} = state) do
    State.concat_and_flush(state, ast)
  end

  defp flush_expr(%State{} = state), do: state

  defp compile_cond_clauses([%Expr{ast: clause_ast, dir: {:":cond", clause_string}, line: line}], acc, state) do
    {clause_pat, state} = to_unsafe_quoted(clause_string, state.env.file, line, state)
    clause = Directive.cond_clause(clause_pat, clause_ast, line)
    fallback = Directive.cond_fallback(line)
    {:lists.reverse([fallback, clause | acc]), state}
  end

  defp compile_cond_clauses([%Expr{ast: clause_ast, dir: {:":else", _}, line: line}], acc, state) do
    {:lists.reverse([Directive.cond_clause(true, clause_ast, line) | acc]), state}
  end

  defp compile_cond_clauses([%Expr{ast: clause_ast, dir: {:":cond", clause_string}, line: line} | rest], acc, state) do
    {clause_pat, state} = to_unsafe_quoted(clause_string, state.env.file, line, state)
    compile_cond_clauses(rest, [Directive.cond_clause(clause_pat, clause_ast, line) | acc], state)
  end

  defp compile_cond_clauses([], [], state) do
    {[], state}
  end

  defp compile_case_clauses([%Expr{ast: clause_ast, dir: {:":clause", clause_string}, line: line} | rest], acc, state) do
    {clause_pat, state} = to_unsafe_quoted(clause_string, state.env.file, line, state)
    compile_case_clauses(rest, [Directive.case_clause(clause_pat, clause_ast, line) | acc], state)
  end

  defp compile_case_clauses([], acc, state) do
    {:lists.reverse(acc), state}
  end

  defp compile_content(state, content) do
    # Always push a noop expression as the first content for simpler directive matching in flush_expr/1
    state
    |> compile_content_rec(content)
    |> State.push_stack(Expr.noop())
    |> flush_expr()
    |> stack_check()
  end

  defp compile_content_rec(state, [node | rest]) do
    state |> compile_node(node) |> compile_content_rec(rest)
  end

  defp compile_content_rec(state, []) do
    state
  end

  defp compile_slot_content(state, content, {:":let", expr_string}, line) do
    state = %State{acc: acc} = compile_content(state, content)
    {expr, state} = to_unsafe_quoted(expr_string, state.env.file, line, state)

    acc =
      quote do
        fn unquote(expr) -> unquote(maybe_to_binary(acc)) end
      end

    %{state | acc: acc}
  end

  defp compile_slot_content(state, content, _, _) do
    state = %State{acc: acc} = compile_content(state, content)
    %{state | acc: maybe_to_binary(acc)}
  end

  defp compile_attributes(state, %Node{global_attrs: true} = node) do
    {globals, attrs} = Enum.split_with(node.attrs, fn {name, _} -> Node.global_attribute?(name) end)

    state |> compile_attributes(attrs, node) |> compile_globals(globals, node)
  end

  defp compile_attributes(state, %Node{global_attrs: false} = node) do
    compile_attributes(state, node.attrs, node)
  end

  defp compile_attributes(state, [{name, value} | rest], %Node{env: {file, _}, line: line} = node) do
    state |> compile_attribute(name, value, file, line) |> compile_attributes(rest, node)
  end

  defp compile_attributes(state, [], _node) do
    state
  end

  defp compile_attribute(state, name, value, file, line) do
    {quoted, state} = quote_attribute(value, file, line, state)
    value = encode_attribute(quoted, line)
    test = quoted

    attr_acc =
      [" " <> name <> "=" <> "\""]
      |> concat(value)
      |> concat("\"")

    if is_binary(value) do
      State.concat(state, attr_acc)
    else
      attr = attr_acc |> :lists.reverse() |> maybe_to_binary()

      expr =
        quote line: line do
          if unquote(test), do: unquote(attr), else: ""
        end

      State.concat(state, expr)
    end
  end

  defp quote_attributes(attrs, line, state) do
    {attrs, state} =
      Enum.reduce(attrs, {[], state}, fn {name, value}, {acc, state} ->
        {quoted, state} = quote_attribute(value, state.env.file, line, state)
        {[{name, quoted} | acc], state}
      end)

    {:lists.reverse(attrs), state}
  end

  defp compile_globals(state, globals, node) do
    quoted =
      quote line: node.line do
        globals =
          Map.merge(unquote({:%{}, [], globals}), var!(state).__globals__, fn
            "class", v1, v2 -> v1 <> " " <> v2
            _, _v1, v2 -> v2
          end)

        Enum.reduce(globals, "", fn {name, value}, acc ->
          if value do
            " " <> name <> "=\"" <> Vaux.Encoder.encode(value) <> "\"" <> acc
          else
            acc
          end
        end)
      end

    State.concat(state, quoted)
  end

  defp inject_case(content, expr_string) do
    inject_case(:lists.reverse(content), expr_string, [])
  end

  defp inject_case([%Node{dir: {:":clause", _}} | _], :done, [%Node{dir: nil} = prev | _]) do
    raise_error(prev, "can not mix regular elements between `:clause` elements")
  end

  defp inject_case([%Node{dir: {:":clause", _}} | _], :done, [%Node{dir: {dir, _}} = prev | _])
       when dir != :":clause" do
    raise_error(prev, "can not mix other directives between `:clause` elements")
  end

  defp inject_case([%Node{dir: {:":clause", _}} = node | rest], :done, acc) do
    inject_case(rest, :done, [node | acc])
  end

  defp inject_case([%Node{dir: {:":clause", pattern}} = node | rest], case_string, acc) do
    node = %{node | dir: {:":clause", {case_string, pattern}}}
    inject_case(rest, :done, [node | acc])
  end

  defp inject_case([node | rest], case_expr, acc) do
    inject_case(rest, case_expr, [node | acc])
  end

  defp inject_case([], _, acc) do
    acc
  end

  defp stack_check(%State{stack: []} = state), do: state

  defp stack_check(%State{env: env, stack: [%Expr{type: :content, ast: ""} | stack]} = state) do
    Enum.each(stack, fn
      %Expr{dir: nil} -> :ok
      %Expr{dir: {:":clause", _}, line: line} -> raise_error(env.file, line, "missing `:case` directive on parent")
      %Expr{dir: {:":else", _}, line: line} -> raise_error(env.file, line, "missing `:if` or `:cond` before `:else`")
      %Expr{line: line} = unknown -> raise_error(env.file, line, "unknown stack error:\n\n#{inspect(unknown)}i\n")
    end)

    state
  end

  defp stack_check(%State{env: env, stack: unknown}) do
    raise_error(env.file, env.line, "unknown stack error:\n\n#{inspect(unknown)}i\n")
  end

  defp find_named_slots(nodes) do
    Enum.split_with(nodes, fn
      %Node{tag: "template", attrs: [_slot_key], type: :slot} -> true
      _ -> false
    end)
  end

  defp quote_attribute(value, file, line, state) do
    case value do
      {:expr, string} ->
        to_unsafe_quoted(string, file, line, state)

      string ->
        {string, state}
    end
  end

  defp encode_attribute(value, line) do
    if is_binary(value) do
      value
    else
      quote line: line do
        Vaux.Encoder.encode(
          # render the atom `true` as ""
          case unquote(value) do
            true -> nil
            v -> v
          end
        )
      end
    end
  end

  defp call(tag, attrs, slots, line, state) do
    case module_from_tag(tag, state.env) do
      nil ->
        description = "component #{tag} is not available"
        raise_error(state.env.file, line, description)

      mod ->
        {attrs, globals} =
          case validate_attrs(mod, attrs) do
            {:ok, attrs, globals} ->
              {attrs, globals}

            {description, attrs, globals} ->
              IO.warn(description,
                file: state.env.file,
                line: line,
                module: state.env.module,
                function: {:render, 2}
              )

              {attrs, globals}
          end

        quote line: line do
          Vaux.render!(
            unquote(mod),
            unquote({:%{}, [], attrs}),
            unquote({:%{}, [], globals}),
            unquote({:%{}, [], slots}),
            unquote(state.env.file),
            unquote(line)
          )
        end
    end
  end

  defp validate_attrs(component, attrs) do
    {globals, attrs} = extract_globals(component, attrs)
    fields = component.__vaux__(:fields)
    required = component.__vaux__(:required)

    case validate_attrs(attrs, fields, required, []) do
      {[], []} ->
        {:ok, attrs, globals}

      {required, invalid} ->
        errors =
          (Enum.map(required, &"\n\t- required attribute `#{&1}` missing") ++
             Enum.map(invalid, &"\n\t- invalid attribute `#{&1}`"))
          |> Enum.join()

        description = "component compile time validation errors:\n" <> errors <> "\n"
        {description, attrs, globals}
    end
  end

  defp validate_attrs([{field, _} | rest], fields, required, invalid) do
    if field in fields do
      required = List.delete(required, field)
      validate_attrs(rest, fields, required, invalid)
    else
      validate_attrs(rest, fields, required, [field | invalid])
    end
  end

  defp validate_attrs([], _fields, required, invalid) do
    {required, invalid}
  end

  defp concat([], value), do: List.wrap(value)
  defp concat(acc, [value | rest]), do: concat(concat(acc, value), rest)
  defp concat(acc, []), do: acc
  defp concat([bin | rest], value) when is_binary(bin) and is_binary(value), do: [bin <> value | rest]
  defp concat(acc, value), do: [value | acc]

  defp to_quoted("", _file, _line, state), do: {"", state}

  defp to_quoted(string, file, line, state) do
    {quoted, state} = to_unsafe_quoted(string, file, line, state)

    quoted =
      quote line: line do
        Vaux.Encoder.encode(unquote(quoted))
      end

    {quoted, state}
  end

  defp to_unsafe_quoted(string, file, line, state) do
    string
    |> Code.string_to_quoted!(file: file, line: line)
    |> Macro.prewalk(state, &handle_assigns/2)
  end

  defp handle_assigns({:@, meta, [{:!, _, [{root_fun, _, _}]}]}, state) do
    ast =
      quote line: meta[:line] || 0 do
        @__vaux_root__.unquote(root_fun)
      end

    {ast, state}
  end

  defp handle_assigns({:@, meta, [{field, _, atom}]}, state) when field != :__vaux_root__ and is_atom(atom) do
    ast =
      quote line: meta[:line] || 0 do
        var!(state).unquote(field)
      end

    state = State.add_assign(state, field)

    {ast, state}
  end

  defp handle_assigns(expr, state) do
    {expr, state}
  end

  defp module_from_tag(tag, env) do
    {mod, _} = Code.eval_string(tag)
    get_module(mod, env)
  end

  defp get_module(mod, env) do
    case Code.ensure_loaded(mod) do
      {:module, mod} ->
        if function_exported?(mod, :__vaux__, 1) do
          mod
        end

      _abort when is_nil(env) ->
        nil

      _maybe_alias ->
        {_, mod} =
          Enum.find(env.aliases, {mod, nil}, fn
            {^mod, _} -> true
            _ -> false
          end)

        if not is_nil(mod) do
          get_module(mod, nil)
        end
    end
  end

  # Lifted from https://github.com/phoenixframework/phoenix_html/blob/main/lib/phoenix_html/engine.ex
  @doc false
  @spec html_escape(String.t()) :: String.t()
  def html_escape(bin) when is_binary(bin) do
    html_escape(bin, 0, bin, []) |> :erlang.iolist_to_binary()
  end

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp html_escape(<<unquote(match), rest::bits>>, skip, original, acc) do
      html_escape(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp html_escape(<<_char, rest::bits>>, skip, original, acc) do
    html_escape(rest, skip, original, acc, 1)
  end

  defp html_escape(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp html_escape(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      html_escape(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp html_escape(<<_char, rest::bits>>, skip, original, acc, len) do
    html_escape(rest, skip, original, acc, len + 1)
  end

  defp html_escape(<<>>, 0, original, _acc, _len) do
    original
  end

  defp html_escape(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end

  def raise_error(%Node{env: {file, _}, line: line}, description) do
    raise_error(file, line, description)
  end

  def raise_error(file, line, description) do
    raise Vaux.CompileError, file: file, line: line, description: description
  end
end

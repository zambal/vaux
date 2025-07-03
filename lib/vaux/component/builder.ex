defmodule Vaux.Component.Builder do
  @moduledoc false

  @components_key :__vaux_components__
  @attrs_key :__vaux_attrs__
  @slots_key :__vaux_slots__
  @var_key :__vaux_var__
  @template_key :__vaux_template__
  @const_key :__vaux_const___

  def defcomponent(env) do
    attrs_schema = Module.get_attribute(env.module, @attrs_key, [])
    Module.delete_attribute(env.module, @attrs_key)
    vars = Module.get_attribute(env.module, @var_key, [])
    Module.delete_attribute(env.module, @var_key)
    slots = Module.get_attribute(env.module, @slots_key, [])
    Module.delete_attribute(env.module, @slots_key)
    template = Module.get_attribute(env.module, @template_key)
    Module.delete_attribute(env.module, @template_key)

    if is_nil(template) do
      raise Vaux.CompileError,
        file: env.file,
        line: env.line,
        description: "`~H` html template is not available"
    end

    {string, caller} = template
    {quoted, assigns} = Vaux.Component.Compiler.compile(string, caller)
    defaults = Vaux.Schema.get_defaults(attrs_schema) |> Macro.escape()

    jsv_schema =
      case Vaux.Schema.to_jsv_schema(attrs_schema) do
        {:ok, root} ->
          Macro.escape(root)

        {:error, %NimbleOptions.ValidationError{message: msg}} ->
          raise Vaux.CompileError,
            file: env.file,
            line: env.line,
            description: "attr parse schema error: #{inspect(msg)}"

        {:error, %JSV.BuildError{reason: reason}} ->
          raise Vaux.CompileError,
            file: env.file,
            line: env.line,
            description: "attr json schema error: #{inspect(reason)}"
      end

    {struct_fields, required} = Vaux.Schema.to_struct_def(attrs_schema, vars, slots)

    case Vaux.Schema.check_assigns(assigns, struct_fields) do
      [] ->
        :ok

      [:__slot__] ->
        :ok

      [unused] ->
        IO.warn("component #{inspect(caller.module)} has an unused assign: `#{unused}`",
          file: caller.file,
          line: caller.line,
          module: caller.module,
          function: {:render, 2}
        )

      unused ->
        unused =
          unused
          |> Enum.filter(&(&1 != :__slot__))
          |> Enum.map_join(", ", &"`#{&1}`")

        IO.warn(
          "component #{inspect(caller.module)} has unused assigns: #{unused}",
          file: caller.file,
          line: caller.line,
          module: caller.module,
          function: {:render, 2}
        )
    end

    quote do
      @enforce_keys unquote(required)
      defstruct unquote(struct_fields)

      def __vaux__(:schema), do: unquote(jsv_schema)
      def __vaux__(:fields), do: unquote(for {name, _} <- struct_fields, do: Atom.to_string(name))
      def __vaux__(:required), do: unquote(for name <- required, do: Atom.to_string(name))
      def __vaux__(:defaults), do: unquote(defaults)
      def __vaux__(:slots), do: unquote(slots)

      def handle_state(%__MODULE__{} = state) do
        {:ok, state}
      end

      def render(%__MODULE__{} = var!(state)) do
        # prevent unused warning
        _state = var!(state)
        unquote(quoted)
      end

      defoverridable(handle_state: 1)
    end
  end

  defmacro defroot(env) do
    components = Module.get_attribute(env.module, @components_key, [])
    Module.delete_attribute(env.module, @components_key)
    consts = Module.get_attribute(env.module, @const_key, [])
    Module.delete_attribute(env.module, @const_key)

    components = components |> handle_requires() |> Macro.escape()

    quote do
      unquote(Vaux.Component.Builder.handle_const_defs(consts, env))

      defmacro __using__(_opts) do
        components = unquote(components)
        root_mod = unquote(env.module)

        quote do
          import Vaux.Component
          alias unquote(root_mod)
          unquote(components)

          @__vaux_root__ unquote(root_mod)
        end
      end
    end
  end

  def put_attribute(mod, attr) do
    if no_attributes?(mod) do
      Module.register_attribute(mod, @attrs_key, accumulate: true)
    end

    Module.put_attribute(mod, @attrs_key, attr)
  end

  def no_attributes?(mod) do
    is_nil(Module.get_attribute(mod, @attrs_key))
  end

  def put_slot(mod, slot_key) do
    if no_slots?(mod) do
      Module.register_attribute(mod, @slots_key, accumulate: true)
    end

    Module.put_attribute(mod, @slots_key, slot_key)
  end

  def no_slots?(mod) do
    is_nil(Module.get_attribute(mod, @slots_key))
  end

  def put_state(mod, state_key) do
    Module.put_attribute(mod, @var_key, state_key)
  end

  def put_template(mod, template) do
    Module.put_attribute(mod, @template_key, template)
  end

  def put_components(mod, comps) do
    if is_nil(Module.get_attribute(mod, @components_key)) do
      Module.register_attribute(mod, @components_key, accumulate: true)
    end

    comps |> List.wrap() |> Enum.map(&Module.put_attribute(mod, @components_key, &1))
  end

  def put_var(mod, var) do
    if is_nil(Module.get_attribute(mod, @var_key)) do
      Module.register_attribute(mod, @var_key, accumulate: true)
    end

    Module.put_attribute(mod, @var_key, var)
  end

  def put_const(mod, const) do
    if is_nil(Module.get_attribute(mod, @const_key)) do
      Module.register_attribute(mod, @const_key, accumulate: true)
    end

    Module.put_attribute(mod, @const_key, const)
  end

  def handle_requires(comps) do
    Enum.reduce(comps, nil, &handle_require/2)
  end

  defp handle_require({:__aliases__, _, segments} = mod, acc) do
    alias = Module.concat([segments |> :lists.reverse() |> hd()])

    quote do
      unquote(acc)
      require unquote(mod), as: unquote(Macro.escape(alias))
    end
  end

  defp handle_require({{:., _, [{:__aliases__, _, prefix}, _]}, _, segments}, acc) do
    segments = for {:__aliases__, _, segments} <- segments, do: segments

    Enum.reduce(segments, acc, fn s, acc ->
      mod = Module.concat(prefix ++ s)
      alias = Module.concat([s |> :lists.reverse() |> hd()])

      quote do
        unquote(acc)
        require unquote(mod), as: unquote(alias)
      end
    end)
  end

  def handle_const_defs(consts, env) do
    Enum.reduce(consts, nil, fn {name, value, line}, acc ->
      quote line: line do
        unquote(acc)
        def unquote(name)(), do: unquote(parse_expr(value, line, env))
      end
    end)
  end

  defp parse_expr(value, line, env) do
    case value do
      {:fn, _, [{:->, _, [[], _]}]} = quoted_fun ->
        {value, _, _} = Code.eval_quoted_with_env(quote(do: unquote(quoted_fun).()), [], env)
        value

      {:fn, _, _} ->
        description = "Only functions of arity 0 are supported as const value"
        raise Vaux.CompileError, file: env.file, line: line, description: description

      {:&, _, [{:/, _, [_, 0]}]} = quoted_fun ->
        {value, _, _} = Code.eval_quoted_with_env(quote(do: unquote(quoted_fun).()), [], env)
        value

      {:&, _, _} ->
        description = "Only functions of arity 0 are supported as const value"
        raise Vaux.CompileError, file: env.file, line: line, description: description

      value ->
        value
    end
    |> Macro.escape()
  end
end

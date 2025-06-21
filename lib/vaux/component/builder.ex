defmodule Vaux.Component.Builder do
  @attrs_key :__vaux_attrs__
  @slots_key :__vaux_slots__
  @state_key :__vaux_state__
  @template_key :__vaux_template__

  defmacro defcomponent(env) do
    attrs_schema = Module.get_attribute(env.module, @attrs_key, [])
    Module.delete_attribute(env.module, @attrs_key)
    slots = Module.get_attribute(env.module, @slots_key, [])
    Module.delete_attribute(env.module, @slots_key)
    state = Module.get_attribute(env.module, @state_key)
    Module.delete_attribute(env.module, @state_key)
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
            description: "defattr parse schema error: #{inspect(msg)}"

        {:error, %JSV.BuildError{reason: reason}} ->
          raise Vaux.CompileError,
            file: env.file,
            line: env.line,
            description: "defattr json schema error: #{inspect(reason)}"
      end

    {state_fields, required} = Vaux.Schema.to_struct_def(attrs_schema, state)

    case Vaux.Schema.check_assigns(assigns, state_fields) do
      [] ->
        :ok

      [unused] ->
        IO.warn("component #{inspect(caller.module)} has an unused assign: `#{unused}`",
          file: caller.file,
          line: caller.line,
          module: caller.module,
          function: {:render, 2}
        )

      unused ->
        IO.warn(
          "component #{inspect(caller.module)} has unused assigns: #{Enum.map_join(unused, ", ", &"`#{&1}`")}",
          file: caller.file,
          line: caller.line,
          module: caller.module,
          function: {:render, 2}
        )
    end

    slot_fields = for slot_key <- [:__default | slots], do: {slot_key, ""}
    fields = state_fields ++ slot_fields

    init_fun =
      if is_nil(state) do
        quote do
          def init(attrs, slot_content) do
            {:ok, Vaux.Component.state(attrs, slot_content)}
          end

          defoverridable(init: 2)
        end
      end

    quote do
      @enforce_keys unquote(required)
      defstruct unquote(fields)

      def __vaux__(:schema), do: unquote(jsv_schema)
      def __vaux__(:fields), do: unquote(for {name, _} <- state_fields, do: Atom.to_string(name))
      def __vaux__(:required), do: unquote(for name <- required, do: Atom.to_string(name))
      def __vaux__(:defaults), do: unquote(defaults)
      def __vaux__(:slots), do: unquote(slots)

      unquote(init_fun)

      def render(%__MODULE__{} = var!(state)) do
        # prevent unused warning
        _state = var!(state)
        unquote(quoted)
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
    Module.put_attribute(mod, @state_key, state_key)
  end

  def put_template(mod, template) do
    Module.put_attribute(mod, @template_key, template)
  end

  def handle_requires([{:__aliases__, _, segments} = mod | rest]) do
    alias = Module.concat([segments |> :lists.reverse() |> hd()])

    quoted =
      quote do
        require unquote(mod), as: unquote(alias)
      end

    [quoted | handle_requires(rest)]
  end

  def handle_requires([{{:., _, [{:__aliases__, _, prefix}, _]}, _, segments} | rest]) do
    segments = for {:__aliases__, _, segments} <- segments, do: segments

    Enum.reduce(segments, handle_requires(rest), fn s, acc ->
      mod = Module.concat(prefix ++ s)
      alias = Module.concat([s |> :lists.reverse() |> hd()])

      quoted =
        quote do
          require unquote(mod), as: unquote(alias)
        end

      [quoted | acc]
    end)
  end

  def handle_requires([]), do: []
end

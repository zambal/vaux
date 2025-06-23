defmodule Vaux.Component do
  require Vaux.Component.Builder
  alias Vaux.Component.Builder

  @callback handle_state(state :: struct()) :: {:ok, state} | {:error, reason}
            when state: struct(), reason: any()

  @callback render(state :: struct()) :: iodata()

  defmacro components(comps) when is_list(comps) or is_atom(comps) do
    Vaux.Component.Builder.put_components(__CALLER__.module, comps)
  end

  defmacro slot(name) do
    %{module: mod, file: file, line: line} = __CALLER__

    Builder.put_slot(mod, name)

    if not is_atom(name) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end
  end

  defmacro attr(field) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_attribute(mod, {field, true, false})
  end

  defmacro attr(field, type, opts \\ []) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    {type, _} = Code.eval_quoted(type, [], __CALLER__)
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)

    case Vaux.Schema.to_schema_prop(type, opts) do
      {:ok, prop_def, required} ->
        Builder.put_attribute(mod, {field, prop_def, required})

      {:error, {:invalid_type, type}} ->
        description = "#{inspect(field)} attribute has an invalid type: #{inspect(type)}"
        raise Vaux.CompileError, file: file, line: line, description: description

      {:error, {:invalid_inner_type, {_type, inner_type}}} ->
        description = "#{inspect(field)} attribute has an invalid inner type: #{inspect(inner_type)}"

        raise Vaux.CompileError, file: file, line: line, description: description

      {:error, {:invalid_opt, opt}} ->
        description = "#{inspect(field)} attribute has an invalid option: #{inspect(opt)}"
        raise Vaux.CompileError, file: file, line: line, description: description
    end
  end

  defmacro var([{name, value}]) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_var(mod, {name, value, line})
  end

  defmacro var(name) when is_atom(name) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_var(mod, {name, nil, line})
  end

  defmacro sigil_H({:<<>>, _meta, [string]}, mods) do
    %{module: mod, file: file, line: line} = __CALLER__

    case mods do
      ~c"vaux" ->
        :ok

      [] ->
        description =
          "Vaux template sigil requires the `vaux` modifier\n\n\t~H\"\"\"\n\t<h1>Hello World</h1>\n\t\"\"\"vaux\n"

        raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_template(mod, {string, __CALLER__})
    Builder.defcomponent(__CALLER__)
  end
end

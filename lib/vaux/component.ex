defmodule Vaux.Component do
  alias Vaux.Component.Builder

  @callback init(attrs :: %{atom() => any()}, slots :: %{atom() => any()}) :: {:ok, state} | {:error, reason}
            when state: struct(), reason: any()

  @callback render(state :: struct()) :: iodata()

  defmacro __using__(opts) do
    requires =
      opts
      |> Keyword.get(:require, [])
      |> List.wrap()
      |> Builder.handle_requires()

    quote do
      import Vaux.Component
      @behaviour Vaux.Component

      unquote(requires)
    end
  end

  defmacro defattr(field) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "defattr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_attribute(mod, {field, true, []})
  end

  defmacro defattr(field, type, opts \\ []) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "defattr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    {type, _} = Code.eval_quoted(type, [], __CALLER__)
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)

    case type do
      atom when is_atom(atom) ->
        :ok

      {type, _} when type in [:enum, :const] ->
        :ok

      _ ->
        description = "invalid attribute type"
        raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_attribute(mod, {field, type, opts})
  end

  defmacro defslot(key) do
    Builder.put_slot(__CALLER__.module, :"__#{key}")
  end

  defmacro defstate(fields) do
    fields =
      Enum.map(fields, fn
        {field, def} -> {field, def}
        field -> {field, nil}
      end)

    Builder.put_state(__CALLER__.module, fields)
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

    quote do
      @before_compile {Vaux.Component.Builder, :defcomponent}
    end
  end

  defmacro state(state) do
    mod = __CALLER__.module

    quote line: __CALLER__.line do
      struct(unquote(mod), unquote(state))
    end
  end

  defmacro state(state, slot_content) do
    mod = __CALLER__.module

    quote line: __CALLER__.line do
      slot_content =
        for {k, v} <- unquote(slot_content), into: %{} do
          case k do
            :default -> {:__default, v}
            slot_key -> {:"__#{slot_key}", v}
          end
        end

      struct(unquote(mod), Map.merge(unquote(state), slot_content))
    end
  end
end

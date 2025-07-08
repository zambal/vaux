defmodule Vaux.Schema do
  @moduledoc false

  @type attr_def :: {name :: atom(), type :: atom(), opts :: keyword()}
  @type attrs_schema :: [attr_def()]

  @schema_atom_types ~w(
    boolean
    object
    array
    number
    integer
    string
    true
    false
  )a

  @schema_opts ~w(
    properties
    items
    contains
    maxLength
    minLength
    pattern
    exclusiveMaximum
    exclusiveMinimum
    maximum
    minimum
    multipleOf
    required
    maxItems
    minItems
    maxContains
    minContains
    uniqueItems
    description
    default
    format
  )a

  @spec to_jsv_schema(attrs_schema()) :: {:ok, JSV.Root.t()} | {:error, term()}
  def to_jsv_schema(attrs_schema) do
    {props, required} =
      Enum.reduce(attrs_schema, {%{}, []}, fn {name, prop_def, req}, {props, reqs} ->
        {Map.put(props, name, prop_def), handle_required(reqs, name, req)}
      end)

    schema = %{type: :object, properties: props, required: required, additionalProperties: false}
    JSV.build(schema)
  end

  defp handle_required(acc, name, true), do: [name | acc]
  defp handle_required(acc, _name, false), do: acc

  @spec to_schema_prop(atom() | tuple(), keyword()) :: {:ok, map(), boolean()} | {:error, {atom(), term()}}
  def to_schema_prop(type, opts) do
    case validate_schema_type(type) do
      :ok ->
        case cast_schema_opts(opts) do
          {:ok, opts} ->
            {required, opts} = Keyword.pop(opts, :required, false)

            case handle_prop_type(type, opts) do
              {:ok, prop_def} -> {:ok, prop_def, required}
              {:error, e} -> {:error, e}
            end

          {:error, opt} ->
            {:error, {:invalid_opt, opt}}
        end

      :error ->
        {:error, {:invalid_type, type}}
    end
  end

  defp handle_prop_type(true, _opts), do: {:ok, true}

  defp handle_prop_type({:array, enum}, opts) when is_list(enum) do
    prop_type = %{type: :array, items: %{enum: enum}}
    {:ok, Enum.into(opts, prop_type)}
  end

  defp handle_prop_type({:array, inner_type}, opts) do
    if inner_type in @schema_atom_types do
      prop_type = %{type: :array, items: %{type: inner_type}}
      {:ok, Enum.into(opts, prop_type)}
    else
      {:error, {:invalid_inner_type, {:array, inner_type}}}
    end
  end

  defp handle_prop_type({type, value}, opts) do
    prop_type = %{type => value}
    {:ok, Enum.into(opts, prop_type)}
  end

  defp handle_prop_type(:array, opts) do
    prop_def = Enum.into(opts, %{type: :array})

    case prop_def[:items] do
      nil ->
        {:ok, prop_def}

      type when is_map(type) or type in @schema_atom_types ->
        handle_array_type(prop_def, type, [])

      {type, items_opts} when is_map(type) or type in @schema_atom_types ->
        handle_array_type(prop_def, type, items_opts)

      invalid ->
        {:error, {:invalid_items_type, invalid}}
    end
  end

  defp handle_prop_type(:object, opts) do
    prop_def = Enum.into(opts, %{type: :object})

    result =
      case prop_def[:properties] do
        nil ->
          {:ok, prop_def}

        props when is_map(props) ->
          handle_object_props(props)

        invalid ->
          {:error, {:invalid_props_type, invalid}}
      end

    case result do
      {:ok, props, []} ->
        {:ok, Map.put(prop_def, :properties, props)}

      {:ok, props, required} ->
        {:ok, Map.put(prop_def, :properties, props) |> Map.put(:required, required)}

      {:error, e} ->
        {:error, e}
    end
  end

  defp handle_prop_type(object_def, opts) when is_map(object_def) do
    handle_prop_type(:object, [{:properties, object_def} | opts])
  end

  defp handle_prop_type(type, opts) do
    prop_type = %{type: type}
    {:ok, Enum.into(opts, prop_type)}
  end

  defp handle_array_type(array_def, type, opts) do
    case to_schema_prop(type, opts) do
      {:ok, prop_def, _req} -> {:ok, Map.put(array_def, :items, prop_def)}
      {:error, e} -> {:error, e}
    end
  end

  defp handle_object_props(props) do
    Enum.reduce(props, {:ok, %{}, []}, fn
      {name, type}, {:ok, acc, reqs} when type in @schema_atom_types ->
        handle_object_name_type(acc, name, type, [], reqs)

      {name, {type, opts}}, {:ok, acc, reqs} when type in @schema_atom_types ->
        handle_object_name_type(acc, name, type, opts, reqs)

      {name, invalid}, {:ok, _, _} ->
        {:error, {:invalid_props_type, {name, invalid}}}

      _, {:error, e} ->
        {:error, e}
    end)
  end

  defp handle_object_name_type(name_def, name, type, opts, reqs) do
    case to_schema_prop(type, opts) do
      {:ok, prop_def, req} -> {:ok, Map.put(name_def, name, prop_def), handle_required(reqs, name, req)}
      {:error, e} -> {:error, e}
    end
  end

  defp validate_schema_type(type) when is_map(type) or type in @schema_atom_types, do: :ok
  defp validate_schema_type({:array, _}), do: :ok
  defp validate_schema_type({:object, _}), do: :ok
  defp validate_schema_type({:enum, _}), do: :ok
  defp validate_schema_type({:const, _}), do: :ok
  defp validate_schema_type(_invalid), do: :error

  defp cast_schema_opts(opts) do
    Enum.reduce(opts, {:ok, []}, fn
      {key, value}, {:ok, acc} ->
        case to_option(key) do
          {:ok, opt} -> {:ok, [{opt, value} | acc]}
          :error -> {:error, key}
        end

      _, {:error, key} ->
        {:error, key}
    end)
  end

  defp to_option(name) do
    case name |> to_string() |> String.split("_") do
      [""] ->
        :error

      [name] ->
        option_to_atom(name)
        |> validate_option()

      [first | rest] ->
        Enum.join([first | Enum.map(rest, &String.capitalize/1)])
        |> option_to_atom()
        |> validate_option()
    end
  end

  defp option_to_atom(string) do
    try do
      {:ok, String.to_existing_atom(string)}
    rescue
      ArgumentError -> :error
    end
  end

  defp validate_option({:ok, opt}) when opt in @schema_opts, do: {:ok, opt}
  defp validate_option(_), do: :error

  @spec get_defaults(attrs_schema()) :: %{String.t() => term()}
  def get_defaults(attrs_schema) do
    for {name, prop_def, _} <- attrs_schema, into: %{} do
      {name, get_default(prop_def)}
    end
  end

  def to_struct_def(attrs_schema, vars, slots) do
    fields = Enum.reduce(slots, [{:__slot__, nil}, {:__globals__, quote(do: %{})}], &[{&1, nil} | &2])
    fields = Enum.reduce(vars, fields, fn {name, var, _line}, acc -> [{name, var} | acc] end)

    Enum.reduce(attrs_schema, {fields, []}, fn {name, prop_def, req}, {names, reqs} ->
      default = get_default(prop_def)
      {[{name, default} | names], handle_required(reqs, name, req)}
    end)
  end

  defp get_default(%{default: d}), do: d
  defp get_default(_), do: nil

  @spec check_assigns([atom()], [{atom(), term()}]) :: [atom()]
  def check_assigns(assigns, names) do
    names = for {name, _} <- names, name not in [:__slot__, :__globals__], do: name

    Enum.reduce(assigns, names, fn name, names ->
      List.delete(names, name)
    end)
  end
end

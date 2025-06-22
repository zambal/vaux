defmodule Vaux.Schema do
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
      Enum.reduce(attrs_schema, {%{}, []}, fn {field, prop_def, req}, {props, reqs} ->
        {Map.put(props, field, prop_def), handle_required(reqs, field, req)}
      end)

    schema = %{type: :object, properties: props, required: required, additionalProperties: false}
    JSV.build(schema)
  end

  defp handle_required(acc, field, true), do: [field | acc]
  defp handle_required(acc, _field, false), do: acc

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
      {field, type}, {:ok, acc, reqs} when type in @schema_atom_types ->
        handle_object_field_type(acc, field, type, [], reqs)

      {field, {type, opts}}, {:ok, acc, reqs} when type in @schema_atom_types ->
        handle_object_field_type(acc, field, type, opts, reqs)

      {field, invalid}, {:ok, _, _} ->
        {:error, {:invalid_props_type, {field, invalid}}}

      _, {:error, e} ->
        {:error, e}
    end)
  end

  defp handle_object_field_type(field_def, field, type, opts, reqs) do
    case to_schema_prop(type, opts) do
      {:ok, prop_def, req} -> {:ok, Map.put(field_def, field, prop_def), handle_required(reqs, field, req)}
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
    for {field, prop_def, _} <- attrs_schema, into: %{} do
      {field, get_default(prop_def)}
    end
  end

  @spec to_struct_def(attrs_schema(), [{atom(), any()}] | nil) :: {list(), list()}
  def to_struct_def(attrs_schema, nil) do
    Enum.reduce(attrs_schema, {[], []}, fn {field, prop_def, req}, {fields, reqs} ->
      default = get_default(prop_def)
      {[{field, default} | fields], handle_required(reqs, field, req)}
    end)
  end

  def to_struct_def(_attrs_schema, state) do
    {state, []}
  end

  defp get_default(%{default: d}), do: d
  defp get_default(_), do: nil

  @spec check_assigns([atom()], [{atom(), term()}]) :: [atom()]
  def check_assigns(assigns, fields) do
    fields = Enum.map(fields, fn {n, _d} -> n end)

    Enum.reduce(assigns, fields, fn name, fields ->
      List.delete(fields, name)
    end)
  end
end

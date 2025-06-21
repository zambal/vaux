defmodule Vaux.Schema do
  @type attr_def :: {name :: atom(), type :: atom(), opts :: keyword()}
  @type attrs_schema :: [attr_def()]

  @spec to_jsv_schema(attrs_schema()) :: {:ok, JSV.Root.t()} | {:error, term()}
  def to_jsv_schema(attrs_schema) do
    {props, required} =
      Enum.reduce(attrs_schema, {%{}, []}, fn {name, type, opts}, {props, required} ->
        prop_def = handle_prop_def(type, opts)
        {Map.put(props, name, prop_def), handle_required(name, opts, required)}
      end)

    schema = %{type: :object, properties: props, required: required, additionalProperties: false}
    JSV.build(schema)
  end

  @spec to_struct_def(attrs_schema(), [{atom(), any()}] | nil) :: {list(), list()}
  def to_struct_def(attrs_schema, nil) do
    Enum.reduce(attrs_schema, {[], []}, fn {name, _type, opts}, {fields, required} ->
      default = Keyword.get(opts, :default)
      required = handle_required(name, opts, required)

      {[{name, default} | fields], required}
    end)
  end

  def to_struct_def(_attrs_schema, state) do
    {state, []}
  end

  @spec get_defaults(attrs_schema()) :: %{String.t() => term()}
  def get_defaults(attrs_schema) do
    for {name, _type, opts} <- attrs_schema, not is_nil(opts[:default]), into: %{} do
      {name, opts[:default]}
    end
  end

  @spec check_assigns([atom()], [{atom(), term()}]) :: [atom()]
  def check_assigns(assigns, fields) do
    fields = Enum.map(fields, fn {n, _d} -> n end)

    Enum.reduce(assigns, fields, fn name, fields ->
      List.delete(fields, name)
    end)
  end

  defp handle_required(name, opts, acc) do
    if Keyword.get(opts, :required, false),
      do: [name | acc],
      else: acc
  end

  defp handle_prop_def(true, _opts), do: true

  defp handle_prop_def({type, value}, opts) do
    prop_def = %{type => value}
    opts = Keyword.delete(opts, :required)
    Enum.into(opts, prop_def)
  end

  defp handle_prop_def(type, opts) do
    prop_def = %{type: type}
    opts = Keyword.delete(opts, :required)
    Enum.into(opts, prop_def)
  end
end

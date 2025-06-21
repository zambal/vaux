defmodule Vaux do
  @type attributes :: %{String.t() => any()}
  @type slot_content :: iodata() | keyword(iodata()) | %{atom() => iodata()} | nil

  @spec render(component :: module(), attrs :: attributes(), slots :: slot_content()) ::
          {:ok, iodata()} | {:error, Vaux.RuntimeError.t()}
  def render(component, attrs, slots \\ nil) do
    {:ok, render!(component, attrs, normalize_slots(slots), "nofile", 0)}
  rescue
    error in [Vaux.RuntimeError] ->
      {:error, error}
  end

  @spec render!(component :: module(), attrs :: attributes(), slots :: slot_content()) :: iodata()
  def render!(component, attrs, slots \\ nil) do
    render!(component, attrs, normalize_slots(slots), "nofile", 0)
  end

  @doc false
  @spec render!(module(), attributes(), map(), Path.t(), non_neg_integer()) :: iodata()
  def render!(component, attrs, slot_content, file, line) do
    case validate_attrs(component, attrs) do
      {:ok, attrs} ->
        case component.init(attrs, slot_content) do
          {:ok, state} when is_struct(state, component) ->
            component.render(state)

          {:ok, badret} ->
            description = "init function is expected to return its module's struct, got #{inspect(badret)}"
            raise Vaux.RuntimeError, file: file, line: line, error: :init, description: description

          {:error, reason} ->
            description = "component #{inspect(component)} init error: #{inspect(reason)}"
            raise Vaux.RuntimeError, file: file, line: line, error: :init, description: description
        end

      {:error, {:__vaux__, :noschema}} ->
        description = "no `defattr` declarations in component #{inspect(component)}"
        raise Vaux.RuntimeError, file: file, line: line, error: :noschema, description: description

      {:error, {:__vaux__, :nofile}} ->
        description = "component #{inspect(component)} is not available"
        raise Vaux.RuntimeError, file: file, line: line, error: :nofile, description: description

      {:error, %JSV.ValidationError{} = error} ->
        %{details: details} = JSV.normalize_error(error)

        msg =
          for %{errors: es} <- details, into: "" do
            Enum.map_join(es, fn %{message: msg} -> "\n\t- " <> msg end)
          end

        description = "component #{inspect(component)} validation errors:\n#{msg}\n"
        raise Vaux.RuntimeError, file: file, line: line, error: :validation, description: description
    end
  end

  defp normalize_slots(nil), do: %{}
  defp normalize_slots([{name, _} | _] = slots) when is_atom(name), do: Enum.into(slots, %{})
  defp normalize_slots(slots) when is_map(slots), do: slots
  defp normalize_slots(slot), do: %{default: slot}

  defp validate_attrs(component, attrs) do
    if function_exported?(component, :__vaux__, 1) do
      case JSV.validate(attrs, component.__vaux__(:schema)) do
        {:ok, attrs} ->
          attrs = atomize(attrs)
          {:ok, Map.merge(component.__vaux__(:defaults), attrs)}

        {:error, e} ->
          {:error, e}
      end
    else
      case Code.ensure_loaded(component) do
        {:module, _} ->
          if function_exported?(component, :__vaux__, 1),
            do: validate_attrs(component, attrs),
            else: {:error, {:__vaux__, :noschema}}

        {:error, :nofile} ->
          {:error, {:__vaux__, :nofile}}
      end
    end
  end

  defp atomize(map) when is_map(map) do
    for {k, v} <- map, into: %{}, do: {String.to_existing_atom(k), atomize(v)}
  end

  defp atomize(list) when is_list(list) do
    for item <- list, do: atomize(item)
  end

  defp atomize(other), do: other
end

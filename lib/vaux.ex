defmodule Vaux do
  @moduledoc """
  Provides functions to render Vaux components to html.

      iex> defmodule HelloWorld do
      ...>   import Vaux.Component
      ...> 
      ...>   attr :title, :string
      ...> 
      ...>   ~H"<h1>{@title}</h1>"vaux
      ...> end
      iex> Vaux.render(HelloWorld, %{"title" => "Hello World"})
      {:ok, "<h1>Hello World</h1>"}
  """

  alias Vaux.Component.Compiler

  @type attributes :: %{String.t() => any()}
  @type slot_content :: iodata() | keyword(iodata()) | %{atom() => iodata()} | nil

  @doc """
  Render a component to html

  Accepts a map where keys are strings as attributes and a map where keys are atoms as slots.

  Returns `{:ok, iodata()}` or `{:error, Vaux.RuntimeError.t()}` when an error 
  is encountered during rendering.

  By default a string is returned, but when 

      config :vaux, render_to_binary: false 

  is set, an iolist is returned. Depending on the template complexity, this can 
  give a small performance boost. Note that this config setting is evaluated at 
  compile time.
  """
  @spec render(component :: module(), attrs :: attributes(), slots :: slot_content()) ::
          {:ok, iodata()} | {:error, Vaux.RuntimeError.t()}
  def render(component, attrs \\ %{}, slots \\ nil) do
    {globals, attrs} = Compiler.extract_globals(component, attrs)
    {:ok, render!(component, Enum.into(attrs, %{}), Enum.into(globals, %{}), normalize_slots(slots), "nofile", 0)}
  rescue
    error in [Vaux.RuntimeError] ->
      {:error, error}
  end

  @doc """
  Same as `render/3`, but raises an `Vaux.RuntimeError` exception when an error is encountered
  """
  @spec render!(component :: module(), attrs :: attributes(), slots :: slot_content()) :: iodata()
  def render!(component, attrs \\ %{}, slots \\ nil) do
    {globals, attrs} = Compiler.extract_globals(component, attrs)
    render!(component, Enum.into(attrs, %{}), Enum.into(globals, %{}), normalize_slots(slots), "nofile", 0)
  end

  @doc false
  @spec render!(module(), attributes(), attributes(), map(), Path.t(), non_neg_integer()) :: iodata()
  def render!(component, attrs, globals, slot_content, file, line) do
    case validate_attrs(component, attrs, globals, slot_content) do
      {:ok, state} ->
        case component.handle_state(state) do
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
        description = "no `attr` declarations in component #{inspect(component)}"
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

  defp validate_attrs(component, attrs, globals, slot_content) do
    if function_exported?(component, :__vaux__, 1) do
      case JSV.validate(attrs, component.__vaux__(:schema)) do
        {:ok, attrs} ->
          attrs = atomize(attrs)
          attrs = Map.put(attrs, :__globals__, globals)
          {:ok, struct(component, Map.merge(attrs, slot_content))}

        {:error, e} ->
          {:error, e}
      end
    else
      case Code.ensure_loaded(component) do
        {:module, _} ->
          if function_exported?(component, :__vaux__, 1),
            do: validate_attrs(component, attrs, globals, slot_content),
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

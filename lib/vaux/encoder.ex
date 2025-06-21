alias Vaux.Component.Compiler

defprotocol Vaux.Encoder do
  @spec encode(t()) :: String.t()
  def encode(value)
end

defimpl Vaux.Encoder, for: Atom do
  def encode(nil), do: ""
  def encode(atom), do: Compiler.html_escape(Atom.to_string(atom))
end

defimpl Vaux.Encoder, for: BitString do
  defdelegate encode(data), to: Compiler, as: :html_escape
end

defimpl Vaux.Encoder, for: Time do
  defdelegate encode(data), to: Time, as: :to_iso8601
end

defimpl Vaux.Encoder, for: Date do
  defdelegate encode(data), to: Date, as: :to_iso8601
end

defimpl Vaux.Encoder, for: NaiveDateTime do
  defdelegate encode(data), to: NaiveDateTime, as: :to_iso8601
end

defimpl Vaux.Encoder, for: DateTime do
  def encode(data) do
    # Call escape in case someone can inject reserved
    # characters in the timezone or its abbreviation
    Compiler.html_escape(DateTime.to_iso8601(data))
  end
end

if Code.ensure_loaded?(Duration) do
  defimpl Vaux.Encoder, for: Duration do
    defdelegate encode(data), to: Duration, as: :to_iso8601
  end
end

defimpl Vaux.Encoder, for: List do
  def encode(list), do: recur(list)

  defp recur([h | t]), do: [recur(h) | recur(t)]
  defp recur([]), do: []

  defp recur(?<), do: "&lt;"
  defp recur(?>), do: "&gt;"
  defp recur(?&), do: "&amp;"
  defp recur(?"), do: "&quot;"
  defp recur(?'), do: "&#39;"

  defp recur(h) when is_integer(h) and h <= 255 do
    h
  end

  defp recur(h) when is_integer(h) do
    raise ArgumentError,
          "lists in Vaux components only support iodata, and not chardata. Integers may only represent bytes. " <>
            "It's likely you meant to pass a string with double quotes instead of a char list with single quotes."
  end

  defp recur(h) when is_binary(h) do
    Compiler.html_escape(h)
  end

  defp recur({:safe, data}) do
    data
  end

  defp recur(other) do
    raise ArgumentError,
          "lists in Vaux and components may only contain integers representing bytes, binaries or other lists, " <>
            "got invalid entry: #{inspect(other)}"
  end
end

defimpl Vaux.Encoder, for: Integer do
  defdelegate encode(data), to: Integer, as: :to_string
end

defimpl Vaux.Encoder, for: Float do
  defdelegate encode(data), to: Float, as: :to_string
end

defimpl Vaux.Encoder, for: URI do
  def encode(data), do: Compiler.html_escape(URI.to_string(data))
end

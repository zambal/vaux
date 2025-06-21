defmodule Vaux.CompileError do
  defexception [:file, :line, :description]

  def message(%{file: file, line: line, description: description}) do
    location = Exception.format_file_line_column(Path.relative_to_cwd(file), line, 0)
    location <> " " <> description
  end
end

defmodule Vaux.RuntimeError do
  @errors ~w(noschema nofile validation init)a

  @type t :: %__MODULE__{
          file: Path.t(),
          line: non_neg_integer(),
          error: :noschema | :nofile | :validation | :init,
          description: String.t()
        }

  defexception [:file, :line, :error, :description]

  def message(%{file: file, line: line, error: error, description: description}) when error in @errors do
    location =
      case file do
        "nofile" ->
          ":"

        path ->
          Exception.format_file_line_column(Path.relative_to_cwd(path), line, 0)
      end

    "(#{error}) " <> location <> " " <> description
  end

  def errors, do: @errors
end

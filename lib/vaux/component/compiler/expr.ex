defmodule Vaux.Component.Compiler.Expr do
  alias __MODULE__

  defstruct ast: nil, dir: nil, slot_key: nil, type: nil, tag: nil, line: 0

  @type t :: %Expr{}

  def new(ast, tag, dir, slot_key, line) do
    type = Vaux.Component.Compiler.Node.get_type_from_tag(tag)

    slot_key =
      case slot_key do
        [key] when is_atom(key) -> key
        key when is_atom(key) -> key
        _ -> nil
      end

    ast =
      case ast do
        [ast] -> ast
        ast -> ast
      end

    %Expr{ast: ast, tag: tag, dir: dir, slot_key: slot_key, type: type, line: line}
  end

  def noop do
    %Expr{tag: :characters, ast: "", type: :content}
  end
end

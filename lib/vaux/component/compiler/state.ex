defmodule Vaux.Component.Compiler.State do
  alias Vaux.Component.Compiler.{Expr, State}

  @type t :: %State{
          env: Macro.Env.t(),
          acc: [Macro.t()],
          stack: [Expr.t()],
          assigns_used: :ordsets.ordset(atom())
        }

  defstruct env: nil, acc: [], stack: [], assigns_used: []

  def new(%State{env: env}) do
    %State{env: env}
  end

  def concat(%State{acc: []} = state, value) do
    %{state | acc: List.wrap(value)}
  end

  def concat(%State{acc: acc} = state, value) do
    %{state | acc: concat_acc(acc, reverse(value))}
  end

  def concat_and_flush(%State{} = state, value) do
    concat(%{state | stack: []}, value)
  end

  def push_stack(%State{stack: stack} = state, node) do
    %{state | stack: [node | stack]}
  end

  def pop_stack(%State{stack: [node | rest]} = state) do
    {node, %{state | stack: rest}}
  end

  def pop_stack(%State{stack: []} = state) do
    state
  end

  def add_assign(%State{assigns_used: used} = state, assign) do
    %{state | assigns_used: :ordsets.add_element(assign, used)}
  end

  def merge_assigns_used(%State{assigns_used: a1} = state, %State{assigns_used: a2}) do
    %{state | assigns_used: :ordsets.union(a1, a2)}
  end

  defp concat_acc(acc, [value | rest]), do: concat_acc(concat_acc(acc, value), rest)
  defp concat_acc(acc, []), do: acc
  defp concat_acc([bin | rest], value) when is_binary(bin) and is_binary(value), do: [value <> bin | rest]
  defp concat_acc(acc, value), do: [value | acc]

  defp reverse(list) when is_list(list), do: :lists.reverse(list)
  defp reverse(x), do: x
end

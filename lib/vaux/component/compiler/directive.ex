defmodule Vaux.Component.Compiler.Directive do
  @moduledoc false

  defmacrop maybe_to_binary(expr) do
    if Application.get_env(:vaux, :render_to_binary, true) do
      quote do
        Vaux.Component.Compiler.to_binary(unquote(expr))
      end
    else
      quote do
        unquote(expr)
      end
    end
  end

  def for(generator, expr, line) do
    quote line: line do
      for unquote(generator), into: "", do: unquote(maybe_to_binary(expr))
    end
  end

  def if_else_fallback(test, expr, line) do
    quote line: line do
      if unquote(test), do: unquote(maybe_to_binary(expr)), else: ""
    end
  end

  def if_else(test, if_expr, else_expr, line) do
    quote line: line do
      if unquote(test),
        do: unquote(maybe_to_binary(if_expr)),
        else: unquote(maybe_to_binary(else_expr))
    end
  end

  def cond_clause(test, expr, line) do
    hd(
      quote line: line do
        (unquote(test) -> unquote(maybe_to_binary(expr)))
      end
    )
  end

  def cond_fallback(line) do
    hd(
      quote line: line do
        (true -> "")
      end
    )
  end

  def cond(clauses, line) do
    quote line: line do
      cond(do: unquote(clauses))
    end
  end

  def case_clause(pattern, expr, line) do
    hd(
      quote line: line do
        (unquote(pattern) -> unquote(maybe_to_binary(expr)))
      end
    )
  end

  def case(case_expr, clauses, line) do
    quote line: line do
      case(unquote(case_expr), do: unquote(clauses))
    end
  end
end

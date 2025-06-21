defmodule Vaux.StateTest do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test "custom state" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title, :string

      defstate [:my_title]

      def init(%{title: title}, _slot) do
        {:ok, state(%{my_title: title})}
      end

      ~H"""
        <h1>{@my_title}</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result
  end

  test "invalid state" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title, :string

      defstate [:my_title]

      def init(%{title: title}, _slot) do
        {:ok, %{my_title: title}}
      end

      ~H"""
        <h1>{@my_title}</h1>
      """vaux
    end

    result = Vaux.render(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert {:error, %Vaux.RuntimeError{error: :init}} = result
  end
end

defmodule Vaux.StateTest do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test "custom handler" do
    defmodule TestComponent do
      import Vaux.Component

      attr :title, :string

      var my_var: 42

      ~H"""
        <h1>{"#{@title} - #{@my_var}"}</h1>
      """vaux

      def handle_state(%{title: title} = state) do
        {:ok, %{state | title: String.upcase(title)}}
      end
    end

    result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<h1>HELLO WORLD - 42</h1>" = result
  end

  test "invalid state" do
    defmodule TestComponent do
      import Vaux.Component

      attr :title, :string
      var :my_var

      def handle_state(%{title: title}) do
        {:ok, %{my_title: title}}
      end

      ~H"""
        <h1>{"#{@title} - #{@my_var}"}</h1>
      """vaux
    end

    result = Vaux.render(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert {:error, %Vaux.RuntimeError{error: :init}} = result
  end
end

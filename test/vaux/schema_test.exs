defmodule Vaux.SchemaTest do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test "optional attribute of any type" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title, :string
      defattr :optional

      ~H"""
        <h1 class={@optional}>{@title}</h1>
      """vaux
    end

    result_excluded = Vaux.render!(TestComponent, %{"title" => "Hello World"})
    result_included = Vaux.render!(TestComponent, %{"title" => "Hello World", "optional" => true})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result_excluded
    assert "<h1 class=\"\">Hello World</h1>" = result_included
  end

  test "enum attribute" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :fruit, {:enum, ~w(apple banana orange)}

      ~H"""
        <p>{@fruit}</p>
      """vaux
    end

    ok_result1 = Vaux.render!(TestComponent, %{"fruit" => "banana"})
    ok_result2 = Vaux.render!(TestComponent, %{})
    invalid_result = Vaux.render(TestComponent, %{"fruit" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<p>banana</p>" == ok_result1
    assert "<p></p>" == ok_result2
    assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result
  end

  test "const attribute" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :answer, {:const, 42}, required: true

      ~H"""
        <p>{@answer}</p>
      """vaux
    end

    ok_result = Vaux.render!(TestComponent, %{"answer" => 42})
    invalid_result1 = Vaux.render(TestComponent, %{})
    invalid_result2 = Vaux.render(TestComponent, %{"answer" => "42"})

    TestHelper.unload(TestComponent)

    assert "<p>42</p>" = ok_result
    assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result1
    assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result2
  end

  test "disallow extra attributes" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title, :string

      ~H"""
        <h1>{@title}</h1>
      """vaux
    end

    result = Vaux.render(TestComponent, %{"title" => "Hello World", "extra" => "value"})
    TestHelper.unload(TestComponent)

    assert {:error, %Vaux.RuntimeError{error: :validation}} = result
  end
end

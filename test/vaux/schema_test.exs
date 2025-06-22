defmodule Vaux.SchemaTest do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test "optional attribute of any type" do
    defmodule TestComponent do
      use Vaux.Component

      attr :title, :string
      attr :optional

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

      attr :fruit, {:enum, ~w(apple banana orange)}

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

      attr :answer, {:const, 42}, required: true

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

  test "array with inner type" do
    defmodule TestComponent do
      use Vaux.Component

      attr :binary, {:array, [0, 1]}

      ~H"""
        <code :for={b <- @binary}>{b}</code>
      """vaux
    end

    ok_result1 = Vaux.render!(TestComponent, %{"binary" => [1, 0, 1, 0, 1, 0]})
    ok_result2 = Vaux.render!(TestComponent, %{"binary" => []})
    invalid_result1 = Vaux.render(TestComponent, %{"binary" => [42]})
    invalid_result2 = Vaux.render(TestComponent, %{"binary" => 0})

    TestHelper.unload(TestComponent)

    assert "<code>1</code><code>0</code><code>1</code><code>0</code><code>1</code><code>0</code>" = ok_result1
    assert "" = ok_result2
    assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result1
    assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result2
  end

  test "disallow extra attributes" do
    defmodule TestComponent do
      use Vaux.Component

      attr :title, :string

      ~H"""
        <h1>{@title}</h1>
      """vaux
    end

    result = Vaux.render(TestComponent, %{"title" => "Hello World", "extra" => "value"})
    TestHelper.unload(TestComponent)

    assert {:error, %Vaux.RuntimeError{error: :validation}} = result
  end

  test "invalid attribute field" do
    assert_raise Vaux.CompileError, ~r/.*expects an atom.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        attr "invalid"

        ~H"""
          <h1>Hello World</h1>
        """vaux
      end
    end
  end

  test "invalid attribute type" do
    assert_raise Vaux.CompileError, ~r/.*invalid type.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        attr :title, :oops

        ~H"""
          <h1>{@title}</h1>
        """vaux
      end
    end
  end

  test "invalid attribute inner type" do
    assert_raise Vaux.CompileError, ~r/.*invalid inner type.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        attr :title, {:array, :oops}

        ~H"""
          <h1>{@title}</h1>
        """vaux
      end
    end
  end

  test "invalid attribute option" do
    assert_raise Vaux.CompileError, ~r/.*invalid option.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        attr :binary, {:array, ~w(0 1)}, oops: 0

        ~H"""
          <h1>{@title}</h1>
        """vaux
      end
    end
  end

  test "complex attribute type" do
    defmodule TestComponent do
      use Vaux.Component

      attr :persons, :array,
        required: true,
        items: %{
          name: :string,
          year_of_birth: {:integer, minimum: 0, maximum: Date.utc_today().year}
        }

      ~H"""
        <div :for={%{name: name, year_of_birth: year} <- @persons}>
          <p>{name}</p>
          <p>{year}</p>
        </div>
      """vaux
    end

    ok_result =
      Vaux.render!(TestComponent, %{
        "persons" => [%{"name" => "Bob", "year_of_birth" => 34}, %{"name" => "Alice", "year_of_birth" => 36}]
      })

    # invalid_result1 = Vaux.render(TestComponent, %{})
    # invalid_result2 = Vaux.render(TestComponent, %{"answer" => "42"})

    TestHelper.unload(TestComponent)

    assert "<div><p>Bob</p><p>34</p></div><div><p>Alice</p><p>36</p></div>" = ok_result
    # assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result1
    # assert {:error, %Vaux.RuntimeError{error: :validation}} = invalid_result2
  end
end

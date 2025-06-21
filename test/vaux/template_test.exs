defmodule VauxTest.Template do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test "no vaux modifier" do
    assert_raise Vaux.CompileError, ~r/.*sigil.*/, fn ->
      defmodule TestComponent do
        import Vaux.Component

        ~H"""
          <h1>Hello World</h1>
        """
      end
    end
  end

  test "no defattr" do
    defmodule TestComponent do
      import Vaux.Component

      ~H"""
        <h1>Hello World</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent, %{})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result
  end

  test "hello world" do
    defmodule TestComponent do
      import Vaux.Component
      @behaviour Vaux.Component

      defattr :title, :string

      ~H"""
        <h1>{@title}</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result
  end

  test "hello world using use" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title, :string

      ~H"""
        <h1>{@title}</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result
  end

  test "conditional attribute" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :title
      defattr :conditional

      ~H"""
        <h1 enabled={@conditional}>{@title}</h1>
      """vaux
    end

    true_result = Vaux.render!(TestComponent, %{"title" => true, "conditional" => true})
    false_result = Vaux.render!(TestComponent, %{"title" => false, "conditional" => false})
    nil_result = Vaux.render!(TestComponent, %{"title" => nil, "conditional" => nil})
    void_result = Vaux.render!(TestComponent, %{})
    empty_result = Vaux.render!(TestComponent, %{"title" => "", "conditional" => ""})

    TestHelper.unload(TestComponent)

    assert "<h1 enabled=\"\">true</h1>" = true_result
    assert "<h1>false</h1>" = false_result
    assert "<h1></h1>" = nil_result
    assert "<h1></h1>" = void_result
    assert "<h1 enabled=\"\"></h1>" = empty_result
  end
end

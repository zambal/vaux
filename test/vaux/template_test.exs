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

  test "no attr" do
    defmodule TestComponent do
      import Vaux.Component

      ~H"""
        <h1>Hello World</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent)

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World</h1>" = result
  end

  test "hello world" do
    defmodule TestComponent do
      import Vaux.Component
      @behaviour Vaux.Component

      attr :title, :string

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
      import Vaux.Component

      attr :title, :string

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
      import Vaux.Component

      attr :title
      attr :conditional

      ~H"""
        <h1 enabled={@conditional}>{@title}</h1>
      """vaux
    end

    true_result = Vaux.render!(TestComponent, %{"title" => true, "conditional" => true})
    false_result = Vaux.render!(TestComponent, %{"title" => false, "conditional" => false})
    nil_result = Vaux.render!(TestComponent, %{"title" => nil, "conditional" => nil})
    void_result = Vaux.render!(TestComponent)
    empty_result = Vaux.render!(TestComponent, %{"title" => "", "conditional" => ""})

    TestHelper.unload(TestComponent)

    assert "<h1 enabled=\"\">true</h1>" = true_result
    assert "<h1>false</h1>" = false_result
    assert "<h1></h1>" = nil_result
    assert "<h1></h1>" = void_result
    assert "<h1 enabled=\"\"></h1>" = empty_result
  end

  test "void elements" do
    defmodule TestComponent do
      import Vaux.Component

      ~H"""
        <img src=""></img>
        <br>
        <input type="number" value="42">
        <br/>
      """vaux
    end

    result = Vaux.render!(TestComponent)

    TestHelper.unload(TestComponent)

    assert "<img src=\"\"/><br/><input type=\"number\" value=\"42\"/><br/>" = result
  end

  test "expression parsing" do
    defmodule TestComponent do
      import Vaux.Component

      ~H"""
        <div id={"}"}>{~s|\|}|}{"ab\"}cd"}</div>
      """vaux
    end

    result = Vaux.render!(TestComponent)

    TestHelper.unload(TestComponent)

    assert "<div id=\"}\">|}ab&quot;}cd</div>" = result
  end

  test "assigns in script and style tags" do
    defmodule TestComponent do
      import Vaux.Component

      attr :number, :integer, default: 42

      ~H"""
        <h1>
          {@number}
        </h1>
        <script>
          var a = {1 + 1};
          var b = {@number};
          var c = 303;
        </script>
        <style>
        .test {
          max-height: {@number}px;
        }
        </style>
      """vaux
    end

    result = Vaux.render!(TestComponent)

    TestHelper.unload(TestComponent)

    expected =
      "<h1>42</h1><script>var a = {1 + 1}; var b = 42; var c = 303;</script><style>.test { max-height: 42px; }</style>"

    assert expected == result
  end
end

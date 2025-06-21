defmodule Vaux.DirectiveTest do
  use ExUnit.Case, async: true
  alias Vaux.TestHelper

  test ":if directive" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :greet, :boolean
      defattr :title, :string

      ~H"""
        <div>
          <a></a>
          <h1 :if={@greet}>{@title}</h1>
          <b></b>
        </div>
      """vaux
    end

    true_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => true})
    false_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => false})
    nil_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>Hello World</h1><b></b></div>" = true_result
    assert "<div><a></a><b></b></div>" = false_result
    assert "<div><a></a><b></b></div>" = nil_result
  end

  test ":if :else directives" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :greet, :boolean
      defattr :title, :string

      ~H"""
        <div>
          <a></a>
          <h1 :if={@greet}>{@title}</h1>
          <h1 :else>No greet today</h1>
          <b></b>
        </div>
      """vaux
    end

    true_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => true})
    false_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => false})
    nil_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>Hello World</h1><b></b></div>" = true_result
    assert "<div><a></a><h1>No greet today</h1><b></b></div>" = false_result
    assert "<div><a></a><h1>No greet today</h1><b></b></div>" = nil_result
  end

  test "invalid :if :else directives" do
    assert_raise Vaux.CompileError, ~r/.*:else.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        defattr :greet, :boolean
        defattr :title, :string

        ~H"""
          <div>
            <a></a>
            <h1 :if={@greet}>{@title}</h1>
            <oops></oops>
            <h1 :else>No greet today</h1>
            <b></b>
          </div>
        """vaux
      end
    end
  end

  test "single :cond directive" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :greet, :boolean
      defattr :title, :string

      ~H"""
        <div>
          <a></a>
          <h1 :cond={@greet}>{@title}</h1>
          <b></b>
        </div>
      """vaux
    end

    true_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => true})
    false_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "greet" => false})
    nil_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>Hello World</h1><b></b></div>" = true_result
    assert "<div><a></a><b></b></div>" = false_result
    assert "<div><a></a><b></b></div>" = nil_result
  end

  test "multiple :cond directives" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :count, :integer
      defattr :title, :string

      ~H"""
        <div>
          <h1 :cond={is_nil(@count)}>{@title}</h1>
          <h1 :cond={@count > 1}>Hello Venus</h1>
          <h1 :cond={@count > 0}>Hello Mercury</h1>
        </div>
      """vaux
    end

    world_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})
    venus_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 2})
    mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 1})
    no_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 0})

    TestHelper.unload(TestComponent)

    assert "<div><h1>Hello World</h1></div>" = world_result
    assert "<div><h1>Hello Venus</h1></div>" = venus_result
    assert "<div><h1>Hello Mercury</h1></div>" = mercury_result
    assert "<div></div>" = no_result
  end

  test "multiple :cond directives enclosed" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :count, :integer
      defattr :title, :string

      ~H"""
        <div>
          <a></a>
          <h1 :cond={is_nil(@count)}>{@title}</h1>
          <h1 :cond={@count > 1}>Hello Venus</h1>
          <h1 :cond={@count > 0}>Hello Mercury</h1>
          <b></b>
        </div>
      """vaux
    end

    world_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})
    venus_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 2})
    mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 1})
    no_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 0})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>Hello World</h1><b></b></div>" = world_result
    assert "<div><a></a><h1>Hello Venus</h1><b></b></div>" = venus_result
    assert "<div><a></a><h1>Hello Mercury</h1><b></b></div>" = mercury_result
    assert "<div><a></a><b></b></div>" = no_result
  end

  test "mixed :cond directives" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :count, :integer
      defattr :title, :string

      ~H"""
        <div>
          <a></a>
          <h1 :cond={is_nil(@count)}>{@title}</h1>
          <h1 :cond={@count > 1}>Hello Venus</h1>
          <b></b>
          <h1 :cond={@count > 0}>Hello Mercury</h1>
          <c></c>
        </div>
      """vaux
    end

    world_mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})
    venus_mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 2})
    mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 1})
    no_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 0})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>Hello World</h1><b></b><h1>Hello Mercury</h1><c></c></div>" = world_mercury_result
    assert "<div><a></a><h1>Hello Venus</h1><b></b><h1>Hello Mercury</h1><c></c></div>" = venus_mercury_result
    assert "<div><a></a><b></b><h1>Hello Mercury</h1><c></c></div>" = mercury_result
    assert "<div><a></a><b></b><c></c></div>" = no_result
  end

  test "mixed :cond :else directives" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :count, :integer
      defattr :title, :string

      ~H"""
        <div>
          <h1 :cond={is_nil(@count)}>{@title}</h1>
          <h1 :cond={@count > 1}>Hello Venus</h1>
          <h1 :else>Void</h1>
          <b></b>
          <h1 :cond={@count > 0}>Hello Mercury</h1>
          <h1 :else>More void</h1>
          <c></c>
        </div>
      """vaux
    end

    world_mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World"})
    venus_mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 2})
    else_mercury_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 1})
    else_else_result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 0})

    TestHelper.unload(TestComponent)

    assert "<div><h1>Hello World</h1><b></b><h1>Hello Mercury</h1><c></c></div>" = world_mercury_result
    assert "<div><h1>Hello Venus</h1><b></b><h1>Hello Mercury</h1><c></c></div>" = venus_mercury_result
    assert "<div><h1>Void</h1><b></b><h1>Hello Mercury</h1><c></c></div>" = else_mercury_result
    assert "<div><h1>Void</h1><b></b><h1>More void</h1><c></c></div>" = else_else_result
  end

  test ":case :clause directives" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :point

      ~H"""
        <div :case={@point}>
          <a></a>
          <h1 :clause={{0, 0}}>A</h1>
          <h1 :clause={{1, 1}}>B</h1>
          <h1 :clause={{2, 2}}>C</h1>
          <h1 :clause={_}>?</h1>
          <b></b>
        </div>
      """vaux
    end

    result_A = Vaux.render!(TestComponent, %{"point" => {0, 0}})
    result_B = Vaux.render!(TestComponent, %{"point" => {1, 1}})
    result_C = Vaux.render!(TestComponent, %{"point" => {2, 2}})
    result_? = Vaux.render!(TestComponent, %{"point" => 0})

    TestHelper.unload(TestComponent)

    assert "<div><a></a><h1>A</h1><b></b></div>" = result_A
    assert "<div><a></a><h1>B</h1><b></b></div>" = result_B
    assert "<div><a></a><h1>C</h1><b></b></div>" = result_C
    assert "<div><a></a><h1>?</h1><b></b></div>" = result_?
  end

  test "invalid :case :clause directives" do
    assert_raise Vaux.CompileError, ~r/.*:clause.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        defattr :point

        ~H"""
          <div :case={@point}>
            <a></a>
            <h1 :clause={{0, 0}}>A</h1>
            <h1 :clause={{1, 1}}>B</h1>
            <oops></oops>
            <h1 :clause={{2, 2}}>C</h1>
            <h1 :clause={_}>?</h1>
            <b></b>
          </div>
        """vaux
      end
    end
  end

  test "missing :case directive" do
    assert_raise Vaux.CompileError, ~r/.*:case.*/, fn ->
      defmodule TestComponent do
        use Vaux.Component

        defattr :point

        ~H"""
          <div>
            <a></a>
            <h1 :clause={{0, 0}}>A</h1>
            <h1 :clause={{1, 1}}>B</h1>
            <h1 :clause={{2, 2}}>C</h1>
            <h1 :clause={_}>?</h1>
            <b></b>
          </div>
        """vaux
      end
    end
  end

  test ":for directive" do
    defmodule TestComponent do
      use Vaux.Component

      defattr :count, :integer
      defattr :title, :string

      ~H"""
        <h1 :for={n <- 1..@count}>{"#{@title} - #{n}"}</h1>
      """vaux
    end

    result = Vaux.render!(TestComponent, %{"title" => "Hello World", "count" => 3})

    TestHelper.unload(TestComponent)

    assert "<h1>Hello World - 1</h1><h1>Hello World - 2</h1><h1>Hello World - 3</h1>" = result
  end
end

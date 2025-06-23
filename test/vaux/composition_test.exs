defmodule Vaux.CompositionTest do
  use ExUnit.Case, async: true
  alias Vaux.CompositionTest.TestComponent
  alias Vaux.TestHelper

  test "call another component" do
    defmodule OtherComponent do
      import Vaux.Component

      attr :title, :string, required: true
      attr :sub_title, :string

      ~H"""
      <body>
        <header>
          <h1>{@title}</h1>
          <h3>{@sub_title}</h3>
        </header>
        <footer>
          <v-slot>FALLBACK</v-slot>
        </footer>
      </body>
      """vaux
    end

    defmodule TestComponent do
      import Vaux.Component

      components [
        OtherComponent
      ]

      attr :title, :string
      attr :sub_title, :string
      attr :footer, :integer

      ~H"""
        <html>
          <OtherComponent title={@title} sub_title={@sub_title}>
            {@footer}
          </OtherComponent>
        </html>
      """vaux
    end

    expected = "<html><body><header><h1>Hello World</h1><h3>and beyond</h3></header><footer>42</footer></body></html>"
    result = Vaux.render!(TestComponent, %{"title" => "Hello World", "sub_title" => "and beyond", "footer" => 42})
    TestHelper.unload(TestComponent)

    assert expected == result
  end

  test "named slots" do
    defmodule OtherComponent4 do
      import Vaux.Component

      slot :header
      slot :footer

      ~H"""
      <body>
        <header>
          <v-slot #header>FALLBACK</v-slot>
        </header>
        <footer>
          <v-slot #footer>FALLBACK</v-slot>
        </footer>
      </body>
      """vaux
    end

    defmodule TestComponent do
      import Vaux.Component
      require OtherComponent4

      ~H"""
        <html>
          <OtherComponent4>
            <v-template #header>
              <h1>Hello World</h1>
            </v-template>
            <v-template #footer>
              <a href="/solar-system">and beyond</a>
            </v-template>
          </OtherComponent4>
        </html>
      """vaux
    end

    expected =
      "<html><body><header><h1>Hello World</h1></header><footer><a href=\"/solar-system\">and beyond</a></footer></body></html>"

    result = Vaux.render!(TestComponent, %{})
    TestHelper.unload(TestComponent)

    assert expected == result
  end

  test "invalid attribute call" do
    assert_raise Vaux.CompileError, ~r/.invalid.*/, fn ->
      defmodule OtherComponent2 do
        import Vaux.Component

        attr :title, :string, required: true
        attr :sub_title, :string

        ~H"""
        <header>
          <h1>{@title}</h1>
          <h3>{@sub_title}</h3>
        </header>
        """vaux
      end

      defmodule TestComponent do
        import Vaux.Component
        require OtherComponent2

        attr :title
        attr :sub_title

        ~H"""
          <OtherComponent2 title={@title} sub_title2={@sub_title}/>
        """vaux
      end
    end
  end

  test "template missing attribute call" do
    assert_raise Vaux.CompileError, ~r/.required.*/, fn ->
      defmodule OtherComponent3 do
        import Vaux.Component

        attr :title, :string, required: true
        attr :sub_title, :string

        ~H"""
        <header>
          <h1>{@title}</h1>
          <h3>{@sub_title}</h3>
        </header>
        """vaux
      end

      defmodule TestComponent do
        import Vaux.Component
        require OtherComponent3

        attr :sub_title

        ~H"""
          <OtherComponent3 sub_title={@sub_title}/>
        """vaux
      end
    end
  end

  test "missing template call" do
    assert_raise Vaux.CompileError, fn ->
      defmodule TestComponent do
        import Vaux.Component

        attr :title

        ~H"""
          <OtherComponent5 title={@title}/>
        """vaux
      end
    end
  end
end

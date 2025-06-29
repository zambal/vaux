defmodule Vaux.CompositionTest do
  use ExUnit.Case, async: true
  alias Vaux.CompositionTest.OtherComponentA
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
          <slot>FALLBACK</slot>
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

  test "call another component with :bind and :let" do
    defmodule OtherComponentA do
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
          <slot :bind={String.upcase(@title)}>FALLBACK</slot>
        </footer>
      </body>
      """vaux
    end

    defmodule TestComponent do
      import Vaux.Component

      components [
        OtherComponentA
      ]

      attr :title, :string
      attr :sub_title, :string

      ~H"""
        <html>
          <OtherComponentA title={@title} sub_title={@sub_title} :let={upcased}>
            {upcased}
          </OtherComponentA>
        </html>
      """vaux
    end

    expected =
      "<html><body><header><h1>Hello World</h1><h3>and beyond</h3></header><footer>HELLO WORLD</footer></body></html>"

    result = Vaux.render!(TestComponent, %{"title" => "Hello World", "sub_title" => "and beyond"})
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
          <slot #header>FALLBACK</slot>
        </header>
        <footer>
          <slot #footer>FALLBACK</slot>
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
            <template #header>
              <h1>Hello World</h1>
            </template>
            <template #footer>
              <a href="/solar-system">and beyond</a>
            </template>
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

  test "named slots with :bind and :let" do
    defmodule OtherComponent5 do
      import Vaux.Component

      attr :test, :string

      slot :header
      slot :footer

      ~H"""
      <body>
        <header>
          <slot #header :bind={String.upcase(@test)}>FALLBACK</slot>
        </header>
        <footer>
          <slot #footer>FALLBACK</slot>
        </footer>
      </body>
      """vaux
    end

    defmodule TestComponent do
      import Vaux.Component
      require OtherComponent5

      ~H"""
        <html>
          <OtherComponent5 test="hello world">
            <template #header :let={upcased}>
              <h1>{upcased}</h1>
            </template>
            <template #footer>
              <a href="/solar-system">and beyond</a>
            </template>
          </OtherComponent5>
        </html>
      """vaux
    end

    expected =
      "<html><body><header><h1>HELLO WORLD</h1></header><footer><a href=\"/solar-system\">and beyond</a></footer></body></html>"

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

  test "complex composition with root module" do
    defmodule Complex.Layout do
      import Vaux.Component

      attr :lang, :string
      slot :pre_head
      slot :head
      slot :main
      slot :footer
      slot :footer2

      ~H"""
        <html lang={@lang}>
          <head>
            <slot #pre_head>
              <meta charset="UTF-8" />
              <meta name="viewport" content="width=device-width" />
            </slot>
            <slot #head></slot>
          </head>
          <body>
            <main><slot #main></slot></main>
            <footer>
              <slot #footer ></slot>
              <slot #footer2 :bind={"FOOTER2"} ></slot>
            </footer>
          </body>
        </html>
      """vaux
    end

    defmodule Complex.Person do
      import Vaux.Component

      var person: %{
            name: "Jan Jansen",
            birth_date: ~D[1977-07-07],
            birth_place: "Amsterdam",
            country: "Netherlands"
          }

      ~H"""
       <table>
         <caption>
           Persons
         </caption>
         <thead>
           <tr>
             <th scope="col">Name</th>
             <th scope="col">Birth Date</th>
             <th scope="col">Birth Place</th>
             <th scope="col">Country</th>
           </tr>
         </thead>
         <tbody>
           <tr >
              <slot :bind={@person}></slot>
           </tr>
         </tbody>
       </table>
      """vaux
    end

    defmodule Complex.Root do
      import Vaux.Root

      components Vaux.CompositionTest.Complex.{Layout, Person}

      const title: "Hello World"
    end

    defmodule Complex.Page do
      use Complex.Root

      attr :number, :number

      ~H"""
      <Layout lang="en">
        <template #head>
          <title>{@!title}</title>
        </template>

        <template #main>
          <Person :let={user}>
           <th>{user.name}</th>
           <th>{user.birth_date}</th>
           <th>{user.birth_place}</th>
           <th>{user.country}</th>
          </Person>
          <Person>
           <th>{1}</th>
           <th>{2}</th>
           <th>{3}</th>
           <th>{4}</th>
          </Person>
        </template>

        <template #footer>
          <p>{"It's always #{@number}"}</p>
          <p>{"It's always #{@number}"}</p>
          <p>{"It's always #{@number}"}</p>
          <p>{"It's always #{@number}"}</p>
        </template>
        <template #footer2 :let={f}>
          <p>{"#{f}-1"}</p>
          <p>{"#{f}-2"}</p>
          <p>{"#{f}-3"}</p>
          <p>{"#{f}-4"}</p>
        </template>
      </Layout>
      """vaux
    end

    expected =
      """
      <html lang="en">
        <head>
            <meta charset="UTF-8"/>
            <meta name="viewport" content="width=device-width"/>
            <title>Hello World</title>
        </head>
        <body>
          <main>
            <table>
             <caption>
               Persons
             </caption>
             <thead>
               <tr>
                 <th scope="col">Name</th>
                 <th scope="col">Birth Date</th>
                 <th scope="col">Birth Place</th>
                 <th scope="col">Country</th>
               </tr>
             </thead>
             <tbody>
               <tr>
                 <th>Jan Jansen</th>
                 <th>1977-07-07</th>
                 <th>Amsterdam</th>
                 <th>Netherlands</th>
               </tr>
             </tbody>
            </table>
            <table>
             <caption>
               Persons
             </caption>
             <thead>
               <tr>
                 <th scope="col">Name</th>
                 <th scope="col">Birth Date</th>
                 <th scope="col">Birth Place</th>
                 <th scope="col">Country</th>
               </tr>
             </thead>
             <tbody>
               <tr>
                 <th>1</th>
                 <th>2</th>
                 <th>3</th>
                 <th>4</th>
               </tr>
             </tbody>
            </table>
          </main>
          <footer>
            <p>It&#39;s always 42</p>
            <p>It&#39;s always 42</p>
            <p>It&#39;s always 42</p>
            <p>It&#39;s always 42</p>
            <p>FOOTER2-1</p>
            <p>FOOTER2-2</p>
            <p>FOOTER2-3</p>
            <p>FOOTER2-4</p>
          </footer>
        </body>
      </html>
      """
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.join()

    result = Vaux.render!(Complex.Page, %{"number" => 42})
    TestHelper.unload(Complex.Page)

    assert expected == result
  end
end

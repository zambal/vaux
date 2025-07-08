# Overview

## Installation

The package can be installed by adding `vaux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vaux, "~> 0.3"}
  ]
end
```


## Introduction

Vaux (rhymes with yo) provides composable html templates for Elixir. It uses 
a customized verion of the excellent html parsing library 
[htmerl](https://hex.pm/packages/htmerl) to offer a simple, but still 
expressive template syntax.

It builds upon HEEx template syntax, which means it offers good editor support 
out of the box.

A minimal example looks like this:

```elixir
  defmodule Component.Example1 do
    import Vaux.Component

    attr :title, :string

    ~H"""
    <h1>{@title}</h1>
    """vaux
  end

  iex> Vaux.render!(Component.Example1, %{"title" => "Hello World"})
  "<h1>Hello World</h1>"
```

If you are familiar with Phoenix components, a Vaux component will look pretty 
similar, as it uses the same sigil and template expression syntax as HEEx 
templates. To make sure HEEx and Vaux templates can't be mixed up, Vaux 
requires the `vaux` modifier for its `~H` sigil. A key difference is that Vaux, 
at least at the moment, only supports a single template per module.

In order to call another component, it needs to be known at compile time. Vaux 
provides the `components/1` macro that both requires and aliases components:

```elixir
  defmodule Component.Example2 do
    import Vaux.Component

    attr :title, :string

    ~H"""
    <title>{@title}</title>
    """vaux
  end

  defmodule Page.Page1 do
    import Vaux.Component

    components Component.{Example1, Example2}

    var title: "Hello World"

    ~H"""
    <html>
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width"/>
        <Example2 title={@title}/>
      </head>
      <body>
        <Example1 title={@title}/>
      </body>
    </html>
    """vaux
  end

  iex> Vaux.render!(Page.Page1)
  "<html><head><meta charset=\"UTF-8\"/><meta name=\"viewport\" content=\"width=device-width\"/><title>Hello World</title></head><body><h1>Hello World</h1></body></html>"
```


## Slots

Every component has a default slot that holds the element's content:

```elixir

  defmodule Layout.Layout1 do
    import Vaux.Component

    ~H"""
    <html>
      <body>
        <slot><p>FALLBACK CONTENT</p></slot>
      </body>
    </html>
    """vaux
  end

  defmodule Page.Page2 do
    import Vaux.Component

    components [
      Component.Example1,
      Layout.Layout1
    ]

    ~H"""
    <Layout1>
      <Example1 title="Hello World"/>
    </Layout1>
    """vaux
  end

  iex> Vaux.render!(Page.Page2)
  "<html><body><h1>Hello World</h1></body></html>"

  defmodule Page.Page3 do
    import Vaux.Component

    components Layout.Layout1

    ~H"""
    <!-- Render fallback content if the component doesn't have any child elements -->
    <Layout1></Layout1>
    """vaux
  end

  iex> Vaux.render!(Page.Page3)
  "<html><body><p>FALLBACK CONTENT</p></body></html>"
```

Vaux also supports named slots. This allows you to easily separate page layout from page content.

Named slots need to be defined with the `slot/1` macro. This allows Vaux to 
catch typos in the template at compile time and gives a component user a quick 
overview what slots are available.

```elixir
  defmodule Layout.Layout2 do
    import Vaux.Component

    slot :head
    slot :body

    ~H"""
    <html>
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width"/>
        <slot #head></slot>
      </head>
      <body>
        <slot #body></slot>
      </body>
    </html>
    """vaux
  end

  defmodule Page.Page4 do
    import Vaux.Component

    components [
      Component.{Example1, Example2},
      Layout.Layout2
    ]

    var title: "Hello World"

    ~H"""
      <Layout2>
        <template #head>
          <Example2 title={@title}/>
        </template>
        <template #body>
          <Example1 title={@title}/>
        </template>
      </Layout2>
    """vaux
  end
  
  iex> Vaux.render!(Page.Page4)
  "<html><head><meta charset=\"UTF-8\"/><meta name=\"viewport\" content=\"width=device-width\"/><title>Hello World</title></head><body><h1>Hello World</h1></body></html>"
```


## Directives

Vaux doesn't support block expressions, but it has an extensive set of 
directives to use:

```elixir
  defmodule Component.DirectivesExample do
    import Vaux.Component

    attr :fruit, {:enum, ~w(apple banana pear orange)}
    attr :count, :integer

    ~H"""
    <body>
      <!-- case expressions, just like in regular Elixir -->
      <div :case={@fruit}>
        <span :clause={"apple"}>{String.upcase(@fruit)}</span>
        <span :clause={"banana"}>{String.reverse(@fruit)}</span>

        <!-- If the pattern is a string, you can ommit the curly braces  -->
        <span :clause="pear">{String.capitalize(@fruit)}</span>
        <span :clause="orange">{String.replace(@fruit, "g", "j")}</span>

        <!-- Guards can be used too -->
        <span :clause={a when is_atom(a)}>Unexpected</span>
      </div>

      <!-- Loops can be expressed with the :for directive -->
      <div :for={number <- 1..@count}>{number}</div>

      <!-- The first element with a truthy :cond expression gets rendered -->
      <div :cond={@count >= 5}>Too many</div>
      <div :cond={@count >= 3}>Ok</div>

      <!-- :else can be used as the equivalent of `true -> ...` in a regular Elixir cond expression -->
      <div :else>Too little</div>

      <!-- :if can be used too -->
      <div :if={@fruit == "apple"}></div>
    </body>
    """vaux
  end

  iex> Vaux.render!(Component.DirectivesExample, %{"fruit" => "orange", "count" => 3})
  "<body><div><span>oranje</span></div><div>1</div><div>2</div><div>3</div><div>Ok</div></body>"
```


#### Applying directives to multiple elements

If you want to apply a directive to a list of elements, you can use the 
`template` element as a wrapper, as it won't get rendered by default (you can 
use the `:keep` directive to keep te `template` element in the rendered output).

```elixir
  defmodule Component.Example3 do
    import Vaux.Component

    attr :fruit, {:enum, ~w(apple banana pear orange)}

    ~H"""
    <template :if={String.starts_with?(@fruit, "a")}>
      <a></a>
      <b></b>
    </template>
    """vaux
  end

  iex> Vaux.render!(Component.Example3, %{"fruit" => "apple"})
  "<a></a><b></b>"
```


#### Using `:bind` and `:let` directives

Vaux templates also offer `:bind` and `:let` directives. These directives make 
it possible to bind data in a template and make it available to the consumer of 
the component.

```elixir
     defmodule Component.BindingExample do
       import Vaux.Component
    
       attr :title, :string
    
       ~H"""
       <slot :bind={String.upcase(@title)}></slot>
       """vaux  
     end

     defmodule Page.Page5 do
       import Vaux.Component
    
       components Component.BindingExample
    
       ~H"""
       <BindingExample title="Hello World" :let={upcased}>{upcased}</BindingExample>
       """vaux  
     end

    iex> Vaux.render!(Page)
    "HELLO WORLD"
```

When using named slots, the `:let` directive can be used on the named template element.


## Attribute validation

Vaux uses [JSV](https://hexdocs.pm/jsv/), a modern JSON Schema 
validation library. When defining an attribute with the `attr/3` macro, most 
JSON schema validation options can be used:

```elixir
  defmodule Component.Validations do
    import Vaux.Component

    # Both Elixir friendly snake_case and JSON Schema's camelCase notation can be used 
    attr :title, :string, min_length: 8, maxLength: 16, required: true
    attr :count, :integer, required: true

    # If the type of an array doesn't need extra validation, a shorthand notation can be used 
    attr :numbers1, :array, items: :integer
    attr :numbers2, {:array, :integer}

    # Shorthand notation for objects is available too
    attr :person1, :object, properties: %{name: {:string, pattern: "\w+\s+\w+"}, age: :integer}
    attr :person2, %{name: {:string, pattern: "\w+\s+\w+"}, age: :integer}

    ~H""vaux
  end
```


## Global Attributes

Vaux supports passing global attributes to the first element of a component. 
This can be used for example when you want to be able to set a class or event 
handler on the component's root element.

```elixir
  defmodule GlobalsTest do
    import Vaux.Component

    attr :title, :string
    globals only: ~w(id class onclick)

    ~H"""
    <h1 id="to-be-replaced-id" class="other">{@title}</h1>
    """vaux
  end

  iex> Vaux.render(GlobalsTest, %{"title" => "Hello World", "id" => "new-id", "class" => "myclass", "onclick" => "alert('Hi')"})
  {:ok, "<h1 onclick=\"alert(&#39;Hi&#39;)\" id=\"new-id\" class=\"other myclass\">Hello World</h1>"}
```

See [`globals/1`](Vaux.Component.html#globals/1) for more info.


## Vaux.Component behaviour and `handle_state/1` callback

Every component implements the `Vaux.Component` behaviour. This behaviour 
requires two functions to be implemented: `handle_state/1` and `render/1`. Both 
receive a struct that is defined by the `sigil_H/2` macro. This struct contains 
all defined attributes, variables and slots. The `handle_state/1` function 
allows you to preprocess atributes, setup internal variables, etc. Finally, the 
returned struct from `handle_state/1` is passed to the `render/1` function.

The `sigil_H/2` macro defines `render/1` and also provides an overridable 
default implementation for `handle_state/1`.

The main idea behind the `handle_state/1` callback is that it allows you to 
keep most complex control flow and data transformations out of the template. 
For top level components however, it can be convenient to treat the callback as 
a type of view controller and let it fetch data from a data source itself. When 
to apply this strategy boils down to the same arguments when thinking about 
side effects in regular code: pure functions tend to be easier to compose and 
reason about, so that is a good default. However, making some key components 
responsible for fetching data makes it simpler to reuse these components in 
different contexts.

```elixir
  defmodule Component.StateExample do
    import Vaux.Component

    @some_data_source %{name: "Jan Jansen", hobbies: ~w(cats drawing)}

    attr :title, :string
    var :hobbies

    ~H"""
      <section>
        <h1>{@title}</h1>
        <p>Current hobbies:{@hobbies}</p>
      </section>
    """vaux

    def handle_state(%__MODULE__{title: title} = state) do
      %{name: name, hobbies: hobbies} = @some_data_source

      title = EEx.eval_string(title, assigns: [name: name])
      hobbies = hobbies |> Enum.map(&String.capitalize/1) |> Enum.join(", ")

      {:ok, %{state | title: title, hobbies: " " <> hobbies}}
    end
  end

  iex> Vaux.render!(Component.StateExample, %{"title" => "Hello <%= @name %>"})
  "<section><h1>Hello Jan Jansen</h1><p>Current hobbies: Cats, Drawing</p></section>"
```


## Root modules

Vaux allows you to define root modules. These modules can be used to bundle 
common elements that components are able to use. 

```elixir
  defmodule MyRoot do
    import Vaux.Root

    components [
      Component.{Example1, Example2},
      Layout.Layout2
    ]

    const title: "Hello World"
  end

  defmodule Page.Page6 do
    use MyRoot

    ~H"""
      <Layout2>
        <template #head>
          <Example2 title={@!title}/>
        </template>
        <template #body>
          <Example1 title={@!title}/>
        </template>
      </Layout2>
    """vaux
  end
  
  iex> Vaux.render!(Page.Page6)
  "<html><head><meta charset=\"UTF-8\"/><meta name=\"viewport\" content=\"width=device-width\"/><title>Hello World</title></head><body><h1>Hello World</h1></body></html>"
```

The `const/1` macro allow you to define static data that is reused by multiple 
components. These can be accessed in templates by the special `@!my_const` 
syntax. The `components/1` macro works the same as in component definitions.

When at least one `const/1` or `components/1` definition is included in a root 
module, a `__using__/1` macro is created for the root module that allows it to be used 
in a component. 

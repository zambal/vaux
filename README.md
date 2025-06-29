# Vaux

## Introduction

Vaux (rhymes with yo) provides composable html templates for Elixir. It uses a
customized verion of the excellent html parsing library 
[htmerl](https://hex.pm/packages/htmerl), which enables it to provide a simple, 
but still expressive syntax tailored for working with html.

Vaux draws inspiration from both [Phoenix components](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) 
and [Vue templates](https://vuejs.org/guide/essentials/template-syntax.html). It also 
builds upon the same syntax as HEEx templates, so Vaux templates are easy to 
work with if your editor has support for HEEx. 

A minimal example looks like this:

```elixir
  defmodule Components.MyComponent do
    import Vaux.Component

    attr :title, :string

    ~H"""
    <h1>{@title}</h1>
    """vaux
  end

  iex> Vaux.render!(MyComponent, %{"title" => "Hello World"})
  "<h1>Hello World</h1>"
```

As you can see, Vaux uses the same sigil and template expression syntax as HEEx 
templates. To make sure HEEx and Vaux templates can't be mixed up, Vaux 
requires the `vaux` modifier for its `~H` sigil.In order to call another 
component, it needs to be known at compile time. Vaux provides `components/1` 
macro that both requires and aliases components:

```elixir
  defmodule Components.Meta do
    import Vaux.Component

    attr :title, :string

    ~H"""
    <meta name="viewport" content="width=device-width"/>
    <title>{@title}</title>
    """vaux
  end

  defmodule Layouts.MyLayout do
    import Vaux.Component

    components Components.{MyComponent, Meta}

    var title: "Hello World"

    ~H"""
    <html>
      <head>
        <meta charset="UTF-8"/>
        <Meta title={@title}/>
      </head>
      <body>
        <MyComponent title={@title}/>
      </body>
    </html>
    """vaux
  end

  iex> Vaux.render!(MyComponent, %{"title" => "Hello World"})
  "<html><head><meta charset=\"UTF-8\"/><meta name=\"viewport\" content=\"width=device-width\"/><title>Hello World</title></head><body><h1>Hello World</h1></body></html>"
```


## Directives

Vaux doesn't support block expressions, but it has an extensive set of 
directives to use:

```elixir
  defmodule Components.AnotherComponent do
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

      <!-- The element with the first truthy :cond expression gets rendered -->
      <div :cond={@count >= 5}>Too many</div>
      <div :cond={@count >= 3}>Ok</div>

      <!-- :else can be used as the equivalent of `true -> ...` in a cond expression -->
      <div :else>Too little</div>

      <!-- :if can be used too -->
      <div :if={@fruit == "apple"}></div>
    </body>
    """vaux
  end

  iex> Vaux.render!(Components.AnotherComponent, %{"fruit" => "orange", "count" = 3})
  "<body><div><span>oranje</span></div><div>1</div><div>2</div><div>3</div><div>Ok</div></body>"
```

If you want to apply a directive to a list of elements, you can use the special `v-template` element as a wrapper, as it won't get rendered.


```elixir
  defmodule Components.AnotherComponent2 do
    import Vaux.Component

    attr :fruit, {:enum, ~w(apple banana pear orange)}

    ~H"""
    <v-template :if={String.starts_with?(@fruit, "a")}>
      <a></a>
      <b></b>
    </v-template<
    """vaux
  end

  iex> Vaux.render!(Components.AnotherComponent2, %{"fruit" => "apple"})
  "<a></a><b></b>"
```


## Schemas and validation

Vaux integrates with [JSV](https://hexdocs.pm/jsv/), a modern JSON Schema 
validation library. When defining an attribute with the `attr/3` macro, most 
JSON schema validation options can be used:

```elixir
  defmodule Components.Validations do
    import Vaux.Component

    # Both Elixir friendly snake_case and JSON Schema's camelCase notation can be used 
    attr :title, :string, min_length: 8, maxLength: 16, required: true
    attr :count, :integer, required: true

    # If the type of an array doesn't need extra validation, a shorthand notation can be used 
    attr :numbers1, :array, items: :integer
    attr :numbers2, {:array, :integer}

    # Shorthand notation for objects is available too
    attr :object1, :object, properties: %{name: {:string, pattern: ~r/\w+\s+\w+/}, age: :integer}
    attr :object2, %{name: {:string, pattern: ~r/\w+\s+\w+/}, age: :integer}

    ~H""vaux
  end

```





## Installation

The package can be installed by adding `vaux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vaux, "~> 0.3"}
  ]
end
```

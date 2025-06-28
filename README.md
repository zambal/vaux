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
  defmodule MyComponent do
    import Vaux.Component

    attr :title, :string

    ~H"""
    <h1>{@title}</h1>
    """vaux
  end

  iex> Vaux.render!(MyComponent, %{"title" => "Hello World"})
  "<h1>Hello World</h1>"
```

As you can see, Vaux uses the same sigil and template expression syntax as HEEx templates. To make sure HEEx and Vaux templates can't be mixed up, Vaux requires the `vaux` modifier for its `~H` sigil.
    

## Installation

The package can be installed by adding `vaux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vaux, "~> 0.3"}
  ]
end
```

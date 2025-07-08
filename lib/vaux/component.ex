defmodule Vaux.Component do
  @moduledoc """
  Import this module to define a component

  In addition to compiling the component template, the `sigil_H/2` macro 
  collects all defined attributes, variables and slots to define a struct that 
  holds all this data as the component's state. This state struct is passed to 
  the compiled template and it's fields are accessible via the `@` assign syntax  
  inside the template.

  The module's behaviour requires the callback functions `handle_state/1` and 
  `render/1` to be implemented. However when defining a html template with 
  `sigil_H/2`, both functions will be defined automatically. `handle_state/1` is 
  overridable to make it possible to process the state struct before it gets 
  passed to `render/1`.

      iex> defmodule Component.StateExample do
      ...>   import Vaux.Component
      ...>  
      ...>    @some_data_source %{name: "Jan Jansen", hobbies: ~w(cats drawing)}
      ...>  
      ...>    attr :title, :string
      ...>    var :hobbies
      ...>  
      ...>    ~H\"""
      ...>      <section>
      ...>        <h1>{@title}</h1>
      ...>        <p>Current hobbies:{@hobbies}</p>
      ...>      </section>
      ...>    \"""vaux
      ...>
      ...>    def handle_state(%__MODULE__{title: title} = state) do
      ...>      %{name: name, hobbies: hobbies} = @some_data_source
      ...>  
      ...>      title = EEx.eval_string(title, assigns: [name: name])
      ...>      hobbies = hobbies |> Enum.map(&String.capitalize/1) |> Enum.join(", ")
      ...>  
      ...>      {:ok, %{state | title: title, hobbies: " " <> hobbies}}
      ...>    end
      ...>  end
      iex> Vaux.render!(Component.StateExample, %{"title" => "Hello <%= @name %>"})
      "<section><h1>Hello Jan Jansen</h1><p>Current hobbies: Cats, Drawing</p></section>"
  """

  require Vaux.Component.Builder
  alias Vaux.Component.Builder

  @callback handle_state(state :: struct()) :: {:ok, state} | {:error, reason}
            when state: struct(), reason: any()

  @callback render(state :: struct()) :: iodata()

  @doc """
  Convenience macro to declare components to use inside a template.

      components My.Component

  gets translated to

      require My.Component, as: Component

  A more complete example

      defmodule MyComponent do
        import Vaux.Component

        components Some.{OtherComponent1, OtherComponent2}

        components [
          Some.Layout,
          Another.Component
        ]

        ~H\"""
        <Layout>
          <Component/>
          <OtherComponent1/>
          <OtherComponent2/>
        </Layout>
        \"""vaux
      end
  """
  defmacro components(comps) do
    quote do
      unquote(comps |> List.wrap() |> Builder.handle_requires())
    end
  end

  @doc """
  Define a named slot

      defmodule Layout do
        import Vaux.Component

        slot :content
        slot :footer

        ~H\"""
        <body>
          <main>
            <slot #content></slot>
          </main>
          <footer>
            <slot #footer><p>footer fallback content</p></slot>
          </footer>
        </body>
        \"""vaux
      end

      defmodule Page do
        import Vaux.Component

        components Layout

        ~H\"""
        <html>
          <head>
            <title>Hello World</title>
          </head>
          <Layout>
            <template #content>
              <h1>Hello World</h1>
            </template>
          </Layout>            
        </html>
        \"""vaux
      end
        
  """
  defmacro slot(name) do
    %{module: mod, file: file, line: line} = __CALLER__

    Builder.put_slot(mod, name)

    if not is_atom(name) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end
  end

  @doc """
  Define an attribute that can hold any value. See `attr/3` for more information about attributes.
  """
  defmacro attr(field) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_attribute(mod, {field, true, false})
  end

  @doc """
  Define an attribute

  Attributes, together with slots, provide the inputs to component templates. Attribute values are currently always html escaped. Vaux uses [JSV](https://hexdocs.pm/jsv/) for attribute validation. This means that most JSON Schema validation keywords are available for validating attributes.

  JSON Schema keywords are camelCased and can be used as such. However, the `attr/3` macro also supports Elixir friendly snake_case naming of JSON Schema keywords.

  The following types are currently supported:

    - `boolean`
    - `object`
    - `array`
    - `number`
    - `integer`
    - `string`
    - `true`
    - `false`

  Note that the types `true` and `false` are different from type `boolean`. 
  `true` means that any type will be accepted and `false` disallows any type. 
  These are mostly added for completeness, but especially `true` might be useful 
  in some cases.

  Options can be both applicator and validation keywords. Currently supported options are:

    - `properties`
    - `items`
    - `contains`
    - `maxLength`
    - `minLength`
    - `pattern`
    - `exclusiveMaximum`
    - `exclusiveMinimum`
    - `maximum`
    - `minimum`
    - `multipleOf`
    - `required`
    - `maxItems`
    - `minItems`
    - `maxContains`
    - `minContains`
    - `uniqueItems`
    - `description`
    - `default`
    - `format`

  A good resource to learn more about the use of these keywords is 
  [www.learnjsonschema.com](https://www.learnjsonschema.com/2020-12/).

  The `attr/3` macro provides some syntactic sugar for defining types. Instead of writing

      attr :numbers, :array, items: :integer, required: true

  it is also possible to write

      attr :numbers, {:array, :integer}, required: true

  When defining objects

      attr :person, :object, properties: %{name: :string, age: :integer}

  it is also possible to write

      attr :person, %{name: :string, age: :integer}

  All validation options can be used when defining (sub)properties by using a tuple

      attr :person, %{
        name: {:string, min_length: 8, max_length: 16},
        age: {:integer, minimum: 0}
      } 
  """
  defmacro attr(field, type, opts \\ []) do
    %{module: mod, file: file, line: line} = __CALLER__

    if not is_atom(field) do
      description = "attr expects an atom as attribute name"
      raise Vaux.CompileError, file: file, line: line, description: description
    end

    {type, _} = Code.eval_quoted(type, [], __CALLER__)
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)

    case Vaux.Schema.to_schema_prop(type, opts) do
      {:ok, prop_def, required} ->
        Builder.put_attribute(mod, {field, prop_def, required})

      {:error, {:invalid_type, type}} ->
        description = "#{inspect(field)} attribute has an invalid type: #{inspect(type)}"
        raise Vaux.CompileError, file: file, line: line, description: description

      {:error, {:invalid_inner_type, {_type, inner_type}}} ->
        description = "#{inspect(field)} attribute has an invalid inner type: #{inspect(inner_type)}"

        raise Vaux.CompileError, file: file, line: line, description: description

      {:error, {:invalid_opt, opt}} ->
        description = "#{inspect(field)} attribute has an invalid option: #{inspect(opt)}"
        raise Vaux.CompileError, file: file, line: line, description: description
    end
  end

  @doc """
  Define a variable

  A component variable can be either used as a constant, or in combination with 
  `handle_state/1` as a place to store internal data that can be accessed inside 
  a template with the same `@` syntax as attributes.

      iex> defmodule Hello do
      ...>   import Vaux.Component
      ...> 
      ...>   var title: "Hello"
      ...> 
      ...>   ~H"<h1>{@title}</h1>"vaux
      ...> end
      iex> Vaux.render(Hello)
      {:ok, "<h1>Hello</h1>"}
  """
  defmacro var(value)

  defmacro var([{name, value}]) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_var(mod, {name, value, line})
  end

  defmacro var(name) when is_atom(name) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_var(mod, {name, nil, line})
  end

  @doc """
  Declare global attributes, including event handlers, that a component 
  optionally accepts 

  The `globals/1` macro can be used if you want to allow setting global 
  attributes on the template's first element. Use `true` to allow any global 
  attribute and `false` to disallow all global attributes (default). When `:only` 
  is passed as option, a list of global attribute names can be passed that are 
  allowed. Finally, the `:except` option can be used to allow any global 
  attribute except for the passed list of global attribute names.

  Passed global attributes overwrite already present attributes, except 
  for the `class` attribute. In that case passed classes will be added to 
  existing classes.

      iex> defmodule GlobalsTest do
      ...>   import Vaux.Component
      ...> 
      ...>   attr :title, :string
      ...>   globals only: ~w(id class onclick)
      ...> 
      ...>   ~H\"""
      ...>   <h1 id=\"to-be-replaced-id\" class=\"other\">{@title}</h1>
      ...>   \"""vaux
      ...> end
      iex> Vaux.render(GlobalsTest, %{"title" => "Hello World", "id" => "new-id", "class" => "myclass", "onclick" => "alert('Hi')"})
      {:ok, "<h1 onclick=\\"alert(&#39;Hi&#39;)\\" id=\\"new-id\\" class=\\"other myclass\\">Hello World</h1>"}

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes for a complete list of global attributes that can be defined.
  """
  defmacro globals(attr_names)

  defmacro globals(b) when is_boolean(b),
    do: Vaux.Component.Builder.set_globals(__CALLER__, b)

  defmacro globals(only: globals),
    do: Vaux.Component.Builder.set_globals(__CALLER__, {:only, globals})

  defmacro globals(except: globals),
    do: Vaux.Component.Builder.set_globals(__CALLER__, {:except, globals})

  defmacro globals(globals),
    do: Vaux.Component.Builder.set_globals(__CALLER__, {:only, globals})

  @doc """
  Define a html template

  Vaux templates support `{...}` for HTML-aware interpolation inside tag 
  attributes and the body. `@field` can be used to access any field of the the 
  template's state struct. To access a root module constant, 
  `@!constant` can be used. Note that Vaux templates require `vaux` as sigil 
  modifier in order to distinguish them from HEEx templates.

      ~H"<h1>{String.capitalize(@title)}</h1>"vaux

  Only variable interpolations are allowed inside `script` and `style` tags. 
  These are exressions in the form of `{@field}` or `{@!const}`. `{1 + @field}` is not valid 
  variable interpolation for example.

  An extensive set of directives is available for expressing control flow, 
  iteration, template bindings and visibility within templates. Available control 
  flow directives are:

    - `:if`
    - `:else`
    - `:cond`
    - `:case`
    - `:clause`

  Most of these directives work like the equivalent in regular Elixir code. A 
  notable difference is that the `:cond` directive won't raise an exception when 
  there is no truthy condition, it simply skips rendering all elements with the 
  `:cond` directive. However, when using the `:case` directive and there is no 
  matching `:clause`, an exception will be raised. This behaviour might change in 
  future releases.

      defmodule Component.DirectivesExample do
        import Vaux.Component

        attr :fruit, {:enum, ~w(apple banana pear orange)}
        attr :count, :integer

        ~H\"""
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

          <!-- The first element with a truthy :cond expression gets rendered -->
          <div :cond={@count >= 5}>Too many</div>
          <div :cond={@count >= 3}>Ok</div>

          <!-- :else can be used as the equivalent of `true -> ...` in a regular Elixir cond expression -->
          <div :else>Too little</div>

          <!-- :if (with or without a following :else) can be used too -->
          <div :if={@fruit == "apple"}></div>
        </body>
        \"""vaux
      end

  `:for` can be used for iterating. It supports a single Elixir `for` generator.

      <div :for={n <- 1..10}>Number: {n}</div>

  By using the `:bind` and `:let` directives, it is possible to bind data in a 
  template and make it available to the consumer of the component. When using 
  named slots, the `:let` directive can be used on the named template element.

      iex> defmodule Component do
      ...>   import Vaux.Component
      ...>
      ...>   attr :title, :string
      ...>
      ...>   ~H\"""
      ...>   <slot :bind={String.upcase(@title)}></slot>
      ...>   \"""vaux  
      ...> end
      iex> defmodule Page do
      ...>   import Vaux.Component
      ...>
      ...>   components Component
      ...>
      ...>   ~H\"""
      ...>   <Component title="Hello World" :let={upcased}>{upcased}</Component>
      ...>   \"""vaux  
      ...> end
      iex> Vaux.render!(Page)
      "HELLO WORLD"


  Finally, the `:keep` directive can be used on template or slot elements to 
  keep them in the rendered output.
  """
  defmacro sigil_H(template, mods)

  defmacro sigil_H({:<<>>, _meta, [string]}, mods) do
    %{module: mod, file: file, line: line} = __CALLER__

    case mods do
      ~c"vaux" ->
        :ok

      [] ->
        description =
          "Vaux template sigil requires the `vaux` modifier\n\n\t~H\"\"\"\n\t<h1>Hello World</h1>\n\t\"\"\"vaux\n"

        raise Vaux.CompileError, file: file, line: line, description: description
    end

    Builder.put_template(mod, {string, __CALLER__})
    Builder.defcomponent(__CALLER__)
  end
end

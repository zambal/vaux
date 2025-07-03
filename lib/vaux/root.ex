defmodule Vaux.Root do
  @moduledoc """
  Importing `Vaux.Root` lets a module define common elements for components to use.

  When at least one `const/1` or `components/1` definition is included in a root 
  module, a `__using__/1` macro is created for the root module that allows it to be used 
  in a component. 

      defmodule MyRoot do
        import Vaux.Root

        components [
          Layout,
          Component.{Example1, Example2}
        ]

        const title: "Hello World"
      end

      defmodule Page do
        use MyRoot

        ~H\"""
          <Layout>
            <template #head>
              <Example2 title={@!title}/>
            </template>
            <template #body>
              <Example1 title={@!title}/>
            </template>
          </Layout>
        \"""vaux
      end
  """

  require Vaux.Component

  @doc """
  See `Vaux.Component.components/1`
  """
  defmacro components(comps) do
    %{module: mod} = __CALLER__

    Vaux.Component.Builder.put_components(mod, comps)

    if Module.get_attribute(mod, :before_compile) == [] do
      Module.put_attribute(mod, :before_compile, {Vaux.Component.Builder, :defroot})
    end
  end

  @doc """
  Define a constant

  The defined constant is accessable in components via the `@!` template syntax.

  When the value is an argumentless function, it will be applied during compile time.

      defmodule Constants do
        import Vaux.Root

        const answer: 42

        const countries: fn ->
          File.read!("priv/countries.json") |> JSON.decode!()
        end
      end

      defmodule Component do
        use Constants

        ~H\"""
        <ul><li :for={%{"name" => name} <- @!countries}>{name}</li></ul>
        <p>Answer: {@!answer}</p>
        \"""vaux
      end

  """
  defmacro const(value)

  defmacro const([{name, value}]) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_const(mod, {name, value, line})

    if Module.get_attribute(mod, :before_compile) == [] do
      Module.put_attribute(mod, :before_compile, {Vaux.Component.Builder, :defroot})
    end
  end
end

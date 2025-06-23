defmodule Vaux.Root do
  defmacro components(comps) do
    %{module: mod} = __CALLER__

    Vaux.Component.Builder.put_components(mod, comps)

    if Module.get_attribute(mod, :before_compile) == [] do
      Module.put_attribute(mod, :before_compile, {Vaux.Component.Builder, :defroot})
    end
  end

  defmacro const([{name, value}]) do
    %{module: mod, line: line} = __CALLER__

    Vaux.Component.Builder.put_const(mod, {name, value, line})

    if Module.get_attribute(mod, :before_compile) == [] do
      Module.put_attribute(mod, :before_compile, {Vaux.Component.Builder, :defroot})
    end
  end
end

defmodule Vaux.TestHelper do
  def unload(mod) do
    :code.delete(mod)
    :code.purge(mod)
  end
end

ExUnit.start()

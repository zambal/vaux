defmodule Vaux.MixProject do
  use Mix.Project

  def project do
    [
      app: :vaux,
      version: "0.3.3",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: [{:jsv, "~> 0.8"}]
    ]
  end

  def application, do: []
end

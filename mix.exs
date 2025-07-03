defmodule Vaux.MixProject do
  use Mix.Project

  @source_url "https://github.com/lud/jsv"
  @version "0.3.7"

  def project do
    [
      app: :vaux,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Vaux",
      source_url: "https://github.com/zambal/vaux",
      description: "Composable HTML for Elixir",
      docs: docs(),
      package: package()
    ]
  end

  def application, do: []

  defp deps do
    [
      {:jsv, "~> 0.8"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      Modules: [Vaux, Vaux.Component, Vaux.Root],
      Exceptions: [~r/^Vaux\.\w+Error/]
    ]
  end

  defp package do
    [
      name: :vaux,
      maintainers: ["Vincent Siliakus"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/zambal/vaux"}
    ]
  end
end

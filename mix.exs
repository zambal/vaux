defmodule Vaux.MixProject do
  use Mix.Project

  @source_url "https://github.com/zambal/vaux"
  @version "0.4.0"

  def project do
    [
      app: :vaux,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Vaux",
      source_url: @source_url,
      description: "Composable HTML templates for Elixir",
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
      source_ref: "v#{@version}",
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
      links: %{"Github" => @source_url}
    ]
  end
end

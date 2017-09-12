defmodule Exkml.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exkml,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
      Read KML files as a stream of features and attributes
    """
  end

  defp package do
    [
      maintainers: ["Chris Duranti"],
      licenses: ["Apache 2"],
      links: %{"GitHub" => "https://github.com/socrata/exkml"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:sweet_xml, "~> 0.6.5"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
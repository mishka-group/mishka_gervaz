defmodule MishkaGervaz.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/mishka-group/mishka_gervaz"

  def project do
    [
      app: :mishka_gervaz,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "MishkaGervaz",
      description:
        "Mishka Gervaz is a comprehensive, declarative UI library for the Ash ecosystem — define tables, forms, and data-driven interfaces entirely through DSL, with built-in sorting, filtering, real-time updates, and extensible templates. Every component, adapter, and behavior is fully overridable and customizable",
      source_url: @source_url,
      homepage_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:spark, github: "ash-project/spark", branch: "main", override: true},
      {:ash, "~> 3.0"},
      {:splode, "~> 0.3"},
      {:gettext, "~> 1.0"},
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:ash_phoenix, "~> 2.3"},
      {:jason, "~> 1.0"},
      {:html_sanitize_ex, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},
      {:sourceror, "~> 1.10", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # Test-only dependency for archive testing
      {:ash_archival, "~> 2.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Shahryar Tavakkoli", "Mona Aghili"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "Sponsor" => "https://github.com/sponsors/mishka-group"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "MishkaGervaz",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix]
    ]
  end
end

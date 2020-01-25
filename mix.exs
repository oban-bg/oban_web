defmodule ObanWeb.MixProject do
  use Mix.Project

  @version "0.8.0"

  def project do
    [
      app: :oban_web,
      version: @version,
      elixir: "~> 1.8",
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      description: "Oban Web Component",
      preferred_cli_env: [
        "test.ci": :test,
        "test.reset": :test,
        "test.setup": :test
      ],

      # Docs
      name: "ObanWeb",
      docs: [
        main: "ObanWeb",
        source_ref: "v#{@version}",
        source_url: "https://github.com/sorentwo/oban_web",
        extras: ["README.md"]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      organization: "oban",
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["Commercial"],
      links: []
    ]
  end

  defp deps do
    [
      {:gettext, "~> 0.17"},
      {:jason, "~> 1.0"},
      {:oban, "~> 0.12"},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_live_view, "~> 0.6"},
      {:credo, "~> 1.0", only: [:test, :dev], runtime: false},
      {:floki, ">= 0.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "test.reset": ["ecto.drop -r ObanWeb.Repo", "test.setup"],
      "test.setup": ["ecto.create -r ObanWeb.Repo --quiet", "ecto.migrate -r ObanWeb.Repo"],
      "test.ci": ["format --check-formatted", "credo --strict", "test --raise"]
    ]
  end
end

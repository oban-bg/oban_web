defmodule Oban.Web.MixProject do
  use Mix.Project

  @version "2.7.3"

  def project do
    [
      app: :oban_web,
      version: @version,
      elixir: "~> 1.9",
      compilers: [:phoenix] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      name: "ObanWeb",
      description: "Oban Web Component",
      preferred_cli_env: [
        "test.ci": :test,
        "test.reset": :test,
        "test.setup": :test
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
      files: ~w(lib priv .formatter.exs mix.exs),
      licenses: ["Commercial"],
      links: []
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:oban, "~> 2.7"},
      {:phoenix, "~> 1.5"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_live_view, "~> 0.16"},
      {:credo, "~> 1.4", only: [:test, :dev], runtime: false},
      {:floki, "~> 0.26", only: [:test]},
      {:stream_data, "~> 0.5", only: [:test]}
    ]
  end

  defp aliases do
    [
      "test.reset": ["ecto.drop -r Oban.Web.Repo", "test.setup"],
      "test.setup": ["ecto.create -r Oban.Web.Repo --quiet", "ecto.migrate -r Oban.Web.Repo"],
      "test.ci": ["format --check-formatted", "credo --strict", "test --raise"]
    ]
  end
end

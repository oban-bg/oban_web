defmodule Oban.Web.MixProject do
  use Mix.Project

  @source_url "https://github.com/oban-bg/oban_web"
  @version "2.11.3"

  def project do
    [
      app: :oban_web,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      package: package(),
      name: "Oban Web",
      description: "Dashboard for the Oban job processing framework",
      preferred_cli_env: [
        "test.ci": :test,
        "test.reset": :test,
        "test.setup": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Oban.Web.Application, []},
      env: [cache: true]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["Apache-2.0"],
      files: ~w(lib priv .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      links: %{
        Website: "https://oban.pro",
        Changelog: "#{@source_url}/blob/main/CHANGELOG.md",
        GitHub: @source_url
      }
    ]
  end

  defp docs do
    [
      main: "overview",
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"],
      api_reference: false,
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      logo: "assets/oban-web-logo.svg",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp extras do
    [
      "guides/introduction/overview.md",
      "guides/introduction/installation.md",
      "guides/advanced/filtering.md",
      "guides/advanced/metrics.md",
      "CHANGELOG.md": [filename: "changelog", title: "Changelog"]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Advanced: ~r/guides\/advanced\/.?/
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 3.3 or ~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_view, "~> 1.0"},

      # Oban
      {:oban, "~> 2.19"},
      {:oban_met, "~> 1.0"},
      {:oban_pro, "~> 1.5", repo: :oban, only: [:test, :dev]},

      # Databases
      {:ecto_sqlite3, "~> 0.18", only: [:dev, :test]},
      {:myxql, "~> 0.7", only: [:dev, :test]},
      {:postgrex, "~> 0.19", only: [:dev, :test]},

      # Dev Server
      {:bandit, "~> 1.5", only: :dev},
      {:esbuild, "~> 0.7", only: :dev, runtime: false},
      {:faker, "~> 0.17", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:tailwind, "~> 0.2", only: :dev, runtime: false},

      # Tooling
      {:credo, "~> 1.7", only: [:test, :dev], runtime: false},
      {:floki, "~> 0.33", only: [:test, :dev]},
      {:igniter, "~> 0.5", only: [:dev, :test]},

      # Docs and Publishing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:makeup_diff, "~> 0.1", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "assets.build": ["tailwind default", "esbuild default"],
      dev: "run --no-halt dev.exs",
      release: [
        "assets.build",
        "cmd git tag v#{@version} -f",
        "cmd git push",
        "cmd git push --tags",
        "hex.publish --yes"
      ],
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --raise"
      ]
    ]
  end
end

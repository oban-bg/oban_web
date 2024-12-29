defmodule Oban.Web.MixProject do
  use Mix.Project

  @version "2.10.5"

  def project do
    [
      app: :oban_web,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      prune_code_paths: false,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      package: package(),
      name: "Oban Web",
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
      extra_applications: [:logger],
      mod: {Oban.Web.Application, []},
      env: [cache: true]
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
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 3.3 or ~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_view, "~> 1.0"},

      # Oban
      {:oban, ">= 2.17.4 and < 2.19.0", github: "oban-bg/oban", override: true},
      {:oban_met, "~> 0.1.7", repo: :oban},
      {:oban_pro, "~> 1.5.0-rc.7", repo: :oban, only: [:test, :dev]},

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
      {:credo, "~> 1.6", only: [:test, :dev], runtime: false},
      {:floki, "~> 0.33", only: [:test, :dev]},

      # Docs and Publishing
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:makeup_diff, "~> 0.1", only: :dev, runtime: false},
      {:lys_publish, "~> 0.1", only: :dev, runtime: false, optional: true, path: "../lys_publish"}
    ]
  end

  defp aliases do
    [
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.watch": ["tailwind watch"],
      dev: "run --no-halt dev.exs",
      release: [
        "assets.build",
        "cmd git tag v#{@version}",
        "cmd git push",
        "cmd git push --tags",
        "docs",
        "hex.publish package --yes",
        "lys.publish"
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

  defp docs do
    [
      main: "overview",
      source_ref: "v#{@version}",
      formatters: ["html"],
      api_reference: false,
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      homepage_url: "/",
      logo: "assets/oban-web-logo.svg",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      before_closing_body_tag: fn _ ->
        """
        <script>document.querySelector('footer.footer p').remove()</script>
        """
      end
    ]
  end

  defp extras do
    [
      "guides/introduction/overview.md",
      "guides/introduction/installation.md",
      "guides/introduction/open_source.md",
      "guides/advanced/metrics.md",
      "guides/advanced/filtering.md",
      "CHANGELOG.md": [filename: "changelog", title: "Changelog"]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Advanced: ~r/guides\/advanced\/.?/
    ]
  end
end

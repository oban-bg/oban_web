defmodule Oban.Web.MixProject do
  use Mix.Project

  @version "2.10.0-dev"

  def project do
    [
      app: :oban_web,
      version: @version,
      elixir: "~> 1.12",
      compilers: Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:phoenix, "1.7.0"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_live_view, "~> 0.18.18"},

      # Oban
      {:oban, "~> 2.14", override: true, path: "../oban"},
      {:oban_met, "~> 0.1", path: "../oban_met"},
      {:oban_pro, "~> 0.13", path: "../oban_pro"},

      # Dev Server
      {:bandit, "~> 0.7", only: :dev},
      {:faker, "~> 0.17", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:tailwind, "~> 0.1", only: :dev, runtime: false},

      # Tooling
      {:credo, "~> 1.6", only: [:test, :dev], runtime: false},
      {:floki, "~> 0.33", only: [:test, :dev]},

      # Docs and Publishing
      {:esbuild, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:lys_publish, "~> 0.1", only: :dev, runtime: false, optional: true, path: "../lys_publish"}
    ]
  end

  defp aliases do
    [
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.watch": ["tailwind watch"],
      dev: "run --no-halt dev.exs",
      release: [
        "cmd git tag v#{@version}",
        "cmd git push",
        "cmd git push --tags",
        "hex.publish package --yes",
        "lys.publish"
      ],
      "test.reset": ["ecto.drop -r Oban.Web.Repo", "test.setup"],
      "test.setup": ["ecto.create -r Oban.Web.Repo --quiet", "ecto.migrate -r Oban.Web.Repo"],
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
      "guides/introduction/installation.md",
      "guides/configuration/mounting.md",
      "guides/configuration/customizing.md",
      "guides/advanced/searching.md",
      "guides/advanced/telemetry.md",
      "CHANGELOG.md": [filename: "changelog", title: "Changelog"],
      "guides/introduction/overview.md": [title: "Overview"]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Configuration: ~r/guides\/configuration\/.?/,
      Advanced: ~r/guides\/advanced\/.?/,
      Deployment: ~r/guides\/deployment\/.?/
    ]
  end
end

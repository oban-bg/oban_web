defmodule Oban.Web.MixProject do
  use Mix.Project

  @version "2.9.6"

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
      {:oban, "~> 2.11"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.1"},
      {:phoenix_live_view, ">= 0.17.4 and < 0.19.0"},
      {:phoenix_view, "~> 2.0"},
      {:esbuild, "~> 0.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21", only: [:dev], runtime: false},
      {:lys_publish, "~> 0.1", only: [:dev], runtime: false, path: "../lys_publish"},
      {:credo, "~> 1.6", only: [:test, :dev], runtime: false},
      {:oban_pro, "~> 0.12", only: [:test, :dev], repo: :oban},
      {:floki, "~> 0.26", only: [:test]},
      {:stream_data, "~> 0.5", only: [:test]}
    ]
  end

  defp aliases do
    [
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

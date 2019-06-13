defmodule ObanWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_web,
      version: "0.1.0",
      elixir: "~> 1.8",
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      description: "Oban Web Component"
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
      licenses: ["Commercial"],
      links: []
    ]
  end

  defp deps do
    [
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:oban, "~> 0.4"},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_live_view, github: "phoenixframework/phoenix_live_view", only: [:dev, :test]},
      {:phoenix_pubsub, "~> 1.1"}
    ]
  end
end

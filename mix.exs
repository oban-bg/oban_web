defmodule ObanWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_web,
      version: "0.1.0",
      elixir: "~> 1.8",
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:oban, ">= 0.0.0", github: "sorentwo/oban"},
      {:phoenix, "~> 1.4.3"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_pubsub, "~> 1.1"}
    ]
  end
end

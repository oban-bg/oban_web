defmodule ObanDash.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_dash,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {ObanDash.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:bandit, "~> 1.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.19"},
      {:oban, "~> 2.20"},
      {:oban_web, oban_web_requirement()},
      {:oban_met, "~> 1.0"}
    ] ++ oban_pro_dep()
  end

  # Release builds pin the exact tagged version, so an image can't silently ship an older package
  # when it builds before the tagged release is available on Hex.
  defp oban_web_requirement do
    case System.get_env("OBAN_WEB_VERSION") do
      version when is_binary(version) and version != "" -> version
      _unset -> "~> 2.13"
    end
  end

  defp oban_pro_dep do
    if System.get_env("OBAN_LICENSE_KEY") do
      [{:oban_pro, "~> 1.6", repo: :oban}]
    else
      []
    end
  end

  defp releases do
    [
      oban_dash: [
        include_executables_for: [:unix]
      ]
    ]
  end
end

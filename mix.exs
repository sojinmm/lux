defmodule Lux.MixProject do
  use Mix.Project

  def project do
    [
      app: :lux,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Lux.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:stream_data, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.4.5", only: :dev, runtime: false},
      {:venomous, "~> 0.7.5"},
      {:mock, "~> 0.3.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dotenvy, "~> 0.8.0", only: [:dev, :test]},
      {:crontab, "~> 1.1"},
      {:ex_json_schema, "~> 0.10.2"}
    ]
  end
end

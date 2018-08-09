defmodule JokenJwks.MixProject do
  use Mix.Project

  def project do
    [
      app: :joken_jwks,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {JokenJwks.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:joken, "~> 2.0.0-rc0"},
      {:jason, "~> 1.1"},
      {:cachex, "~> 3.0"},
      {:tesla, "~> 1.1"},

      # docs
      {:ex_doc, "0.18.4", only: :dev, override: true},

      # linter
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end
end

defmodule JokenJwks.MixProject do
  use Mix.Project

  @source_url "https://github.com/joken-elixir/joken_jwks"
  @version "1.4.1"

  def project do
    [
      app: :joken_jwks,
      version: @version,
      name: "Joken JWKS",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      package: package(),
      deps: deps(),
      docs: docs(),
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
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:joken, "~> 2.3"},
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.3"},
      {:hackney, "~> 1.17.0"},
      {:telemetry, "~> 0.4.2"},

      # docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},

      # linters & coverage
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test},

      # tests
      {:mox, "~> 0.5", only: :test}
    ]
  end

  defp package do
    [
      description: "JWKS (JSON Web Keys Set) support for Joken2",
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
      maintainers: ["Bryan Joseph", "Victor Nascimento"],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/joken_jwks/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      source_url: @source_url,
      source_ref: "v#{@version}",
      main: "readme",
      formatters: ["html"]
    ]
  end
end

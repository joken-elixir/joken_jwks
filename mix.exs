defmodule JokenJwks.MixProject do
  use Mix.Project

  @version "1.3.1"

  def project do
    [
      app: :joken_jwks,
      version: @version,
      name: "Joken JWKS",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      description: description(),
      package: package(),
      deps: deps(),
      source_ref: "v#{@version}",
      source_url: "https://github.com/joken-elixir/joken_jwks",
      docs: docs_config(),
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
      {:joken, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:tesla, "~> 1.2"},
      {:hackney, "~> 1.16.0"},
      {:telemetry, "~> 0.4.1"},

      # docs
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},

      # linters & coverage
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},

      # tests
      {:mox, "~> 0.5", only: :test}
    ]
  end

  defp description do
    """
    JWKS (JSON Web Keys Set) support for Joken2
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
      maintainers: ["Bryan Joseph", "Victor Nascimento"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/joken-elixir/joken_jwks",
        "Docs" => "http://hexdocs.pm/joken_jwks"
      }
    ]
  end

  defp docs_config do
    [
      extra_section: "GUIDES",
      extras: [
        "guides/introduction.md",
        {"CHANGELOG.md", [title: "Changelog"]}
      ],
      main: "introduction"
    ]
  end
end

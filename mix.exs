defmodule JokenJwks.MixProject do
  use Mix.Project

  def project do
    [
      app: :joken_jwks,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:joken, github: "victorolinasc/joken", branch: "vn/joken2_poc"},
      {:jason, "~> 1.1"},
      {:cachex, "~> 3.0"},
      {:tesla, "~> 1.0"}
    ]
  end
end

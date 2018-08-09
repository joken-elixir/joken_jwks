# JokenJwks

A `Joken.Hooks` implementation that builds a signer out of a JWKS url for verification.

## Usage

After [installation](#installation), you can add this hook to your token module like this:

``` elixir
defmodule MyToken do
  use Joken.Config
  
  add_hook(JokenJwks, jwks_url: "https://some.url")
  
  # ... rest of token configuration
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `joken_jwks` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:joken_jwks, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/joken_jwks](https://hexdocs.pm/joken_jwks).


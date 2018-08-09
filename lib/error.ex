defmodule JokenJwks.Error do
  @moduledoc "JWKS errors"

  defexception [:reason]

  @impl true
  def exception(reason), do: %__MODULE__{reason: reason}

  @impl true
  def message(%__MODULE__{reason: :no_jwks_url}),
    do: """
    No option `jwks_url` was passed. We can't fetch a signer without it.

    When you add `JokenJwks` hook, you must pass a `jwks_url` option:

    `add_hook(JokenJwks, jwks_url: "https://example_url.com)`
    """
end

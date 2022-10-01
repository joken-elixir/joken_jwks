defmodule JokenJwks.SignerMatchStrategy do
  @moduledoc """
  A strategy behaviour for using with `JokenJwks`.

  JokenJwks will call this for every token with a kid. It is the strategy's responsibility to handle
  caching and matching of the kid with its signers cache.

  See `JokenJwks.DefaultStrategyTemplate` for an implementation.
  """

  @callback match_signer_for_kid(kid :: binary(), hook_options :: any()) ::
              {:ok, Joken.Signer.t()} | {:error, reason :: atom()}

  # When dealing with dynamically generated strategies (via GenServer), also implement this one
  @callback match_signer_for_kid(pid :: pid(), kid :: binary(), hook_options :: any()) ::
              {:ok, Joken.Signer.t()} | {:error, reason :: atom()}

  @optional_callbacks match_signer_for_kid: 3
end

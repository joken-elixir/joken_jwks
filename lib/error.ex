defmodule JokenJwks.Error do
  defexception [:reason]

  def exception(reason), do: %__MODULE__{reason: reason}

  def message(%__MODULE__{reason: [:no_configuration_set, app]}),
    do: """
    No configuration was set for fetching JWKs keys for application: #{app}.

    It is expected that `joken_jwks_url` and `joken_jwks_key_id` be set.

    If you need dynamic values, set them under your intialization callback.
    """
end

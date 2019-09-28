defmodule JokenJwks.HttpFetcher do
  @moduledoc """
  Makes a GET request to an OpenID Connect certificates endpoint.

  This must be a standard JWKS URI as per the specification here:
  https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata

  This uses the `Tesla` library to make it easy to test or change the adapter
  if wanted.

  See our tests for an example of mocking the HTTP fetching.
  """
  alias Tesla.Middleware, as: M

  @doc """
  Fetches the JWKS signers from the given url.

  This retries up to 10 times with a fixed delay of 500 ms until the server
  delivers an answer. We only perform a GET request that is idempotent.

  We use `:hackney` as it validates certificates automatically.
  """
  @spec fetch_signers(binary, boolean) :: {:ok, list} | {:error, atom} | no_return()
  def fetch_signers(url, opts) do
    log_level = opts[:log_level]

    with {:ok, resp} <- Tesla.get(new(opts), url),
         {:status, 200} <- {:status, resp.status},
         {:keys, keys} when not is_nil(keys) <- {:keys, resp.body["keys"]} do
      JokenJwks.log(:debug, log_level, "JWKS fetching: fetched keys -> #{inspect(keys)}")
      {:ok, keys}
    else
      {:status, status} when is_integer(status) and status >= 400 and status < 500 ->
        JokenJwks.log(:debug, log_level, "JWKS fetching: #{status} -> client error")
        {:error, :jwks_client_http_error}

      {:status, status} when is_integer(status) and status >= 500 ->
        JokenJwks.log(:debug, log_level, "JWKS fetching: #{status} -> server error")
        {:error, :jwks_server_http_error}

      {:status, _status} ->
        {:error, :status_not_200}

      {:error, :econnrefused} ->
        JokenJwks.log(:debug, log_level, "JWKS fetching: could not connect (:econnrefused)")
        {:error, :could_not_reach_jwks_url}

      {:keys, nil} ->
        {:error, :no_keys_on_response}

      error ->
        JokenJwks.log(:debug, log_level, "JWKS fetching: unkown error #{inspect(error)}")
        error
    end
  end

  @default_adapter Tesla.Adapter.Hackney

  defp new(opts) do
    adapter =
      Application.get_env(:tesla, __MODULE__)[:adapter] ||
        Application.get_env(:tesla, :adapter, @default_adapter)

    adapter = opts[:http_adapter] || adapter

    middleware = [
      {M.JSON, decode_content_types: ["application/jwk-set+json"]},
      M.Logger,
      {M.Retry,
       delay: opts[:http_delay_per_retry] || 500,
       max_retries: opts[:http_max_retries_per_fetch] || 10}
    ]

    Tesla.client(middleware, adapter)
  end
end

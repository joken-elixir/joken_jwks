defmodule JokenJwks.HttpFetcher do
  use Tesla, doc: false

  alias Tesla.Middleware

  plug(Middleware.Retry, delay: 500, max_retries: 10)
  plug(Middleware.JSON)
  plug(Middleware.Logger)

  @doc "Fetches the Joken.Signer from configuration"
  def fetch_signers(url) do
    {:ok, resp} = get(url)

    with 200 <- resp.status,
         keys <- resp.body["keys"] do
      {:ok, keys}
    else
      status when is_integer(status) and status >= 400 and status < 500 ->
        {:error, :jwks_client_http_error}

      status when is_integer(status) and status >= 500 ->
        {:error, :jwks_server_http_error}

      error ->
        error
    end
  end
end

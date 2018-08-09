defmodule JokenJwks.HttpFetcher do
  @moduledoc "Fetches signers in the JWKS url"

  use Tesla, docs: false

  alias Tesla.Middleware

  plug(Middleware.Retry, delay: 500, max_retries: 10)
  plug(Middleware.JSON)
  plug(Middleware.Logger)

  @doc """
  Fetches the JWKS signers from the given url

  This retries up to 10 times with a fixed delay of 500 ms until the server
  delivers an answer. We only perform a GET request that is idempotent.
  """
  @spec fetch_signers(binary) :: {:ok, map} | {:error, atom}
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

defmodule JokenJwks.HttpFetcher do
  use Tesla

  plug(Tesla.Middleware.Retry, delay: 500, max_retries: 10)
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Logger)

  def fetch_signer(_opts = [jwks_url: url, key_id: key_id]) do
    {:ok, resp} = get(url)

    with 200 <- resp.status,
         keys <- resp.body["keys"] do
      do_parse_key(Enum.filter(keys, &(&1["kid"] == key_id)))
    else
      status when is_integer(status) and status >= 400 and status < 500 ->
        {:error, :client_http_error}

      status when is_integer(status) and status > 500 ->
        {:error, :server_http_error}

      error ->
        error
    end
  end

  defp do_parse_key(nil) do
    {:error, :no_key_found}
  end

  defp do_parse_key([key = %{"alg" => alg}]) when is_map(key) do
    {:ok, Joken.Signer.create(alg, key)}
  end
end

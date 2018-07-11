defmodule JokenJwksHook do
  use Joken.Hooks

  @cache :joken_jwks_cache

  @impl true
  def before_verify(options, token, _signer) do
    with {:ok, signer} <- fetch_signer(options) do
      {:ok, token, signer}
    else
      error ->
        {:halt, error}
    end
  end

  defp fetch_signer(opts = [jwks_url: _url, key_id: _id]) do
    with {:ok, signer} <- Cachex.fetch(@cache, :signer, fn _ -> {:error, :missing} end) do
      {:ok, signer}
    else
      {:error, :missing} ->
        {:ok, signer} = JokenJwksHook.Fetcher.fetch_signer(opts)

        if is_nil(signer) do
          {:halt, :could_not_signer}
        else
          Cachex.put(@cache, :signer, signer)
          {:ok, signer}
        end
    end
  end
end

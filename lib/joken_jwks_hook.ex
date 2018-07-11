defmodule JokenJwks do
  use Joken.Hooks

  @cache :joken_jwks_cache

  @impl true
  def before_verify(hook_options, token, _signer) do
    with {:ok, signer} <- hook_options |> fetch_jwks_options() |> fetch_signer() do
      {:ok, token, signer}
    else
      error ->
        {:halt, error}
    end
  end

  defp fetch_jwks_options(options) do
    app = options[:app_config] || :joken_jwks
    url = Application.get_env(app, :joken_jwks_url)
    key_id = Application.get_env(app, :joken_jwks_key_id)

    unless url && key_id, do: raise(JokenJwks.Error, [:no_configuration_set, app])

    [jwks_url: url, key_id: key_id]
  end

  defp fetch_signer(opts = [jwks_url: _url, key_id: _id]) do
    with {:ok, signer} <- Cachex.fetch(@cache, :signer, fn _ -> {:error, :missing} end) do
      {:ok, signer}
    else
      {:error, :missing} ->
        {:ok, signer} = JokenJwks.HttpFetcher.fetch_signer(opts)

        if is_nil(signer) do
          {:halt, :could_not_signer}
        else
          Cachex.put(@cache, :signer, signer)
          {:ok, signer}
        end
    end
  end
end

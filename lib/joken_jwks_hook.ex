defmodule JokenJwks do
  use Joken.Hooks

  @cache :joken_jwks_cache

  @impl true
  def before_verify(_hook_options, {:error, reason}, _token, _signer), do: {:error, reason}

  def before_verify(hook_options, _status, token, _signer) do
    with {:ok, signers} <- hook_options |> fetch_jwks_url() |> fetch_signers(),
         {:ok, signer} <- match_signer_with_token(token, signers) do
      {:cont, {:ok, token, signer}}
    else
      err ->
        {:halt, err}
    end
  end

  defp match_signer_with_token(token, signers) do
    kid =
      token
      |> Joken.peek_header()
      |> Map.get("kid")

    with {^kid, signer} <-
           Enum.find(signers, {:error, :kid_does_not_match}, &(elem(&1, 0) == kid)) do
      {:ok, signer}
    end
  end

  defp fetch_jwks_url(options) do
    app = options[:app_config] || :joken_jwks
    url = Application.get_env(app, :joken_jwks_url)

    unless url, do: raise(JokenJwks.Error, [:no_configuration_set, app])
    url
  end

  defp fetch_signers(url) do
    case Cachex.get(@cache, :jwks_signers) do
      {:ok, signers} when not is_nil(signers) ->
        {:ok, signers}

      _ ->
        with {:ok, keys} when not is_nil(keys) <- JokenJwks.HttpFetcher.fetch_signers(url) do
          signers =
            Enum.map(keys, fn key -> {key["kid"], Joken.Signer.create(key["alg"], key)} end)

          Cachex.put(@cache, :jwks_signers, signers)
          {:ok, signers}
        else
          {:ok, nil} ->
            {:error, :could_not_fetch_signers}

          err ->
            err
        end
    end
  end
end

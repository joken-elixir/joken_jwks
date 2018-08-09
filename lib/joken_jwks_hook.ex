defmodule JokenJwks do
  @moduledoc """
  Fetches a signer from a public JWKS URL

  This hook is intended to be used when you are verifying a token is signed with
  a well known public key. This is, for example, part of the OpenID Connect spec.

  To use it, pass this hook to Joken either with the `add_hook/2` macro or directly
  to each Joken function. Example:

      defmodule MyToken do
        use Joken.Config
        
        add_hook(JokenJwks, jwks_url: "https://some-well-known-jwks-url.com")
        
        # rest of your token config
      end

  ## Options

  This hook accepts 2 types of configuration: 

    - `app_config`: accepts an atom that should be the application that has a 
      configuration key `joken_jwks_url`. This is a dynamic configuration. 
    - `jwks_url`: the fixed URL for the JWKS. This is a static configuration.

  """

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
    app = options[:app_config]

    jwks_url =
      if is_nil(app) do
        options[:jwks_url]
      else
        Application.get_env(app, :joken_jwks_url)
      end

    unless jwks_url, do: raise(JokenJwks.Error, :no_jwks_url)

    jwks_url
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

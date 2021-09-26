defmodule JokenJwks do
  @moduledoc """
  `Joken.Hooks` implementation for fetching `Joken.Signer`s from public JWKS URLs.

  This hook is intended to be used when you are _verifying_ a token is signed with
  a well known public key. It only overrides the `before_verify/2` callback providing a
  `Joken.Signer` for the given token. It is important to notice this is not meant for
  use when **GENERATING** a token. So, using this hook with `Joken.encode_and_sign`
  function **WILL NOT WORK!!!**

  To use it, pass this hook to Joken either with the `add_hook/2` macro or directly
  to each `Joken` function. Example:

      defmodule MyToken do
        use Joken.Config

        add_hook(JokenJwks, strategy: MyFetchingStrategy)

        # rest of your token config
      end

  Or:

      Joken.verify_and_validate(config, token, nil, context, [{Joken.Jwks, strategy: MyStrategy}])

  ## Fetching strategy

  Very rarely, your authentication server might rotate or block its keys. Key rotation is the
  process of issuing a new key that in time will replace the older key. This is security hygiene
  and should/might be a regular process.

  Sometimes it is important to block keys because they got leaked or for any other reason.

  Other times you simply don't control the authentication server and can't ensure the keys won't
  change. This is the most common scenario for this hook.

  In these cases (and some others) it is important to have a cache invalidation strategy: all your
  cached keys should be refreshed. Since the best strategy might differ for each use case, there
  is a behaviour that can be customized as the "fetching strategy", that is: when to fetch and re-fetch
  keys. `JokenJwks` has a default strategy that tries to be smart and cover most use cases by default.
  It combines a time based state machine to avoid overflowing the system with re-fetching keys. If  that
  is not a good option for your use case, it can still be configured. Please, see
  `JokenJwks.SignerMatchStrategy` or `JokenJwks.DefaultStrategyTemplate` docs for more information.
  """

  require Logger

  use Joken.Hooks

  @impl true
  def before_verify(hook_options, {token, _signer}) do
    with strategy <- hook_options[:strategy] || raise("No strategy provided"),
         {:ok, kid} <- get_token_kid(token),
         {:ok, signer} <- strategy.match_signer_for_kid(kid, hook_options) do
      {:cont, {token, signer}}
    else
      err -> {:halt, err}
    end
  end

  defp get_token_kid(token) do
    with {:ok, headers} <- Joken.peek_header(token),
         {:kid, kid} when not is_nil(kid) <- {:kid, headers["kid"]} do
      {:ok, kid}
    else
      {:kid, nil} -> {:error, :no_kid_in_token_header}
      err -> err
    end
  end

  def log(_, :none, _), do: :ok

  def log(:debug, log_level, msg) do
    unless Logger.compare_levels(:debug, log_level) == :lt, do: Logger.debug(fn -> msg end)
  end

  def log(:info, log_level, msg) do
    unless Logger.compare_levels(:info, log_level) == :lt, do: Logger.info(fn -> msg end)
  end

  def log(:warn, log_level, msg) do
    unless Logger.compare_levels(:warn, log_level) == :lt, do: Logger.warn(fn -> msg end)
  end

  def log(:error, _, msg), do: Logger.error(msg)
end

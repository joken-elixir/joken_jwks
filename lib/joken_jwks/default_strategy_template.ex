defmodule JokenJwks.DefaultStrategyTemplate do
  @moduledoc """
  A `JokenJwks.SignerMatchStrategy` template that has a window of time for refreshing its
  cache. This is a template and not a concrete implementation. You should `use` this module
  in order to use the default strategy.

  This implementation is a task that should be supervised. It loops on a time window checking
  whether it should re-fetch keys or not.

  Every time a bad kid is received it writes to an ets table a counter to 1. When the task
  loops, it polls for the counter value. If it is more than zero it starts re-fetching the
  cache. Upon successful fetching, it zeros the counter once again. This way we avoid
  overloading the JWKS server.

  It will try to fetch signers when supervision starts it. This can be a sync or async operation
  depending on the value of `first_fetch_sync`. It defaults to `false`.

  ## Resiliency

  This strategy tries to be smart about keys it can USE to verify signatures. For example, if the
  provider has encryption keys, it will skip those (any key with field "use" with value "enc").

  Also, if the running BEAM instance has no support for a given signature algorithm (possibly not implemented
  on the given OpenSSL + BEAM + JOSE combination) this implementation will also skip those.

  Be sure to check your logs as if there are NO signers available it will log a warning telling you
  that.

  For debugging purpouses, calling the function `fetch_signers/2` directly might be helpful.

  ## Usage

  This strategy must be under your apps' supervision tree. It must be explicitly used under a
  module so that you can have more than one JWKS source.

  When using this strategy, there is an `init_opts/1` callback that can be overridden. This is called
  upon supervision start. It should return a keyword list with all the options. This follows the
  standard practice of allowing a callback for using runtime configuration. It can override all
  other options as this has higher preference.

  ## Configuration

  Other than the `init_opts/1` callback you can pass options through `Config` and when starting
  the supervisor. The order of preference in least significant order is:

    - Per environment `Config`
    - Supervisor child options
    - `init_opts/1` callback

  The only mandatory option is `jwks_url` (`binary()`) that is, usually, a
  runtime parameter like a system environment variable. It is recommended to
  use the `init_opts/1` callback.

  Other options are:

    - `time_interval` (`integer()` - default 60_000 (1 minute)): time interval
      for polling if it is needed to re-fetch the keys

    - `should_start` (`boolean()` - default `true`): whether to start the
      supervised polling task. For tests, this should be false

    - `first_fetch_sync` (`boolean()` - default `false`): whether to fetch the
      first time synchronously or async

    - `explicit_alg` (`String.t()`): the JWS algorithm for use with the key.
      Overrides the one in the JWK

    - `http_max_retries_per_fetch` (`pos_integer()` - default `10`): passed to
      `Tesla.Middleware.Retry`

    - `http_delay_per_retry` (`pos_integer()` - default `500`): passed to
      `Tesla.Middleware.Retry`

  ### Examples

      defmodule JokenExample.MyStrategy do
        use JokenJwks.DefaultStrategyTemplate

        def init_opts(opts) do
          url = # fetch url ...
          Keyword.merge(opts, jwks_url: url)
        end
      end

      defmodule JokenExample.Application do
        @doc false
        def start(_type, _args) do
          import Supervisor.Spec, warn: false

          children = [
            {MyStrategy, time_interval: 2_000}
          ]

          opts = [strategy: :one_for_one]
          Supervisor.start_link(children, opts)
        end
      end

  Then on your token configuration module:

      defmodule MyToken do
        use Joken.Config

        add_hook(JokenJwks, strategy: MyStrategy)
        # rest of your token config
      end


  ## Telemetry events

  This library produces events for helping understand its behaviour. Event prefix is
  `[:joken_jwks, :default_strategy]`. It always add the module as a metadata.

  This can be useful to implement logging.

  Events:

  - `[:joken_jwks, :default_strategy, :refetch]`: starts refetching
  - `[:joken_jwks, :default_strategy, :signers]`: signers sucessfully fetched
  - `[:joken_jwks, :http_fetcher, :start | :stop | :exception]`: http lifecycle
  """

  require Logger

  alias TestToken.Strategy.EtsCache
  alias JokenJwks.DefaultStrategyTemplate.EtsCache
  alias JokenJwks.DefaultStrategyTemplate
  alias Joken.Signer
  alias JokenJwks.{HttpFetcher, SignerMatchStrategy}

  @telemetry_prefix [:joken_jwks, :default_strategy]

  defmacro __using__(_opts) do
    quote do
      use GenServer, restart: :transient

      alias JokenJwks.DefaultStrategyTemplate
      alias JokenJwks.SignerMatchStrategy

      @behaviour SignerMatchStrategy

      @doc "Callback for initializing options upon strategy startup"
      @spec init_opts(opts :: Keyword.t()) :: Keyword.t()
      def init_opts(opts), do: opts

      @impl SignerMatchStrategy
      def match_signer_for_kid(kid, opts),
        do: DefaultStrategyTemplate.match_signer_for_kid(__MODULE__, kid, opts)

      defoverridable init_opts: 1

      @doc false
      def start_link(opts), do: DefaultStrategyTemplate.start_link(__MODULE__, opts)

      # Server (callbacks)
      @impl GenServer
      def init(opts), do: DefaultStrategyTemplate.init(__MODULE__, opts)

      @doc false
      @impl GenServer
      def handle_info(:check_fetch, state) do
        DefaultStrategyTemplate.check_fetch(__MODULE__, state[:jwks_url], state)
        DefaultStrategyTemplate.schedule_check_fetch(__MODULE__, state[:time_interval])

        {:noreply, state}
      end
    end
  end

  @doc false
  def start_link(module, opts) do
    opts =
      Application.get_env(:joken_jwks, module, [])
      |> Keyword.merge(opts)
      |> module.init_opts()

    opts[:jwks_url] || raise "No url set for fetching JWKS!"

    GenServer.start_link(module, opts, name: module)
  end

  @doc false
  def init(module, opts) do
    [_, _, {:jws, {:alg, algs}}] = JOSE.JWA.supports()

    opts =
      opts
      |> Keyword.put_new(:time_interval, 60 * 1_000)
      |> Keyword.put(:jws_supported_algs, algs)
      |> Keyword.put(:mod, module)

    # init callback runs in the server process already
    EtsCache.new(module)

    first_fetch_sync = Keyword.get(opts, :first_fetch_sync)

    if first_fetch_sync do
      fetch_signers(module, opts[:jwks_url], opts)
    end

    if Keyword.get(opts, :should_start, true) do
      EtsCache.set_status(module, :refresh)
      initial_interval = if first_fetch_sync, do: opts[:time_interval], else: 0
      schedule_check_fetch(module, initial_interval)
      {:ok, opts}
    else
      :ignore
    end
  end

  @doc false
  def check_fetch(module, url, opts) do
    case EtsCache.check_state(module) do
      # no need to re-fetch
      0 ->
        :ok

      # start re-fetching
      _counter ->
        :telemetry.execute(@telemetry_prefix ++ [:refetch], %{count: 1}, %{module: module})
        fetch_signers(module, url, opts)
    end
  end

  @doc false
  def match_signer_for_kid(module, kid, _hook_options) do
    with {:cache, [{:signers, signers}]} <- {:cache, EtsCache.get_signers(module)},
         {:signer, signer} when not is_nil(signer) <- {:signer, signers[kid]} do
      {:ok, signer}
    else
      {:signer, nil} ->
        EtsCache.set_status(module, :refresh)
        {:error, :kid_does_not_match}

      {:cache, []} ->
        {:error, :no_signers_fetched}

      err ->
        err
    end
  end

  @doc "Fetch signers with `JokenJwks.HttpFetcher`"
  def fetch_signers(module, url, opts) do
    with {:ok, keys} <- HttpFetcher.fetch_signers(url, opts),
         {:ok, signers} <- validate_and_parse_keys(keys, opts) do
      :telemetry.execute(
        @telemetry_prefix ++ [:signers],
        %{count: 1},
        %{module: module, signers: signers}
      )

      if signers == %{} do
        Logger.warning("NO VALID SIGNERS FOUND!")
      end

      true = EtsCache.put_signers(module, signers)
      EtsCache.set_status(module, :ok)

      {:ok, opts}
    else
      {:error, _reason} = err ->
        Logger.error("Failed to fetch signers. Reason: #{inspect(err)}")
        EtsCache.set_status(module, :refresh)
        err

      err ->
        Logger.error("Unexpected error while fetching signers. Reason: #{inspect(err)}")
        EtsCache.set_status(module, :refresh)
        err
    end
  end

  defp validate_and_parse_keys(keys, opts) when is_list(keys) do
    Enum.reduce_while(keys, {:ok, %{}}, fn key, {:ok, acc} ->
      case parse_signer(key, opts) do
        {:ok, signer} -> {:cont, {:ok, Map.put(acc, key["kid"], signer)}}
        # We don't support "enc" keys but should not break otherwise
        {:error, :not_signing_key} -> {:cont, {:ok, acc}}
        # We skip unknown JWS algorithms or JWEs
        {:error, :not_signing_alg} -> {:cont, {:ok, acc}}
        e -> {:halt, e}
      end
    end)
  end

  defp parse_signer(key, opts) do
    with {:use, true} <- {:use, key["use"] != "enc"},
         {:kid, kid} when is_binary(kid) <- {:kid, key["kid"]},
         {:ok, alg} <- get_algorithm(key["alg"], opts[:explicit_alg]),
         {:jws_alg?, true} <- {:jws_alg?, alg in opts[:jws_supported_algs]},
         {:ok, _signer} = res <- {:ok, Signer.create(alg, key)} do
      res
    else
      {:use, false} -> {:error, :not_signing_key}
      {:kid, _} -> {:error, :kid_not_binary}
      {:jws_alg?, false} -> {:error, :not_signing_alg}
      err -> err
    end
  rescue
    e ->
      Logger.error("""
      Error while parsing a key entry fetched from the network.

      This should be investigated by a human.

      Key: #{inspect(key)}

      Error: #{inspect(e)}
      """)

      {:error, :invalid_key_params}
  end

  # According to JWKS spec (https://tools.ietf.org/html/rfc7517#section-4.4) the "alg"" claim
  # is not mandatory. This is why we allow this to be passed as a hook option.
  #
  # We give preference to the one provided as option
  defp get_algorithm(nil, nil), do: {:error, :no_algorithm_supplied}
  defp get_algorithm(_, alg) when is_binary(alg), do: {:ok, alg}
  defp get_algorithm(alg, _) when is_binary(alg), do: {:ok, alg}
  defp get_algorithm(_, _), do: {:error, :bad_algorithm}

  @doc false
  def schedule_check_fetch(module, interval),
    do: Process.send_after(module, :check_fetch, interval)
end

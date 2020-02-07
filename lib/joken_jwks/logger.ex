defmodule JokenJwks.Logger do
  @moduledoc """
  Telemetry integration to handle metrics
  and log them using Logger

  This handler is attached by default when opts[:disable_logs]
  is nil or false, and prints all infos/errors to console.

  To set your own interceptor for telemetry events,
  see https://github.com/beam-telemetry/telemetry
  """

  require Logger

  @events [
    ~w/joken_jwks fetch_signers success/a,
    ~w/joken_jwks fetch_signers error/a,
    ~w/joken_jwks http_fetch_signers success/a,
    ~w/joken_jwks http_fetch_signers error/a,
    ~w/joken_jwks ets_cache not_needed/a,
    ~w/joken_jwks ets_cache needed/a,
    ~w/joken_jwks parse_signer error/a,
  ]

  @doc """
  Default logger is attached when there is
  no explicit config for disabling it and
  splits error, success and debug events
  """
  def attach_default_logger(level) do
    :telemetry.attach_many("jokenjwks-default-logger", @events, &handle_event/4, level)
  end

  defp handle_event([:joken_jwks, :ets_cache, message], _measure, metadata, _level) do
    Logger.debug(fn -> "ets_cache #{message}: #{metadata[:message]}" end)
  end

  defp handle_event([:joken_jwks, function, :error], _measure, metadata, _level) do
    Logger.warn("error in #{function}: #{inspect(metadata)}")
  end

  defp handle_event([:joken_jwks, function, :success], _measure, metadata, _level) do
    Logger.info("success in #{function}: #{inspect(metadata)}")
  end
end

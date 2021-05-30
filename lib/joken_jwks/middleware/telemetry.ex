defmodule JokenJwks.Middleware.Telemetry do
  @moduledoc """
  Tesla Middleware for publishing telemetry events.

  This middleware reports status and request time/response useful for
  monitoring the JWKS provider.
  """

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, opts) do
    {time, res} = :timer.tc(Tesla, :run, [env, next])

    :telemetry.execute([opts[:telemetry_prefix], :joken_jwks, :request], %{request_time: time}, %{
      result: res
    })

    res
  end
end

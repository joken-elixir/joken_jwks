defmodule JokenJwks.Middleware.Telemetry do
  @moduledoc """
  Middleware used on Tesla calls to intercept
  request time and response content and
  report to :telemetry library
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

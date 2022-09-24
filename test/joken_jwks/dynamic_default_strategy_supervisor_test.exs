defmodule JokenJwks.DynamicDefaultStrategySupervisorTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import Mox
  import Tesla.Mock, only: [json: 1, json: 2]
  alias JokenJwks.DynamicDefaultStrategySupervisor
  alias JokenJwks.DynamicDefaultStrategyRegistry
  alias JokenJwks.TestUtils

  setup :set_mox_from_context

  test "should create child with naming done with Registry" do
    ref = setup_jwks()

    child_spec_list = [
      DynamicDefaultStrategyRegistry,
      DynamicDefaultStrategySupervisor
    ]

    started_children =
      for child <- child_spec_list do
        start_supervised(child)
      end

    opts = [
      jwks_url: "http://jwks",
      strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :tenant_x_jwks_strategy}}
    ]

    DynamicDefaultStrategySupervisor.start_strategy(opts) |> IO.inspect()

    wait_until_jwks_call_done(ref)
  end

  defp setup_jwks(time_interval \\ 1_000) do
    ref =
      expect_call(fn %{url: "http://jwks"} ->
        {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
      end)

    # start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", time_interval: time_interval})
    :timer.sleep(100)
    ref
  end

  defp expect_call(num_of_invocations \\ 1, function) do
    parent = self()
    ref = make_ref()

    send(parent, {ref, :called})
    expect(TeslaAdapterMock, :call, num_of_invocations, fn env, _opts -> function.(env) end)
    ref
  end

  defp wait_until_jwks_call_done(ref) do
    assert_receive {^ref, :called}
    verify!()
  end
end

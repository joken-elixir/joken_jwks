Application.ensure_all_started(:telemetry)

defmodule JokenJwks.DefaultStrategyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox
  import Tesla.Mock, only: [json: 1, json: 2]
  alias JokenJwks.TestUtils

  setup :set_mox_global
  setup :verify_on_exit!

  @moduletag :capture_log

  test "can fetch keys" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id2"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "fails if kid does not match" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)
  end

  test "fails if it can't fetch" do
    parent = self()
    ref = make_ref()

    expect_call(fn %{url: "http://jwks/500"} ->
      send(parent, {ref, :continue})
      {:ok, %Tesla.Env{status: 500}}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks/500"})

    assert_receive {^ref, :continue}

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
    assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
  end

  test "fails if no option was provided" do
    assert_raise(RuntimeError, ~r/No url set for fetching JWKS!/, fn ->
      start_supervised!({TestToken.Strategy, []})
    end)
  end

  test "can configure window of time for searching for new signers" do
    setup_jwks(500)

    expect_call(fn %{url: "http://jwks"} ->
      {:ok,
       json(%{
         "keys" => [
           TestUtils.build_key("id1"),
           TestUtils.build_key("id2"),
           TestUtils.build_key("id3")
         ]
       })}
    end)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)

    :timer.sleep(800)
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "fetches only one per window of time invariably" do
    setup_jwks(2_000)

    expect_call(fn %{url: "http://jwks"} ->
      {:ok,
       json(%{
         "keys" => [
           TestUtils.build_key("id1"),
           TestUtils.build_key("id2"),
           TestUtils.build_key("id3")
         ]
       })}
    end)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))

    Enum.each(1..100, fn _ ->
      assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)
    end)

    :timer.sleep(2_500)
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "fails if no signers are fetched" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1")]}, status: 500)}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks"})
    :timer.sleep(100)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
  end

  test "can skip start polling and fetching" do
    # expect 0 invocations
    expect_call(0, fn _, _opts -> :ok end)
    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", should_start: false})
    assert TestToken.Strategy.EtsCache.check_state() == 0
  end

  test "can set log_level to none" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    log =
      capture_log(fn ->
        start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", log_level: :none})
        :timer.sleep(100)
      end)

    assert not String.contains?(log, "Fetched signers. ")
  end

  test "can set log_level to error and skip debug messages" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    log =
      capture_log(fn ->
        start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", log_level: :error})
        :timer.sleep(100)
      end)

    # debug message not shown
    assert not String.contains?(log, "Fetched signers. ")
  end

  test "can set log_level to error and see error messages" do
    expect_call(fn %{url: "http://jwks/500"} -> {:ok, json(%{}, status: 500)} end)

    log =
      capture_log(fn ->
        start_supervised!({TestToken.Strategy, jwks_url: "http://jwks/500", log_level: :error})
        :timer.sleep(100)
      end)

    assert log =~ "Failed to fetch signers."
  end

  test "set telemetry_prefix to default prefix" do
    self = self()

    on_exit(fn -> :telemetry.detach("telemetry-test-default") end)

    :telemetry.attach(
      "telemetry-test-default",
      [TestToken.Strategy, :joken_jwks, :request],
      fn name, measurements, metadata, _ ->
        send(self, {:telemetry_event, name, measurements, metadata})
      end,
      nil
    )

    expect_call(fn %{url: "http://jwks/500"} -> {:ok, json(%{}, status: 500)} end)

    start_supervised!({TestToken.Strategy, [jwks_url: "http://jwks/500"]})

    assert_receive {:telemetry_event, [TestToken.Strategy, :joken_jwks, :request],
                    %{request_time: _}, %{result: {:ok, %Tesla.Env{}}}}
  end

  test "can set telemetry_prefix to a custom prefix" do
    self = self()

    :telemetry.attach(
      "telemetry_test_prefix",
      [:my_custom_prefix, :joken_jwks, :request],
      fn name, measurements, metadata, _ ->
        send(self, {:telemetry_event, name, measurements, metadata})
      end,
      nil
    )

    expect_call(fn %{url: "http://jwks/500"} -> {:ok, json(%{}, status: 500)} end)

    start_supervised!(
      {TestToken.Strategy, jwks_url: "http://jwks/500", telemetry_prefix: :my_custom_prefix}
    )

    assert_receive {:telemetry_event, [:my_custom_prefix, :joken_jwks, :request],
                    %{request_time: _}, %{result: {:ok, %Tesla.Env{}}}}
  end

  test "can set options on callback init_opts/1" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    start_supervised!({InitOptsToken.Strategy, log_level: :none})
    :timer.sleep(100)

    assert InitOptsToken.Strategy.EtsCache.get_signers()[:signers] |> Map.keys() == ["id1", "id2"]
  end

  test "can override alg" do
    expect_call(fn %{url: "http://jwks"} ->
      assert key = "id1" |> TestUtils.build_key() |> Map.put("alg", "RS256")
      assert key["alg"] == "RS256"
      {:ok, json(%{"keys" => [key]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", explicit_alg: "RS384"})
    :timer.sleep(100)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1", "RS384"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "can parse key without alg with option explicit_alg" do
    expect_call(fn %{url: "http://jwks"} ->
      assert key = "id1" |> TestUtils.build_key() |> Map.delete("alg")
      refute key["alg"]
      {:ok, json(%{"keys" => [key]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", explicit_alg: "RS384"})
    :timer.sleep(100)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1", "RS384"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "can start first fetch synchronously" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1")]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", first_fetch_sync: true})

    # no sleep here

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "even if first fetch sync fails will try to poll" do
    expect_call(2, fn %{url: "http://jwks"} -> {:error, :internal_error} end)

    start_supervised!(
      {TestToken.Strategy,
       jwks_url: "http://jwks",
       first_fetch_sync: true,
       time_interval: 100,
       http_max_retries_per_fetch: 1}
    )

    # We expect 3 calls in the timespan of 150 milliseconds:
    # 1. Try first fetch synchroonusly
    # 2. Because it fails, it will try again after time_interval
    :timer.sleep(120)
  end

  test "ignores keys with `use` as `enc`" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok,
       json(%{
         "keys" => [
           TestUtils.build_key("id1"),
           Map.merge(TestUtils.build_key("id2"), %{"use" => "enc", "alg" => "RSA-OAEP-256"})
         ]
       })}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", first_fetch_sync: true})

    # use is ignored
    assert length(TestToken.Strategy.EtsCache.get_signers()) == 1

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "ignores keys algorithms that are not JWS" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok,
       json(%{
         "keys" => [
           Map.merge(TestUtils.build_key("id1"), %{"use" => "sig", "alg" => "RSA-OAEP-256"})
         ]
       })}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", first_fetch_sync: true})

    # use is ignored
    assert length(TestToken.Strategy.EtsCache.get_signers()) == 0
  end

  def setup_jwks(time_interval \\ 1_000) do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", time_interval: time_interval})
    :timer.sleep(100)
  end

  defp expect_call(num_of_invocations \\ 1, function),
    do: expect(TeslaAdapterMock, :call, num_of_invocations, fn env, _opts -> function.(env) end)
end

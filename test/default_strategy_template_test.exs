:ok = Application.ensure_started(:telemetry)

defmodule JokenJwks.DefaultStrategyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox
  import Tesla.Mock, only: [json: 1, json: 2]

  alias JokenJwks.TestUtils
  alias JokenJwks.DefaultStrategyTemplate.EtsCache

  @telemetry_events [
    [:joken_jwks, :default_strategy, :refetch],
    [:joken_jwks, :default_strategy, :signers],
    [:joken_jwks, :http_fetcher, :start],
    [:joken_jwks, :http_fetcher, :stop],
    [:joken_jwks, :http_fetcher, :exception],
    [:tesla, :request, :start]
  ]

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    self = self()
    on_exit(fn -> :telemetry.detach("telemetry-test") end)

    capture_log(fn ->
      :telemetry.attach_many(
        "telemetry-test",
        @telemetry_events,
        &reply_telemetry(self, &1, &2, &3, &4),
        nil
      )
    end)

    :ok
  end

  test "can fetch keys" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id2"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)

    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :start], _, _}
    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :stop], _, _}

    assert_receive {:telemetry_event, [:joken_jwks, :default_strategy, :signers], %{count: 1},
                    %{signers: %{"id1" => _, "id2" => _}}}
  end

  test "fails if kid does not match" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)

    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :start], _, _}
    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :stop], _, _}

    assert_receive {:telemetry_event, [:joken_jwks, :default_strategy, :signers], %{count: 1},
                    %{signers: %{"id1" => _, "id2" => _}}}
  end

  test "fails if it can't fetch" do
    expect_call(fn %{url: "http://jwks/500"} -> {:ok, %Tesla.Env{status: 500}} end)

    assert capture_log(fn ->
             start_supervised!({TestToken.Strategy, jwks_url: "http://jwks/500"})

             token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
             assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
           end) =~ "[error] Failed to fetch signers. Reason: {:error, :jwks_server_http_error}"

    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :start], _, _}
    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :stop], _, _}
  end

  test "fails if http raises" do
    expect_call(fn %{url: "http://jwks"} -> {:error, :econnrefused} end)

    assert capture_log(fn ->
             start_supervised!(
               {TestToken.Strategy, jwks_url: "http://jwks", http_max_retries_per_fetch: 0}
             )

             token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
             assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
           end) =~ "[error] Failed to fetch signers. Reason: {:error, :could_not_reach_jwks_url}"

    assert_receive {:telemetry_event, [:joken_jwks, :http_fetcher, :start], _, _}
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
    setup_jwks(100)

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

    # Let's wait for next poll...
    # By default we are only populating id1 and id2
    # On poll it will add id3
    :timer.sleep(200)
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "allows not fetching sync the first time" do
    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))

    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1")]})}
    end)

    capture_log(fn ->
      start_supervised!(
        {TestToken.Strategy, jwks_url: "http://jwks", first_fetch_sync: false, time_interval: 100}
      )
    end)

    assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)

    # Let's wait for next poll...
    :timer.sleep(120)
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "can skip start polling and fetching" do
    # expect 0 invocations
    expect_call(0, fn _, _opts -> :ok end)

    capture_log(fn ->
      start_supervised!(
        {TestToken.Strategy,
         jwks_url: "http://jwks", should_start: false, first_fetch_sync: false}
      )
    end)

    assert :ets.whereis(TestToken.Strategy.EtsCache) == :undefined
  end

  test "can set extra tesla middlewares" do
    expect_call(fn %{url: "http://jwks/500"} -> {:ok, json(%{}, status: 500)} end)

    assert capture_log(fn ->
             start_supervised!(
               {TestToken.Strategy,
                jwks_url: "http://jwks/500", http_middlewares: [Tesla.Middleware.Telemetry]}
             )
           end) =~ "[error] Failed to fetch signers. Reason: {:error, :jwks_server_http_error}"

    assert_receive {:telemetry_event, [:tesla, :request, :start], %{system_time: _},
                    %{env: %Tesla.Env{}}}
  end

  test "can set options on callback init_opts/1" do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    # sets jwks URL dynamically on boot
    start_supervised!(InitOptsToken.Strategy)
    assert EtsCache.get_signers(InitOptsToken.Strategy)[:signers] |> Map.keys() == ["id1", "id2"]
  end

  test "can override alg" do
    expect_call(fn %{url: "http://jwks"} ->
      assert key = "id1" |> TestUtils.build_key() |> Map.put("alg", "RS256")
      assert key["alg"] == "RS256"
      {:ok, json(%{"keys" => [key]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", explicit_alg: "RS384"})

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

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1", "RS384"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "even if first fetch sync fails will try to poll" do
    expect_call(2, fn %{url: "http://jwks"} -> {:error, :econnrefused} end)

    assert capture_log(fn ->
             start_supervised!(
               # disable retries
               {TestToken.Strategy,
                jwks_url: "http://jwks", time_interval: 70, http_max_retries_per_fetch: 0}
             )

             # We expect 2 calls in the timespan of 100 milliseconds:
             # 1. Try first fetch synchronously
             # 2. Because it fails, it will try again after time_interval
             :timer.sleep(80)
           end) =~ "[error] Failed to fetch signers. Reason: {:error, :could_not_reach_jwks_url}"

    assert_receive {:telemetry_event, [:joken_jwks, :default_strategy, :refetch], %{count: 1},
                    %{module: TestToken.Strategy}}
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
    assert length(EtsCache.get_signers(TestToken.Strategy)) == 1

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

    assert capture_log(fn -> start_supervised!({TestToken.Strategy, jwks_url: "http://jwks"}) end) =~
             "NO VALID SIGNERS FOUND!"

    # use is ignored
    assert Enum.empty?(EtsCache.get_signers(TestToken.Strategy)[:signers])
  end

  test "ets table creation attempt should not error out even if table already exists" do
    setup_jwks()
    EtsCache.new(TestToken.Strategy)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id2"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  def setup_jwks(time_interval \\ 1_000) do
    expect_call(fn %{url: "http://jwks"} ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    start_supervised!({TestToken.Strategy, jwks_url: "http://jwks", time_interval: time_interval})
  end

  defp expect_call(num_of_invocations \\ 1, function),
    do: expect(TeslaAdapterMock, :call, num_of_invocations, fn env, _opts -> function.(env) end)

  defp reply_telemetry(pid, name, measurements, metadata, _config) do
    send(pid, {:telemetry_event, name, measurements, metadata})
  end
end

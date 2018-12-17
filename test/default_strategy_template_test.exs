defmodule JokenJwks.DefaultStrategyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox
  import Tesla.Mock, only: [json: 1, json: 2]
  alias Joken.Signer
  alias JokenJwks.TestUtils

  setup :set_mox_global
  setup :verify_on_exit!

  defmodule TestToken do
    use Joken.Config

    defmodule Strategy do
      use JokenJwks.DefaultStrategyTemplate
    end

    add_hook(JokenJwks, strategy: Strategy)

    def token_config, do: %{}
  end

  @tag :capture_log
  test "can fetch keys" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id2"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  @tag :capture_log
  test "fails if kid does not match" do
    setup_jwks()

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)
  end

  @tag :capture_log
  test "fails if it can't fetch" do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks/500"}, _opts ->
      {:ok, %Tesla.Env{status: 500}}
    end)

    TestToken.Strategy.start_link(jwks_url: "http://jwks/500")

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id1"))
    assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
  end

  @tag :capture_log
  test "fails if no option was provided" do
    assert_raise(RuntimeError, ~r/No url set for fetching JWKS!/, fn ->
      TestToken.Strategy.start_link([])
    end)
  end

  @tag :capture_log
  test "can configure window of time for searching for new signers" do
    setup_jwks(500)

    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
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

  @tag :capture_log
  test "fetches only one per window of time invariably" do
    setup_jwks(2_000)

    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
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

  @tag :capture_log
  test "fails if no signers are fetched" do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1")]}, status: 500)}
    end)

    TestToken.Strategy.start_link(jwks_url: "http://jwks")
    :timer.sleep(100)

    token = TestToken.generate_and_sign!(%{}, TestUtils.create_signer_with_kid("id3"))
    assert {:error, :no_signers_fetched} == TestToken.verify_and_validate(token)
  end

  test "can skip start polling and fetching" do
    # expect 0 invocations
    expect(TeslaAdaterMock, :call, 0, fn _, _opts -> :ok end)
    TestToken.Strategy.start_link(jwks_url: "http://jwks", should_start: false)
    assert TestToken.Strategy.EtsCache.check_state() == 0
  end

  test "can set log_level to none" do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    log =
      capture_log(fn ->
        TestToken.Strategy.start_link(jwks_url: "http://jwks", log_level: :none)
        :timer.sleep(100)
      end)

    assert not String.contains?(log, "Fetched signers. ")
  end

  test "can set log_level to error and skip debug messages" do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    log =
      capture_log(fn ->
        TestToken.Strategy.start_link(jwks_url: "http://jwks", log_level: :error)
        :timer.sleep(100)
      end)

    # debug message not shown
    assert not String.contains?(log, "Fetched signers. ")
  end

  test "can set log_level to error and see error messages" do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks/500"}, _opts ->
      {:ok, json(%{}, status: 500)}
    end)

    log =
      capture_log(fn ->
        TestToken.Strategy.start_link(jwks_url: "http://jwks/500", log_level: :error)
        :timer.sleep(100)
      end)

    assert log =~ "Failed to fetch signers."
  end

  @tag :capture_log
  test "can set options on callback init_opts/1" do
    defmodule InitOptsToken do
      use Joken.Config

      defmodule Strategy do
        use JokenJwks.DefaultStrategyTemplate

        @doc false
        def init_opts(other_opts) do
          assert other_opts == [log_level: :none]

          # override and add option
          [log_level: :debug, jwks_url: "http://jwks"]
        end
      end

      add_hook(JokenJwks, strategy: Strategy)

      def token_config, do: %{}
    end

    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    InitOptsToken.Strategy.start_link(log_level: :none)
    :timer.sleep(100)

    assert InitOptsToken.Strategy.EtsCache.get_signers()[:signers] |> Map.keys() == ["id1", "id2"]
  end

  def setup_jwks(time_interval \\ 1_000) do
    expect(TeslaAdaterMock, :call, fn %{url: "http://jwks"}, _opts ->
      {:ok, json(%{"keys" => [TestUtils.build_key("id1"), TestUtils.build_key("id2")]})}
    end)

    TestToken.Strategy.start_link(
      jwks_url: "http://jwks",
      time_interval: time_interval
    )

    :timer.sleep(100)
  end
end

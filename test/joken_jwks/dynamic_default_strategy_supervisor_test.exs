defmodule JokenJwks.DynamicDefaultStrategySupervisorTest do
  use ExUnit.Case
  import Mox
  import Tesla.Mock, only: [json: 1, json: 2]
  alias JokenJwks.DynamicDefaultStrategySupervisor
  alias JokenJwks.DynamicDefaultStrategyRegistry
  alias JokenJwks.TestUtils

  setup :set_mox_from_context
  setup :verify_on_exit!

  defp setup_jwks(
         num_of_call_invocations \\ 1,
         url \\ "http://jwks",
         key1 \\ "id1",
         key2 \\ "id2"
       ) do
    ref =
      expect_call(num_of_call_invocations, fn %{url: ^url} ->
        {:ok, json(%{"keys" => [TestUtils.build_key(key1), TestUtils.build_key(key2)]})}
      end)

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
  end

  test "should create child with naming done with Registry" do
    ref1 = setup_jwks()
    ref2 = setup_jwks(1, "http://some/other/jwks")

    child_spec_list = [
      DynamicDefaultStrategyRegistry,
      DynamicDefaultStrategySupervisor
    ]

    _started_children =
      for child <- child_spec_list do
        start_supervised(child)
      end

    opts1 = [
      jwks_url: "http://jwks",
      strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :tenant_x_jwks_strategy}}
    ]

    opts2 = [
      jwks_url: "http://some/other/jwks",
      strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :tenant_y_jwks_strategy}}
    ]

    {:ok, _pid1} = DynamicDefaultStrategySupervisor.start_strategy(opts1)

    {:ok, _pid2} = DynamicDefaultStrategySupervisor.start_strategy(opts2)

    wait_until_jwks_call_done(ref1)
    wait_until_jwks_call_done(ref2)
  end

  describe "functional spot tests - from tests in JokenJwks.DefaultStrategyTest" do
    setup do
      # setup is starting two dynamically set strategies
      child_spec_list = [
        DynamicDefaultStrategyRegistry,
        DynamicDefaultStrategySupervisor
      ]

      _started_children =
        for child <- child_spec_list do
          start_supervised(child)
        end

      jwks1_key1 = "id1"
      jwks1_key2 = "id2"
      jwks1_url = "http://jwks/one"
      jwks2_key1 = "id3"
      jwks2_key2 = "id4"
      jwks2_url = "http://jwks/two"
      ref1 = setup_jwks(1, jwks1_url, jwks1_key1, jwks1_key2)
      ref2 = setup_jwks(1, jwks2_url, jwks2_key1, jwks2_key2)

      opts1 = [
        jwks_url: jwks1_url,
        strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :tenant_1_jwks_strategy}}
      ]

      opts2 = [
        jwks_url: jwks2_url,
        strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :tenant_2_jwks_strategy}}
      ]

      {:ok, pid1} = DynamicDefaultStrategySupervisor.start_strategy(opts1)
      {:ok, pid2} = DynamicDefaultStrategySupervisor.start_strategy(opts2)

      [
        strategy1_pid: pid1,
        strategy2_pid: pid2,
        ref1: ref1,
        ref2: ref2,
        jwks1_key1: jwks1_key1,
        jwks1_key2: jwks1_key2,
        jwks2_key1: jwks2_key1,
        jwks2_key2: jwks2_key2,
        jwks1_url: jwks1_url,
        jwks2_url: jwks2_url
      ]
    end

    defmodule TestTokenOne do
      use Joken.Config

      # We can't use add_hook() for dynamically generated strategies because they are runtime based, and add_hook is compile time
      @impl true
      def before_verify(hook_options, {_token, _signer} = config_tuple) do
        strategy_pid =
          JokenJwks.DynamicDefaultStrategyRegistry.lookup_by_name!(:tenant_1_jwks_strategy)

        strategy = JokenJwks.DynamicDefaultStrategySupervisor.DefaultStrategy

        JokenJwks.before_verify_by_pid(strategy, strategy_pid, hook_options, config_tuple)
      end

      def token_config, do: %{}
    end

    defmodule TestTokenTwo do
      use Joken.Config

      @impl true
      def before_verify(hook_options, {_token, _signer} = config_tuple) do
        strategy_pid =
          JokenJwks.DynamicDefaultStrategyRegistry.lookup_by_name!(:tenant_2_jwks_strategy)

        strategy = JokenJwks.DynamicDefaultStrategySupervisor.DefaultStrategy

        JokenJwks.before_verify_by_pid(strategy, strategy_pid, hook_options, config_tuple)
      end

      def token_config, do: %{}
    end

    defmodule TestTokenDynamic do
      use Joken.Config

      @impl true
      def before_verify(hook_options, {_token, _signer} = config_tuple) do
        strategy_pid =
          hook_options
          |> get_strategy_name()
          |> JokenJwks.DynamicDefaultStrategyRegistry.lookup_by_name!()

        strategy = JokenJwks.DynamicDefaultStrategySupervisor.DefaultStrategy

        JokenJwks.before_verify_by_pid(strategy, strategy_pid, hook_options, config_tuple)
      end

      def token_config, do: %{}

      @spec dynamic_verify_and_validate(atom(), Joken.bearer_token(), Joken.signer_arg(), term) ::
              {:ok, Joken.claims()} | {:error, Joken.error_reason()}
      def dynamic_verify_and_validate(
            strategy_name,
            bearer_token,
            key \\ __default_signer__(),
            context \\ %{}
          )
          when is_atom(strategy_name) do
        opts = [strategy_name: strategy_name]

        hooks = [
          {__MODULE__, opts}
        ]

        Joken.verify_and_validate(token_config(), bearer_token, key, context, hooks)
      end

      defp get_strategy_name(opts), do: opts[:strategy_name]
    end

    test "can fetch keys with token module dynamically passing a strategy", %{
      jwks1_key1: jwks1_key1
    } do
      # shows how you can use a Token module, via `use Joken.Config`, configured for a specific IDP,
      # and then use it with multiple strategies that might use the same claim configuration,
      # but might use each strategy's JWKS url which is unique per strategy.
      # This often occurs when you're creating an auth service for many tenants.
      # Tenant 1/2/3 use JWKS from Auth0 for example, but each tenant has their own JWKS.
      # Tenant 4/5/6 use JWKS from Okta.
      # Tenant 1/2/3 might use a set of token configuration for Auth0, and 4/5/6 uses different one for Okta.
      # When another tenant using Auth0 gets provisioned, without any downtime, you can just:
      #   * DynamicDefaultStrategySupervisor.start_strategy([
      #       jwks_url: "https://jwks/url/for/new/tenant",
      #       strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :new_tenant_strategy_name}}
      #     ])
      #   * And then usage would be: `TokenDynamicForAuth0.dynamic_verify_and_validate(:new_tenant_strategy_name, token)`

      token =
        TestTokenDynamic.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks1_key1))

      assert {:ok, %{}} ==
               TestTokenDynamic.dynamic_verify_and_validate(:tenant_1_jwks_strategy, token)
    end

    # add some of the functionality tests from test/default_strategy_template_test.exs
    test "can fetch keys", %{jwks1_key1: jwks1_key1, jwks2_key1: jwks2_key1} do
      # test for token one
      token = TestTokenOne.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks1_key1))
      assert {:ok, %{}} == TestTokenOne.verify_and_validate(token)

      # test for token two
      token = TestTokenTwo.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks2_key1))
      assert {:ok, %{}} == TestTokenTwo.verify_and_validate(token)

      # negative test - wrong token
      token = TestTokenTwo.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks2_key1))
      refute {:ok, %{}} == TestTokenOne.verify_and_validate(token)
    end

    test "can invalidate wrong keys", %{jwks1_key1: jwks1_key1} do
      # test for token one
      token = TestTokenOne.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks1_key1))

      refute {:ok, %{}} == TestTokenTwo.verify_and_validate(token)
    end

    test "fails if no signers are fetched", %{
      jwks1_url: jwks1_url,
      jwks1_key1: jwks1_key1
    } do
      expect_call(fn %{url: ^jwks1_url} ->
        {:ok, json(%{"keys" => [TestUtils.build_key(jwks1_key1)]}, status: 500)}
      end)

      # trigger a crash to make DynamicDefaultStrategySupervisor restart the strategy to get the 500 response processed
      strategy_pid =
        JokenJwks.DynamicDefaultStrategyRegistry.lookup_by_name!(:tenant_1_jwks_strategy)

      Process.exit(strategy_pid, :something_funky)

      Process.sleep(100)

      token = TestTokenOne.generate_and_sign!(%{}, TestUtils.create_signer_with_kid(jwks1_key1))
      assert {:error, :no_signers_fetched} == TestTokenOne.verify_and_validate(token)
    end
  end
end

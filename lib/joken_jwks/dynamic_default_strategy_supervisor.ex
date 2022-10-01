defmodule JokenJwks.DynamicDefaultStrategySupervisor do
  @moduledoc """
  Dynamic Supervisor for dynamically creating strategies.
  This is to be used with `JokenJwks.DynamicDefaultStrategyRegistry`

  ## Where is this used?
  This is needed when you're creating an auth service for many tenants.
  Say you are creating a SaaS for B2B, and tenants need to use their JWKS url.
  But certain set of tenants belong to one IdP, and some with another IdP.

  Addition to this scenario is that whenever a new tenant provisions, a new strategy can be brought up
  for the tenant, and it be use the Token configuration set for the IdP.
    - If a new Token (via `use Joken.Config`) configuration is needed, that needs to be created
      at compile time.
    - See the test file for how to create a Token module which can work with dynamically supervised strategies

  Tenant 1/2/3 use JWKS from Auth0 for example, but each tenant has their own JWKS.
  Tenant 4/5/6 use JWKS from Okta.
  Tenant 1/2/3 might use a set of token configuration for Auth0, and 4/5/6 uses different one for Okta.
  When another tenant using Auth0 gets provisioned, without any downtime, you can just:

  * DynamicDefaultStrategySupervisor.start_strategy([
      jwks_url: "https://jwks/url/for/new/tenant",
      strategy_name: {:via, Registry, {DynamicDefaultStrategyRegistry, :new_tenant_strategy_name}}
    ])
  * And then usage would be: `TokenDynamicForAuth0.dynamic_verify_and_validate(:new_tenant_strategy_name, token)`

  ## Example of adding it at the application supervisor level
  ```
  defmodule MyApplication do
    use Application
    def start(_type, _args) do
      children = [
        ...,
        JokenJwks.DynamicDefaultStrategyRegistry,
        JokenJwks.DynamicDefaultStrategySupervisor
        ...
      ]

      opts = [strategy: :one_for_one, name: MySupervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```

  Please see the tests in `dynamic_default_strategy_supervisor_test.exs` for usage.
  """
  use DynamicSupervisor
  alias JokenJwks.DynamicDefaultStrategySupervisor.DefaultStrategy

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a child strategy built using DefaultStrategy
  """
  def start_strategy(opts) do
    child_spec = %{
      id: DefaultStrategy,
      start: {DefaultStrategy, :start_link, [opts]}
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def list_strategy_pids() do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.reduce([], fn {_, pid, _, _}, acc ->
      [pid | acc]
    end)
  end

  defmodule DefaultStrategy do
    use JokenJwks.DefaultStrategyTemplate
  end
end

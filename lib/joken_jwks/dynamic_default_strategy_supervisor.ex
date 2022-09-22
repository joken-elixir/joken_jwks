defmodule JokenJwks.DynamicDefaultStrategySupervisor do
  @moduledoc """
  Dynamic Supervisor for dynamically creating strategies

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
      start: {DefaultStrategy, :start_link, opts}
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

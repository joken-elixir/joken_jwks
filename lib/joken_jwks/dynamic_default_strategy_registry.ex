defmodule JokenJwks.DynamicDefaultStrategyRegistry do
  @moduledoc """
  Registry for mapping dynamically created strategies.
  Mainly used for lookup with pid or name of GenServer.
  """

  @doc """
  Child spec creation. This way you can add this registry at `application.ex`:

  ## Example
  ```
  defmodule MyApplication do
    use Application
    def start(_type, _args) do
      children = [
        ...,
        JokenJwks.DynamicDefaultStrategyRegistry,
        ...
      ]

      opts = [strategy: :one_for_one, name: MySupervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```
  """
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_opts \\ []) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__,
      partitions: System.schedulers_online()
    )
  end

  @doc """
  Look up Strategy pid by name
  """
  @spec lookup_by_name(atom()) :: {:error, :not_found} | {:ok, pid()}
  def lookup_by_name(name) do
    case Registry.lookup(__MODULE__, name) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Look up Strategy pid by name and just return the pid. Raise if not found.
  """
  @spec lookup_by_name!(atom()) :: pid()
  def lookup_by_name!(name) do
    {:ok, pid} = lookup_by_name(name)

    pid
  end

  @doc """
  Look up assigned name by pid. Assume one name assigned per pid.
  """
  @spec lookup_by_name(pid()) :: nil | atom()
  def lookup_name_by_pid(pid) do
    Process.whereis(__MODULE__)
    |> case do
      nil -> nil
      _ -> Registry.keys(__MODULE__, pid) |> List.first()
    end
  end
end

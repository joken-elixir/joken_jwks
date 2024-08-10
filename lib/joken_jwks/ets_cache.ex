defmodule JokenJwks.DefaultStrategyTemplate.EtsCache do
  @moduledoc "Simple ETS counter based state machine"

  @doc "Starts ETS cache - will only create if table doesn't exist already"
  def new(module) do
    case :ets.whereis(name(module)) do
      :undefined ->
        :ets.new(name(module), [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true
        ])

        :ets.insert(name(module), {:counter, 0})

      _ ->
        true
    end
  end

  @doc "Returns 0 - no need to fetch signers or 1 - need to fetch"
  def check_state(module) do
    :ets.lookup_element(name(module), :counter, 2)
  end

  @doc "Sets the cache status"
  def set_status(module, :refresh) do
    :ets.update_counter(name(module), :counter, {2, 1, 1, 1}, {:counter, 0})
  end

  def set_status(module, :ok) do
    :ets.update_counter(name(module), :counter, {2, -1, 1, 0}, {:counter, 0})
  end

  @doc "Loads fetched signers"
  def get_signers(module) do
    :ets.lookup(name(module), :signers)
  end

  @doc "Puts fetched signers"
  def put_signers(module, signers) do
    :ets.insert(name(module), {:signers, signers})
  end

  defp name(name), do: :"#{name}.EtsCache"
end

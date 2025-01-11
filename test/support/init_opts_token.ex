defmodule InitOptsToken do
  @moduledoc false
  use Joken.Config

  defmodule Strategy do
    @moduledoc false
    use JokenJwks.DefaultStrategyTemplate

    @doc false
    def init_opts(_other_opts) do
      # override options
      [jwks_url: "http://jwks", first_fetch_sync: true]
    end
  end

  add_hook(JokenJwks, strategy: Strategy)

  def token_config, do: %{}
end

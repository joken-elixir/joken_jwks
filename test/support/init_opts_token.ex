defmodule InitOptsToken do
  use Joken.Config

  defmodule Strategy do
    use JokenJwks.DefaultStrategyTemplate

    @doc false
    def init_opts(_other_opts) do
      # override options
      [jwks_url: "http://jwks"]
    end
  end

  add_hook(JokenJwks, strategy: Strategy)

  def token_config, do: %{}
end

defmodule TestToken do
  use Joken.Config

  defmodule Strategy do
    use JokenJwks.DefaultStrategyTemplate
  end

  add_hook(JokenJwks, strategy: Strategy)

  def token_config, do: %{}
end

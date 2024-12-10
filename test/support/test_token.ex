defmodule TestToken do
  @moduledoc false

  use Joken.Config

  defmodule Strategy do
    @moduledoc false

    use JokenJwks.DefaultStrategyTemplate
  end

  add_hook(JokenJwks, strategy: Strategy)

  def token_config, do: %{}
end

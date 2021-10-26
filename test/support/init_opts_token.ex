defmodule InitOptsToken do
  use Joken.Config

  import ExUnit.Assertions

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

use Mix.Config

config :tesla, JokenJwks.HttpFetcher, adapter: Tesla.Adapter.Hackney

if Mix.env() == :test do
  config :ex_unit, capture_log: true
end

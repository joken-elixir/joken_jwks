import Config

config :tesla, JokenJwks.HttpFetcher, adapter: Tesla.Adapter.Hackney

if config_env() == :test do
  config :ex_unit, capture_log: true
end

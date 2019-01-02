ExUnit.start()

Mox.defmock(TeslaAdaterMock, for: Tesla.Adapter)
Application.put_env(:tesla, JokenJwks.HttpFetcher, adapter: TeslaAdaterMock)

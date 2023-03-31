defmodule JokenJwks.IntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :external

  @google_certs_url "https://www.googleapis.com/oauth2/v3/certs"
  @microsoft_certs_url "https://login.microsoftonline.com/common/discovery/v2.0/keys"

  defmodule Strategy do
    use JokenJwks.DefaultStrategyTemplate
  end

  @tag :capture_log
  test "can parse Google's JWKS" do
    Strategy.start_link(
      jwks_url: @google_certs_url,
      http_adapter: Tesla.Adapter.Hackney,
      first_fetch_sync: true
    )

    assert signers = Strategy.EtsCache.get_signers()
    assert Enum.count(signers) >= 1
  end

  @tag :capture_log
  test "can parse Microsoft's JWKS" do
    Strategy.start_link(
      jwks_url: @microsoft_certs_url,
      http_adapter: Tesla.Adapter.Hackney,
      first_fetch_sync: true,
      explicit_alg: "RS256"
    )

    assert signers = Strategy.EtsCache.get_signers()
    assert Enum.count(signers) >= 1
  end
end

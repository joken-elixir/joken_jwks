defmodule JokenJwksHookTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  @rsa_private """
  -----BEGIN RSA PRIVATE KEY-----
  MIICWwIBAAKBgQDdlatRjRjogo3WojgGHFHYLugdUWAY9iR3fy4arWNA1KoS8kVw
  33cJibXr8bvwUAUparCwlvdbH6dvEOfou0/gCFQsHUfQrSDv+MuSUMAe8jzKE4qW
  +jK+xQU9a03GUnKHkkle+Q0pX/g6jXZ7r1/xAK5Do2kQ+X5xK9cipRgEKwIDAQAB
  AoGAD+onAtVye4ic7VR7V50DF9bOnwRwNXrARcDhq9LWNRrRGElESYYTQ6EbatXS
  3MCyjjX2eMhu/aF5YhXBwkppwxg+EOmXeh+MzL7Zh284OuPbkglAaGhV9bb6/5Cp
  uGb1esyPbYW+Ty2PC0GSZfIXkXs76jXAu9TOBvD0ybc2YlkCQQDywg2R/7t3Q2OE
  2+yo382CLJdrlSLVROWKwb4tb2PjhY4XAwV8d1vy0RenxTB+K5Mu57uVSTHtrMK0
  GAtFr833AkEA6avx20OHo61Yela/4k5kQDtjEf1N0LfI+BcWZtxsS3jDM3i1Hp0K
  Su5rsCPb8acJo5RO26gGVrfAsDcIXKC+bQJAZZ2XIpsitLyPpuiMOvBbzPavd4gY
  6Z8KWrfYzJoI/Q9FuBo6rKwl4BFoToD7WIUS+hpkagwWiz+6zLoX1dbOZwJACmH5
  fSSjAkLRi54PKJ8TFUeOP15h9sQzydI8zJU+upvDEKZsZc/UhT/SySDOxQ4G/523
  Y0sz/OZtSWcol/UMgQJALesy++GdvoIDLfJX5GBQpuFgFenRiRDabxrE9MNUZ2aP
  FaFp+DyAe+b4nDwuJaW2LURbr8AEZga7oQj0uYxcYw==
  -----END RSA PRIVATE KEY-----
  """

  defmodule TestToken do
    use Joken.Config

    add_hook(JokenJwks, jwks_url: "http://jwks")

    def token_config, do: %{}
  end

  setup do
    Cachex.clear(:joken_jwks_cache)

    mock(fn
      %{method: :get, url: "http://jwks"} ->
        json(%{"keys" => [build_key("id1"), build_key("id2")]})

      %{method: :get, url: "http://jwks/500"} ->
        %Tesla.Env{status: 500}
    end)

    :ok
  end

  test "can fetch keys" do
    token = TestToken.generate_and_sign!(%{}, create_signer_with_kid("id2"))
    assert {:ok, %{}} == TestToken.verify_and_validate(token)
  end

  test "fails if kid does not match" do
    token = TestToken.generate_and_sign!(%{}, create_signer_with_kid("id3"))
    assert {:error, :kid_does_not_match} == TestToken.verify_and_validate(token)
  end

  @tag :capture_log
  test "fails if it can't fetch" do
    defmodule Server500 do
      use Joken.Config

      add_hook(JokenJwks, jwks_url: "http://jwks/500")

      def token_config, do: %{}
    end

    token = Server500.generate_and_sign!(%{}, create_signer_with_kid("id1"))

    assert {:error, :jwks_server_http_error} == Server500.verify_and_validate(token)
  end

  test "fails if no option was provided" do
    defmodule NoJwksUrl do
      use Joken.Config

      add_hook(JokenJwks)

      def token_config, do: %{}
    end

    assert_raise(JokenJwks.Error, ~r/No option `jwks_url` was passed./, fn ->
      NoJwksUrl.verify_and_validate("")
    end)
  end

  defp build_key(kid) do
    %{
      "kid" => kid,
      "kty" => "RSA",
      "alg" => "RS512",
      "e" => "AQAB",
      "n" =>
        "3ZWrUY0Y6IKN1qI4BhxR2C7oHVFgGPYkd38uGq1jQNSqEvJFcN93CYm16_G78FAFKWqwsJb3Wx-nbxDn6LtP4AhULB1H0K0g7_jLklDAHvI8yhOKlvoyvsUFPWtNxlJyh5JJXvkNKV_4Oo12e69f8QCuQ6NpEPl-cSvXIqUYBCs"
    }
  end

  defp create_signer_with_kid(kid) do
    jwk =
      @rsa_private
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_map()
      |> elem(1)
      |> Map.put("kid", kid)
      |> JOSE.JWK.to_map()

    jws = JOSE.JWS.from_map(%{"typ" => "JWT", "kid" => kid, "alg" => "RS512"})
    %Joken.Signer{alg: "RS512", jwk: jwk, jws: jws}
  end
end

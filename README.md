# Joken JWKS

[![Build](https://travis-ci.org/joken-elixir/joken_jwks.svg?branch=master)](https://travis-ci.org/joken-elixir/joken_jwks)
[![Module Version](https://img.shields.io/hexpm/v/joken_jwks.svg)](https://hex.pm/packages/joken_jwks)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/joken_jwks/)
[![Total Download](https://img.shields.io/hexpm/dt/joken_jwks.svg)](https://hex.pm/packages/joken_jwks)
[![License](https://img.shields.io/hexpm/l/joken_jwks.svg)](https://github.com/joken-elixir/joken_jwks/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/joken-elixir/joken_jwks.svg)](https://github.com/joken-elixir/joken_jwks/commits/master)

A `Joken.Hooks` implementation that builds a signer out of a JWKS url for verification.

## Usage

Please see our [documentation](https://hexdocs.pm/joken_jwks/) for usage.

## Installation

```elixir
def deps do
  [
    {:joken_jwks, "~> 1.1.0"}
  ]
end
```

# JWKS (JSON Web Key Set)

When using JWTs for digital signing we need a key to sign and verify the contents of the token. Many times the part that is doing signature verification is the same that does the signing and so, it possesses both the private and public key. Other times, this is not the case.

When using an authentication server that is different than the "business" server, the later has no control about the keys being used to authenticate a request. On these cases, the authentication server publishes its own public key so that anyone can validate tokens that it has generated before with the matching private key.

This scenario is common on delegated authentication as mentioned. One specification that uses this approach is OAuth2 with OpenID Connect. The auth server has a public configuration endpoint where there is plenty information about how to connect with the server. One such information is the JWKS (JSON Web Key Set): a list of public keys the server uses to generate signed tokens.

Example of well known JWKS URIs:

- Google: https://www.googleapis.com/oauth2/v3/certs
- Microsoft: https://login.microsoftonline.com/common/discovery/keys

## Joken JWKS hook

If your server is using Joken 2 to validate tokens, then you can use this hook to retrieve the list of signers from a JWKS URI. This is how it happens:

1. Build you token configuration (either with `use Joken.Config` or directly)
2. Initialize your fetching strategy
3. Pass this hook to your verify call:
   - If you are using `Joken.Config` then it's just a matter of `add_hook(JokenJwks, strategy: <<YOUR STRATEGY>>)`
   - If you are calling `Joken.verify_*` directly, you can pass the hook as a last parameter

**Remember** that there can't be a default signer otherwise it will have precedence over this!

## Architecture

This hook will call the behaviour `JokenJwks.SignerMatchstrategy` for every token. It is the implementation job to decide how to choose a signer for the token.

The only occasion where this will not call the behaviour is if the given token is not properly formed nor it contains a "kid" claim on its header. JWKS mandates this claim so that we know which key to use for verifying.

A very naive approach of implementing the callback would be to fetch signers upon startup and then re-fetching every time a token kid does not match with the loaded cache.

This could potentially open an attack vector for massively hitting the authentication server. Of course, the auth server JWKS url is public and an attacker could just hit it directly, but it is wise to have some defense mechanism in place when developing your strategy.

## Default Strategy Template

`JokenJwks` comes with a smart enough implementation that uses a time window approach for re-fetching signers. By default, it polls the cache state every minute to see if a bad kid was attempted. If so, it re-fetches the cache. So, it will fetch JWKS once every minute tops.

## Interpretation of the JWKS RFC

Since the JWKS specification is just that, a specification, many servers might disagree on how to implement this. For example, Google specifies the "alg" claim on every key instance. Microsoft does not. Therefore we assume some interpretations:

- Every key must have a "kid" (even if there is only one key)
- We don't currently check for the "use" claim and so we might hit an encryption key (which will be parsed as well)
- If no "alg" claim is provided, then the user must pass the option "explicit_alg"

That's it for now :)

## Copyright and License

Copyright (c) 2018 Victor Nascimento

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

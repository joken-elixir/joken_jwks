# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### BREAKING CHANGES

- No more custom logging (use Logger facilities)

If you need to disable specific logging from the library, you can use default `Logger` facilities like `Logger.put_application_level/2` (which accepts `:none`) and so on. There is no need to use custom logging here anymore.

- No more custom telemetry (use Teslas built-in)

Tesla has its own middleware for telemetry events. We should just use that :) 

## [1.6.0] - 2021-10-26

This release brings a more resilient parsing of JWK sets. If the provider has encryption keys along with signing keys, we skip them.

Also, since JWS specification has some algorithms that are not natively available to all installations (Edwards curves for example) we also skip those. This aims to avoid a server not loading other keys if one is not supported.

### Changed

- Update Hackney spec to include 1.18 versions (thanks to @J3RN)
- Add patch level to 1.18 spec (thanks to @J3RN)
- More resilient parsing of JWKs (#28)

## [1.5.0] - 2020-12-23

### Changed

- Use hackney v1.17.4
- Documentation re-organization (#22 thanks to @kianmeng)
- Conditional telemetry version (#23 thanks to @J3RN)

## [1.4.0] - 2020-09-27

### Changed

- (Emil Bostijancic) upgrades hackney dependency to 1.16.0 (#17)
- Updated deps

### Fixed

- (@seancribbs) Address unmatched return warnings from Dialyzer (#16)

## [1.3.1] - 2020-03-02

### Fixed

- (@duzzifelipe) #13 fix: change fetch signers spec

## [1.3.0] - 2020-03-02

### Added

- (@duzzifelipe) #12 feat: telemetry middleware for tesla

## [1.2.0] - 2019-11-08

### Added

- (René Mygind Andersen) #7 Adds support for parsing JWKS returned with content-type 'applicat…

### Changed

- (@ltj) Use hackney v1.15.2

## [1.1.0] - 2019-03-05

### Added

- Options for explicitly telling which algorithm will use for the parsed signers;
- HTTP options for retry and adapter;
- Integration tests for Google and Microsoft JWKS endpoints.

### Fixed

- Fixed docs about how to use DefaultStrategyTemplate and Fixed spelling (#4 thanks to @bforchhammer)

## [1.0.0] - 2019-01-02

### Added

- First version of the library with a default time window strategy for refetching signers.


# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2020-12-23

### Changed

- Use hackney v1.17.0

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


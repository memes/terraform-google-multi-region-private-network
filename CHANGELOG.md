# Changelog

## [3.1.1](https://github.com/memes/terraform-google-multi-region-private-network/compare/v3.1.0...v3.1.1) (2025-03-21)


### Bug Fixes

* Include gateway_address in subnet details. ([637571e](https://github.com/memes/terraform-google-multi-region-private-network/commit/637571e3a1dbd9b88ba533f8e0cd3126402a0671))
* Include gateway_address in subnet details. ([66effc4](https://github.com/memes/terraform-google-multi-region-private-network/commit/66effc48939af0c0db0f57f71427e6ba81b6c352)), closes [#83](https://github.com/memes/terraform-google-multi-region-private-network/issues/83)

## [3.1.0](https://github.com/memes/terraform-google-multi-region-private-network/compare/v3.0.0...v3.1.0) (2025-01-24)


### Features

* Add resource id to output ([156f1f7](https://github.com/memes/terraform-google-multi-region-private-network/commit/156f1f7ed0a8446f996572ecf7eaa47e1984751a))

## [3.0.0](https://github.com/memes/terraform-google-multi-region-private-network/compare/v2.1.0...v3.0.0) (2024-05-03)


### ⚠ BREAKING CHANGES

* Support subnet offsets and steps

### Features

* Support subnet offsets and steps ([84fe4dc](https://github.com/memes/terraform-google-multi-region-private-network/commit/84fe4dcfc6ac84ade83db286df890ffd241e9673))

## [2.1.0](https://github.com/memes/terraform-google-multi-region-private-network/compare/v2.0.0...v2.1.0) (2023-12-07)


### Features

* Support Private Google APIs access ([779cc5b](https://github.com/memes/terraform-google-multi-region-private-network/commit/779cc5b5891677f28d366938b58d6a9106bc7edd)), closes [#46](https://github.com/memes/terraform-google-multi-region-private-network/issues/46)

## [2.0.0](https://github.com/memes/terraform-google-multi-region-private-network/compare/v1.0.2...v2.0.0) (2023-03-17)


### ⚠ BREAKING CHANGES

* Inputs and outputs have changed for consistent nameing of IPv4 and IPv6 resources.
* Support for arbitrary routes has been removed from module

### Features

* Initial support for IPv6 ([49c70a6](https://github.com/memes/terraform-google-multi-region-private-network/commit/49c70a6d947d55fa98b1668fe29b1ff595066a7c))
* Remove Google network and NAT modules ([ac0431e](https://github.com/memes/terraform-google-multi-region-private-network/commit/ac0431e767122adca007f109df70999402e19327))

## [1.0.2](https://github.com/memes/terraform-google-multi-region-private-network/compare/v1.0.1...v1.0.2) (2023-03-06)


### Bug Fixes

* Add `subnets_by_region` output to module ([40ceb96](https://github.com/memes/terraform-google-multi-region-private-network/commit/40ceb96643c98cccf1d8d1599b4e09a48129262c))

## [1.0.1](https://github.com/memes/terraform-google-multi-region-private-network/compare/v1.0.0...v1.0.1) (2023-02-13)


### Bug Fixes

* Change subnets output to be keyed by name ([4562272](https://github.com/memes/terraform-google-multi-region-private-network/commit/456227261aa91ae95e3a3d7434f83d4e4615e543))

## 1.0.0 (2023-02-13)


### Features

* Multi-region private VPC module ([f98f7f4](https://github.com/memes/terraform-google-multi-region-private-network/commit/f98f7f429f2f6c6fd674cdf5565a051c5e1448b5))

## Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

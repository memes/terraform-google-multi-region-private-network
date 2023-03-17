# Changelog

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

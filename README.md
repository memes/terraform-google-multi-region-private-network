# Multi-region VPC network module

![GitHub release](https://img.shields.io/github/v/release/memes/terraform-google-multi-region-private-network?sort=semver)
![Maintenance](https://img.shields.io/maintenance/yes/2023)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

This Terraform module creates a private global VPC network with subnets in the
specified regions, with each subnet receiving a CIDR of specified size. Unless
the default configuration is changed, this module will create a VPC network with
the following properties:

* A subnet defined in each region specified, with primary and secondary ranges
  sectioned from a common CIDR
* Private by default
  * Default route to internet (0.0.0.0/0) is deleted
  * Private Google API access is enabled in each subnet
  * Private connectivity route is added to support VPC Service Controls
    > NOTE: DNS is not managed by this module; see [restricted-apis-dns]

> NOTE: The intent of this module is to easily repeat common VPC network patterns
> I use to deploy in Google Cloud; it is not a general purpose VPC network creation
> tool. Use Google's [network] module for that purpose.

## Examples

### East-west dual region private VPC network

|Item|Managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary CIDR|&check;|`172.16.x.0/12`, split into a `/24` per region|
|Secondary CIDRs|&check;|None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet unless a custom route is added|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Additional Routes|&check;|None added|
|MTU|&check;|1460|
|Cloud NAT|&check;|Not enabled|
|Restricted Google API DNS zone(s)||Not managed by this module; see [restricted-apis-dns]|
|Bastion||Not managed by this module; see [private-bastion]|

```hcl
module "vpc" {
    source = "memes/multi-region-private-network/google"
    version = "1.0.0"
    project_id = "my-project-id"
    name = "internal-us"
    regions = ["us-east1", "us-west1"]
}
```

### East-west dual region with secondary ranges for GKE

<!-- markdownlint-disable MD033 MD034-->
|Item|Managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary CIDR|&check;|`172.16.x.0/24` per region|
|Secondary CIDRs|&check;|&bullet; `pods` CIDR `10.x.0.0/16` per region<br/>&bullet; `services` CIDR `10.100.x.0/24` per region|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet unless a custom route is added|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Additional Routes|&check;|None added|
|MTU|&check;|1460|
|Cloud NAT|&check;|Not enabled|
|Restricted Google API DNS zone(s)||Not managed by this module; see [restricted-apis-dns]|
|Bastion||Not managed by this module; see [private-bastion]|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "1.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    cidrs      = {
        primary_cidr        = "172.16.0.0/12"
        primary_subnet_size = 24
        secondary_ranges    = [
            {
                name        = "pods"
                cidr        = "10.0.0.0/8"
                subnet_size = 16
            },
            {
                name        = "services"
                cidr        = "10.100.0.0/16"
                subnet_size = 24
            },
        ]
    }
}
```

### East-west dual region with Cloud NAT

<!-- markdownlint-disable MD033 MD034-->
|Item|Managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary CIDR|&check;|`172.16.x.0/24` per region|
|Secondary CIDRs|&check;|None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Not deleted - Cloud NAT requires a default internet route be in place|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Additional Routes|&check;|None added|
|MTU|&check;|1460|
|Cloud NAT|&check;|A Cloud Router and Cloud NAT will be created in each region|
|Restricted Google API DNS zone(s)||Not managed by this module; see [restricted-apis-dns]|
|Bastion||Not managed by this module; see [private-bastion]|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "1.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    options    = {
        mtu                   = 1460
        delete_default_routes = false
        restricted_apis       = true
        routing_mode          = "GLOBAL"
        nat                   = true
    }
}
```

<!-- markdownlint-disable MD033 MD034-->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.42 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_nat"></a> [nat](#module\_nat) | terraform-google-modules/cloud-router/google | 4.0.0 |
| <a name="module_network"></a> [network](#module\_network) | terraform-google-modules/network/google | 6.0.1 |
| <a name="module_regions"></a> [regions](#module\_regions) | memes/region-detail/google | 1.0.1 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the VPC network will be created. | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | The list of Compute Engine regions in which to create the VPC subnetworks. | `list(string)` | n/a | yes |
| <a name="input_cidrs"></a> [cidrs](#input\_cidrs) | Sets the primary CIDR and regional subnet size to use with the network, and any<br>optional secondary CIDRs and sizes. | <pre>object({<br>    primary             = string<br>    primary_subnet_size = number<br>    secondaries = map(object({<br>      cidr        = string<br>      subnet_size = number<br>    }))<br>  })</pre> | <pre>{<br>  "primary": "172.16.0.0/12",<br>  "primary_subnet_size": 24,<br>  "secondaries": {}<br>}</pre> | no |
| <a name="input_description"></a> [description](#input\_description) | A descriptive value to apply to the VPC network. Default value is 'custom vpc'. | `string` | `"custom vpc"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name to use when naming resources managed by this module. Must be RFC1035<br>compliant and between 1 and 55 characters in length, inclusive. | `string` | `"restricted"` | no |
| <a name="input_options"></a> [options](#input\_options) | The set of options to use when creating the VPC network. | <pre>object({<br>    mtu                   = number<br>    delete_default_routes = bool<br>    restricted_apis       = bool<br>    routing_mode          = string<br>    nat                   = bool<br>    nat_tags              = set(string)<br>    flow_logs             = bool<br>  })</pre> | <pre>{<br>  "delete_default_routes": true,<br>  "flow_logs": false,<br>  "mtu": 1460,<br>  "nat": false,<br>  "nat_tags": null,<br>  "restricted_apis": true,<br>  "routing_mode": "GLOBAL"<br>}</pre> | no |
| <a name="input_routes"></a> [routes](#input\_routes) | An optional set of routes to add to the VPC network. Format is the same as the<br>`routes` variable for Google's network module. | `list(map(string))` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The fully-qualified self-link URI of the created VPC network. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | A map of subnet name to region, self\_link, and CIDRs. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable MD033 MD034 -->

[network]: https://registry.terraform.io/modules/terraform-google-modules/network/google/latest?tab=readme
[restricted-apis-dns]: https://registry.terraform.io/modules/memes/restricted-apis-dns/google/latest?tab=readme
[private-bastion]: https://registry.terraform.io/modules/memes/private-bastion/google/latest?tab=readme

# Multi-region VPC network module

![GitHub release](https://img.shields.io/github/v/release/memes/terraform-google-multi-region-private-network?sort=semver)
![Maintenance](https://img.shields.io/maintenance/yes/2025)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

This Terraform module creates an opinionated private global VPC network that spans
the regions provided, with each subnet receiving a calculated CIDR of requested
size from the network CIDR.

The default configuration will create a VPC network with the following properties:

* For each region, a `/24` subnet from `172.16.0.0/12`, with no secondary ranges
* Private by default
  * Default route to internet (0.0.0.0/0) is deleted
  * Private Google API access is enabled to support VPC Service Controls
  * Private connectivity route is added to support VPC Service Controls
    > NOTE: Private Cloud DNS zones and bastions are not managed by this module;
    > see [restricted-apis-dns] and [private-bastion] for those.

Optionally, a Cloud NAT gateway can be added to each region to allow for controlled
egress traffic, and IPv6 ULA addressing enabled.

## Opinions

1. The network should be defined as a CIDR; the module will allocate sub-CIDRs to
   regions as needed.
2. The network will be **private** by default
3. Module consumers can override CIDRs, and option flags, but must explicitly set
   all the `cidrs` and/or `options` fields. Nothing is inferred by omission.
4. Firewall rules, additional routes, and other per-application settings should
   not be managed by this module.

> NOTE: The intent of this module is to easily repeat common VPC network patterns
> I use to deploy in Google Cloud; it is not a general purpose VPC network creation
> tool. Use Google's [network] module for that purpose.

## Examples

### East-west dual region private VPC network

|Item|Enabled/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs||None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route||None added|
|MTU|&check;|1460|
|Cloud NAT|||
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    name       = "internal-us"
    regions    = ["us-east1", "us-west1"]
}
```

### East-west dual region private VPC network, with primary subnet offset and steps

|Item|Enabled/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (as `172.16.10.0/16`, `172.16.20.0/16`)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs||None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route||None added|
|MTU|&check;|1460|
|Cloud NAT|||
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    name       = "internal-us"
    regions    = ["us-east1", "us-west1"]
    cidrs      = {
        primary_ipv4_cidr          = "172.16.0.0/12"
        primary_ipv4_subnet_size   = 24
        primary_ipv4_subnet_offset = 10
        primary_ipv4_subnet_step   = 10
        primary_ipv6_cidr          = null
        secondaries = {}
    }
}
```

### East-west dual region with secondary ranges for GKE

<!-- markdownlint-disable MD033 MD034-->
|Item|Enabled/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs|&check;|&bullet; `pods` CIDR `10.x.0.0/16` per region<br/>&bullet; `services` CIDR `10.100.x.0/24` per region|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route||None added|
|MTU|&check;|1460|
|Cloud NAT||Not enabled|
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    cidrs      = {
        primary_ipv4_cidr          = "172.16.0.0/12"
        primary_ipv4_subnet_size   = 24
        primary_ipv4_subnet_offset = 0
        primary_ipv4_subnet_step   = 1
        primary_ipv6_cidr          = null
        secondaries = {
            pods = {
                ipv4_cidr          = "10.0.0.0/8"
                ipv4_subnet_size   = 16
                ipv4_subnet_offset = 0
                ipv4_subnet_step   = 1
            }
            services = {
                ipv4_cidr          = "10.100.0.0/16"
                ipv4_subnet_size   = 24
                ipv4_subnet_offset = 0
                ipv4_subnet_step   = 1
            }
        }
    }
}
```

### East-west dual region with Cloud NAT

<!-- markdownlint-disable MD033 MD034-->
|Item|Managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs||None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Not deleted - Cloud NAT requires a default internet route be in place|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route||None added|
|MTU|&check;|1460|
|Cloud NAT|&check;|A Cloud Router and Cloud NAT will be created in each region|
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    nat = {
        tags           = ["allow-nat"]
        logging_filter = null
    }
}
```

### East-west dual region with auto-allocated IPv6 CIDR

<!-- markdownlint-disable MD033 MD034-->
|Item|Enable/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR|&check;|Auto-allocated `/48` from `fd20::/20` (`/64` per region)|
|Secondary IPv4 CIDRs||None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route||None added|
|MTU|&check;|1460|
|Cloud NAT||Not enabled|
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    options    = {
        mtu                           = 1460
        delete_default_routes         = true
        enable_restricted_apis_access = true
        regional_routing_mode         = false
        ipv6_ula                      = true
    }
}
```

### East-west dual region with explicit IPv6 CIDR

<!-- markdownlint-disable MD033 MD034-->
|Item|Enable/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR|&check;|`fd20:0:0309:0:0:0:0:0/48` (`/64` per region)|
|Secondary IPv4 CIDRs||None added|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|MTU|&check;|1460|
|Cloud NAT||Not enabled|
|*Restricted Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    cidrs      = {
        primary_ipv4_cidr          = "172.16.0.0/12"
        primary_ipv4_subnet_size   = 24
        primary_ipv4_subnet_offset = 0
        primary_ipv4_subnet_step   = 1
        primary_ipv6_cidr          = "fd20:0:0309:0:0:0:0:0/48"
        secondaries                = {}
    }
    options    = {
        mtu                           = 1460
        delete_default_routes         = true
        enable_restricted_apis_access = true
        regional_routing_mode         = false
        ipv6_ula                      = true
    }
}
```

### East-west dual region with Private Google APIs access

<!-- markdownlint-disable MD033 MD034-->
|Item|Enabled/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs||Not enabled|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route||None added|
|Private API route|&check;|A route for private Google API endpoints is added|
|MTU|&check;|1460|
|Cloud NAT||Not enabled|
|*Private Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    cidrs      = {
        primary_ipv4_cidr          = "172.16.0.0/12"
        primary_ipv4_subnet_size   = 24
        primary_ipv4_subnet_offset = 0
        primary_ipv4_subnet_step   = 1
        primary_ipv6_cidr          = null
        secondaries                = {}
    }
    options = {
        mtu                           = 1460
        delete_default_routes         = true
        enable_restricted_apis_access = false
        regional_routing_mode         = false
        ipv6_ula                      = false
    }
}
```

### East-west dual region with Restricted Google APIs access via PSC

<!-- markdownlint-disable MD033 MD034-->
|Item|Enabled/managed by module|Description|
|----|-----------------|-----------|
|Regions|&check;|`us-east1` and `us-west1`|
|Primary IPv4 CIDR|&check;|`172.16.0.0/12` (`/24` per region)|
|Primary IPv6 CIDR||Not enabled|
|Secondary IPv4 CIDRs||Not enabled|
|VPC routing mode|&check;|GLOBAL|
|Default internet route|&check;|Deleted; VPC will not route to internet|
|Restricted API route|&check;|A route for restricted Google API endpoints is added|
|Private API route|&check;|A route for private Google API endpoints is added|
|MTU|&check;|1460|
|Cloud NAT||Not enabled|
|PSC||`10.10.10.10`
|*Restricted and Private Google API DNS zone(s)*||*Not managed by this module; see [restricted-apis-dns]*|
|*Bastion*||*Not managed by this module; see [private-bastion]*|
<!-- markdownlint-enable MD033 MD034-->

```hcl
module "vpc" {
    source     = "memes/multi-region-private-network/google"
    version    = "4.0.0"
    project_id = "my-project-id"
    regions    = ["us-east1", "us-west1"]
    psc        = {
        address           = "10.10.10.10"
        service_directory = null
    }
}
```

<!-- markdownlint-disable MD033 MD034-->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.25 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_regions"></a> [regions](#module\_regions) | memes/region-detail/google | 1.1.6 |

## Resources

| Name | Type |
|------|------|
| [google_compute_global_address.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_network.network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_route.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_route.tagged_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_router.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnet](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the VPC network will be created. | `string` | n/a | yes |
| <a name="input_regions"></a> [regions](#input\_regions) | The list of Compute Engine regions in which to create the VPC subnetworks. | `list(string)` | n/a | yes |
| <a name="input_cidrs"></a> [cidrs](#input\_cidrs) | Sets the primary IPv4 CIDR and regional subnet size to use with the network,<br/>an optional IPv6 ULA CIDR to use with the network, and any optional secondary<br/>IPv4 CIDRs and sizes. | <pre>object({<br/>    primary_ipv4_cidr          = string<br/>    primary_ipv4_subnet_size   = number<br/>    primary_ipv4_subnet_offset = number<br/>    primary_ipv4_subnet_step   = number<br/>    primary_ipv6_cidr          = string<br/>    secondaries = map(object({<br/>      ipv4_cidr          = string<br/>      ipv4_subnet_size   = number<br/>      ipv4_subnet_offset = number<br/>      ipv4_subnet_step   = number<br/>    }))<br/>  })</pre> | <pre>{<br/>  "primary_ipv4_cidr": "172.16.0.0/12",<br/>  "primary_ipv4_subnet_offset": 0,<br/>  "primary_ipv4_subnet_size": 24,<br/>  "primary_ipv4_subnet_step": 1,<br/>  "primary_ipv6_cidr": null,<br/>  "secondaries": {}<br/>}</pre> | no |
| <a name="input_description"></a> [description](#input\_description) | A descriptive value to apply to the VPC network. Default value is 'custom vpc'. | `string` | `"custom vpc"` | no |
| <a name="input_flow_logs"></a> [flow\_logs](#input\_flow\_logs) | If not null, enable flow log collection in Cloud Logging using the provided parameters. If null (default), flow log<br/>collection will be disabled. | <pre>object({<br/>    aggregation_interval = string<br/>    flow_sampling        = number<br/>    metadata             = string<br/>    metadata_fields      = set(string)<br/>    filter_expr          = string<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name to use when naming resources managed by this module. Must be RFC1035<br/>compliant and between 1 and 55 characters in length, inclusive. | `string` | `"restricted"` | no |
| <a name="input_nat"></a> [nat](#input\_nat) | If not null, Cloud NAT instances and supporting Cloud Routers will be added to each subnet along with supporting<br/>routes with tags, if applicable. Log collection is controlled by the presence of a non empty logging\_filter field. | <pre>object({<br/>    tags           = set(string)<br/>    logging_filter = string<br/>  })</pre> | `null` | no |
| <a name="input_options"></a> [options](#input\_options) | The set of options to use when creating the VPC network. The default value will create a VPC network with MTU of 1460,<br/>GLOBAL routing mode, and IPv6 ULA disabled. Default routes (0.0.0.0/0, ::0) to the default gateway are deleted; routes<br/>will be added to support Restricted (default) or Private Google APIs access unless PSC for Google APIs is enabled<br/>through the `psc` variable. | <pre>object({<br/>    mtu                           = number<br/>    delete_default_routes         = bool<br/>    enable_restricted_apis_access = bool<br/>    regional_routing_mode         = bool<br/>    ipv6_ula                      = bool<br/>  })</pre> | <pre>{<br/>  "delete_default_routes": true,<br/>  "enable_restricted_apis_access": true,<br/>  "ipv6_ula": false,<br/>  "mtu": 1460,<br/>  "regional_routing_mode": false<br/>}</pre> | no |
| <a name="input_psc"></a> [psc](#input\_psc) | If set, create a Private Service Connect for Google APIs resource to provide Private or Restricted Google APIs access<br/>via a PSC in the VPC. If a valid service\_directory field is present automatic DNS registration via Service Directory<br/>will be activated. The value of `options.enable_restricted_apis_access` determines if the PSC will be to Restricted<br/>(default) or Private Google APIs bundle. | <pre>object({<br/>    address = string<br/>    service_directory = object({<br/>      namespace = string<br/>      region    = string<br/>    })<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | The qualified id of the created VPC network. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The fully-qualified self-link URI of the created VPC network. |
| <a name="output_subnets_by_name"></a> [subnets\_by\_name](#output\_subnets\_by\_name) | A map of subnet name to region, self\_link, and CIDRs. |
| <a name="output_subnets_by_region"></a> [subnets\_by\_region](#output\_subnets\_by\_region) | A map of subnet region to name, self\_link, and CIDRs. |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable MD033 MD034 -->

[network]: https://registry.terraform.io/modules/terraform-google-modules/network/google/latest?tab=readme
[restricted-apis-dns]: https://registry.terraform.io/modules/memes/restricted-apis-dns/google/latest?tab=readme
[private-bastion]: https://registry.terraform.io/modules/memes/private-bastion/google/latest?tab=readme

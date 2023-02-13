terraform {
  required_version = ">= 1.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.42"
    }
  }
}

locals {
  primary_ranges = cidrsubnets(var.cidrs.primary, [for r in var.regions : var.cidrs.primary_subnet_size - tonumber(split("/", var.cidrs.primary)[1])]...)
  subnets = { for i, region in var.regions :
    format("%s-%s", var.name, module.regions.results[region].abbreviation) => {
      region        = region
      primary_range = local.primary_ranges[i]
      secondary_ranges = var.cidrs.secondaries == null ? [] : [for k, v in var.cidrs.secondaries : {
        range_name    = k
        ip_cidr_range = cidrsubnet(v.cidr, v.subnet_size - tonumber(split("/", v.cidr)[1]), i)
      }]
    }
  }
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.0.1"
  regions = var.regions
}

module "network" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "6.0.1"
  project_id                             = var.project_id
  network_name                           = var.name
  description                            = var.description
  auto_create_subnetworks                = false
  delete_default_internet_gateway_routes = var.options.delete_default_routes
  routing_mode                           = var.options.routing_mode
  mtu                                    = var.options.mtu
  subnets = [for key in keys(local.subnets) :
    {
      subnet_name           = key
      subnet_ip             = local.subnets[key].primary_range
      subnet_region         = local.subnets[key].region
      subnet_private_access = true
      subnet_flow_logs      = var.options.flow_logs
    }
  ]
  secondary_ranges = { for k, v in local.subnets :
    k => v.secondary_ranges
  }
  routes = concat(
    var.options.restricted_apis ? [
      {
        name              = format("%s-restricted-apis", var.name)
        description       = "Route for restricted Google API access"
        destination_range = "199.36.153.4/30"
        next_hop_internet = true
      }
    ] : [],
    var.options.nat && try(length(var.options.nat_tags), 0) > 0 ? [
      {
        priority          = "900"
        name              = format("%s-tagged-nat", var.name)
        description       = "Route to NAT gateway for tagged resources"
        destination_range = "0.0.0.0/0"
        next_hop_internet = true
        tags              = join(",", var.options.nat_tags)
      }
    ] : [],
  var.routes)
}

# If the NAT option is set, create a Cloud Router and Cloud NAT pair in each
# region to provide internet egress.
module "nat" {
  for_each = { for region in var.regions : region => format("%s-%s", var.name, module.regions.results[region].abbreviation) if var.options.nat }
  source   = "terraform-google-modules/cloud-router/google"
  version  = "4.0.0"
  project  = var.project_id
  name     = each.value
  network  = module.network.network_self_link
  region   = each.key

  # Create an opinionated Cloud NAT instance in the region that can be used by
  # all resources attached to the network through primary or alias IP addresses.
  nats = [{
    name                               = each.value
    nat_ip_allocation_option           = "AUTO_ONLY"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
    subnetworks                        = []
  }]
}

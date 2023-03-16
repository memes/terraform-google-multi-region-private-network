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
      region           = region
      primary_range    = local.primary_ranges[i]
      secondary_ranges = var.cidrs.secondaries == null ? {} : { for k, v in var.cidrs.secondaries : k => cidrsubnet(v.cidr, v.subnet_size - tonumber(split("/", v.cidr)[1]), i) }
    }
  }
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.0"
  regions = var.regions
}

resource "google_compute_network" "network" {
  project                         = var.project_id
  name                            = var.name
  description                     = var.description
  auto_create_subnetworks         = false
  routing_mode                    = var.options.routing_mode
  mtu                             = var.options.mtu
  delete_default_routes_on_create = var.options.delete_default_routes
}

resource "google_compute_subnetwork" "subnet" {
  for_each                 = local.subnets
  project                  = var.project_id
  name                     = each.key
  network                  = google_compute_network.network.id
  ip_cidr_range            = each.value.primary_range
  private_ip_google_access = var.options.restricted_apis
  region                   = each.value.region

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = var.options.flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
      filter_expr          = true
    }
  }
}

resource "google_compute_route" "restricted_apis" {
  count            = var.options.restricted_apis ? 1 : 0
  project          = var.project_id
  name             = format("%s-restricted-apis", var.name)
  network          = google_compute_network.network.name
  description      = "Route for restricted Google API access"
  dest_range       = "199.36.153.4/30"
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "tagged_nat" {
  count            = var.options.nat && try(length(var.options.nat_tags), 0) > 0 ? 1 : 0
  project          = var.project_id
  name             = format("%s-tagged-nat", var.name)
  network          = google_compute_network.network.name
  description      = "Route to NAT gateway for tagged resources"
  priority         = "900"
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  tags             = var.options.nat_tags
}

# If the NAT option is set, create a Cloud Router and Cloud NAT pair in each
# region to provide internet egress.
resource "google_compute_router" "nat" {
  for_each    = { for region in var.regions : region => format("%s-%s", var.name, module.regions.results[region].abbreviation) if var.options.nat }
  project     = var.project_id
  name        = each.value
  network     = google_compute_network.network.self_link
  description = "Router to support NAT gateway for internet egress"
  region      = each.key
}

resource "google_compute_router_nat" "nat" {
  for_each                           = google_compute_router.nat
  project                            = var.project_id
  name                               = each.value.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  router                             = each.value.name
  region                             = each.value.region
  log_config {
    enable = var.options.nat_logs
    filter = "ALL"
  }
}

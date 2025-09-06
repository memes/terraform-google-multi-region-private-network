terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.1"
    }
  }
}

locals {
  subnets = { for i, region in var.regions :
    format("%s-%s", var.name, module.regions.results[region].abbreviation) => {
      region                = region
      primary_ipv4_cidr     = cidrsubnet(var.cidrs.primary_ipv4_cidr, var.cidrs.primary_ipv4_subnet_size - tonumber(split("/", var.cidrs.primary_ipv4_cidr)[1]), var.cidrs.primary_ipv4_subnet_offset + i * var.cidrs.primary_ipv4_subnet_step)
      secondary_ipv4_ranges = var.cidrs.secondaries == null ? {} : { for k, v in var.cidrs.secondaries : k => cidrsubnet(v.ipv4_cidr, v.ipv4_subnet_size - tonumber(split("/", v.ipv4_cidr)[1]), v.ipv4_subnet_offset + i * v.ipv4_subnet_step) }
      stack_type            = var.options.ipv6_ula ? "IPV4_IPV6" : "IPV4_ONLY"
      ipv6_access_type      = var.options.ipv6_ula ? "INTERNAL" : null
    }
  }
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.6"
  regions = var.regions
}

resource "google_compute_network" "network" {
  project                         = var.project_id
  name                            = var.name
  description                     = var.description
  auto_create_subnetworks         = false
  routing_mode                    = var.options.regional_routing_mode ? "REGIONAL" : "GLOBAL"
  mtu                             = var.options.mtu
  delete_default_routes_on_create = var.options.delete_default_routes
  enable_ula_internal_ipv6        = var.options.ipv6_ula
  internal_ipv6_range             = var.options.ipv6_ula ? var.cidrs.primary_ipv6_cidr : null
}

resource "google_compute_subnetwork" "subnet" {
  for_each                   = local.subnets
  project                    = var.project_id
  name                       = each.key
  network                    = google_compute_network.network.id
  ip_cidr_range              = each.value.primary_ipv4_cidr
  private_ip_google_access   = true
  private_ipv6_google_access = var.options.ipv6_ula ? "ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE" : null
  region                     = each.value.region
  stack_type                 = each.value.stack_type
  ipv6_access_type           = each.value.ipv6_access_type

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ipv4_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = var.flow_logs == null ? {} : { config = var.flow_logs }
    content {
      aggregation_interval = try(log_config.value.aggregation_interval, "INTERVAL_5_SEC")
      flow_sampling        = try(log_config.value.flow_sampling, 0.5)
      metadata             = try(log_config.value.metadata, "INCLUDE_ALL_METADATA")
      metadata_fields      = try(log_config.value.metadata, "") == "CUSTOM_METADATA" ? log_config.value.metadata_fields : null
      filter_expr          = try(log_config.value.filter_expr, "true")
    }
  }
}

resource "google_compute_route" "apis" {
  for_each         = var.psc != null ? {} : (var.options.enable_restricted_apis_access ? { restricted = "199.36.153.4/30" } : { private = "199.36.153.8/30" })
  project          = var.project_id
  name             = format("%s-%s-apis", var.name, each.key)
  network          = google_compute_network.network.name
  description      = format("Route for %s Google API access", each.key)
  dest_range       = each.value
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_route" "tagged_nat" {
  for_each         = var.nat != null && try(length(var.nat.tags), 0) > 0 ? { tags = var.nat.tags } : {}
  project          = var.project_id
  name             = format("%s-tagged-nat", var.name)
  network          = google_compute_network.network.name
  description      = "Route to NAT gateway for tagged resources"
  priority         = "900"
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  tags             = each.value
}

# If the NAT option is set, create a Cloud Router and Cloud NAT pair in each
# region to provide internet egress.
resource "google_compute_router" "nat" {
  for_each    = { for region in var.regions : region => format("%s-%s", var.name, module.regions.results[region].abbreviation) if var.nat != null }
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
    enable = coalesce(try(var.nat.logging_filter, null), "unspecified") != "unspecified"
    filter = coalesce(try(var.nat.logging_filter, null), "unspecified") != "unspecified" ? var.nat.logging_filter : "ALL"
  }
}
resource "google_compute_global_address" "psc" {
  for_each     = coalesce(try(var.psc.address, null), "unspecified") == "unspecified" ? {} : { (var.name) = var.psc.address }
  project      = google_compute_network.network.project
  name         = each.key
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.network.id
  address      = each.value
}

resource "google_compute_global_forwarding_rule" "psc" {
  for_each              = google_compute_global_address.psc
  project               = google_compute_network.network.project
  name                  = substr(replace(each.key, "/[^a-z0-9]/", ""), 0, 20)
  target                = try(var.options.enable_restricted_apis_access, true) ? "vpc-sc" : "all-apis"
  network               = google_compute_network.network.self_link
  ip_address            = each.value.address
  load_balancing_scheme = ""

  dynamic "service_directory_registrations" {
    for_each = try(length(var.psc.service_directory), 0) > 0 ? { entry = var.psc.service_directory } : {}
    content {
      namespace                = service_directory_registrations.value.namespace
      service_directory_region = service_directory_registrations.value.region
    }
  }
}

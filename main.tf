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
  # Sanitize the primary CIDRs to handle null/optional values and generate the subnet parameters
  primary_ipv4_cidr          = coalesce(try(var.cidrs.primary_ipv4_cidr, null), "172.16.0.0/12")
  primary_ipv4_subnet_size   = try(var.cidrs.primary_ipv4_subnet_size, 24)
  primary_ipv4_subnet_offset = try(var.cidrs.primary_ipv4_subnet_offset, 0)
  primary_ipv4_subnet_step   = try(var.cidrs.primary_ipv4_subnet_step, 1)
  secondaries                = try(var.cidrs.secondaries, null) == null ? {} : var.cidrs.secondaries
  subnets = { for i, region in var.regions :
    format("%s-%s", var.name, module.regions.results[region].abbreviation) => {
      region                = region
      primary_ipv4_cidr     = cidrsubnet(local.primary_ipv4_cidr, local.primary_ipv4_subnet_size - tonumber(split("/", local.primary_ipv4_cidr)[1]), local.primary_ipv4_subnet_offset + i * local.primary_ipv4_subnet_step)
      secondary_ipv4_ranges = { for k, v in local.secondaries : k => cidrsubnet(v.ipv4_cidr, try(v.ipv4_subnet_size, 24) - tonumber(split("/", v.ipv4_cidr)[1]), try(v.ipv4_subnet_offset, 0) + i * try(v.ipv4_subnet_step, 1)) }
      stack_type            = try(var.options.ipv6_ula, false) ? "IPV4_IPV6" : "IPV4_ONLY"
      ipv6_access_type      = try(var.options.ipv6_ula, false) ? "INTERNAL" : null
    }
  }
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.7"
  regions = var.regions
}

resource "google_compute_network" "network" {
  project                         = var.project_id
  name                            = var.name
  description                     = var.description
  auto_create_subnetworks         = false
  routing_mode                    = try(var.options.regional_routing_mode, false) ? "REGIONAL" : "GLOBAL"
  mtu                             = try(var.options.mtu, 1460)
  delete_default_routes_on_create = try(var.options.delete_default_routes, true)
  enable_ula_internal_ipv6        = try(var.options.ipv6_ula, false)
  internal_ipv6_range             = try(var.options.ipv6_ula, false) ? try(var.cidrs.primary_ipv6_cidr, null) : null
}

resource "google_compute_subnetwork" "subnet" {
  for_each                   = local.subnets
  project                    = var.project_id
  name                       = each.key
  network                    = google_compute_network.network.id
  ip_cidr_range              = each.value.primary_ipv4_cidr
  private_ip_google_access   = true
  private_ipv6_google_access = try(var.options.ipv6_ula, false) ? "ENABLE_OUTBOUND_VM_ACCESS_TO_GOOGLE" : null
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
    for_each = var.flow_logs == null ? {} : { enable = true }
    content {
      aggregation_interval = coalesce(try(var.flow_logs.aggregation_interval, "INTERVAL_5_SEC"), "INTERVAL_5_SEC")
      flow_sampling        = try(var.flow_logs.flow_sampling, 0.5)
      metadata             = coalesce(try(var.flow_logs.metadata, "INCLUDE_ALL_METADATA"), "INCLUDE_ALL_METADATA")
      metadata_fields      = try(var.flow_logs.metadata, "INCLUDE_ALL_METADATA") == "CUSTOM_METADATA" ? try(var.flow_logs.metadata_fields, []) : []
      filter_expr          = coalesce(try(var.flow_logs.filter_expr, "true"), "true")
    }
  }
}

resource "google_compute_route" "apis" {
  for_each         = var.psc != null ? {} : (try(var.options.enable_restricted_apis_access, true) ? { restricted = "199.36.153.4/30" } : { private = "199.36.153.8/30" })
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
  labels       = var.labels
}

resource "google_compute_global_forwarding_rule" "psc" {
  for_each              = google_compute_global_address.psc
  project               = google_compute_network.network.project
  name                  = substr(replace(each.key, "/[^a-z0-9]/", ""), 0, 20)
  target                = try(var.options.enable_restricted_apis_access, true) ? "vpc-sc" : "all-apis"
  network               = google_compute_network.network.self_link
  ip_address            = each.value.address
  load_balancing_scheme = ""
  labels                = var.labels

  dynamic "service_directory_registrations" {
    for_each = try(length(var.psc.service_directory), 0) > 0 ? { entry = var.psc.service_directory } : {}
    content {
      namespace                = service_directory_registrations.value.namespace
      service_directory_region = service_directory_registrations.value.region
    }
  }
}

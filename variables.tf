variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id variable must must be 6 to 30 lowercase letters, digits, or hyphens; it must start with a letter and cannot end with a hyphen."
  }
  description = <<-EOD
  The GCP project identifier where the VPC network will be created.
  EOD
}

variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,54}$", var.name))
    error_message = "The name variable must be RFC1035 compliant and between 1 and 55 characters in length."
  }
  default     = "restricted"
  description = <<-EOD
  The name to use when naming resources managed by this module. Must be RFC1035
  compliant and between 1 and 55 characters in length, inclusive.
  EOD
}

variable "description" {
  type        = string
  default     = "custom vpc"
  description = <<-EOD
  A descriptive value to apply to the VPC network. Default value is 'custom vpc'.
  EOD
}

variable "regions" {
  type = list(string)
  validation {
    condition     = var.regions == null ? false : alltrue([for region in var.regions : can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", region))])
    error_message = "There must be at least one entry, and it must be a valid Google Cloud region name."
  }
  description = <<-EOD
  The list of Compute Engine regions in which to create the VPC subnetworks.
  EOD
}

variable "cidrs" {
  type = object({
    primary_ipv4_cidr          = string
    primary_ipv4_subnet_size   = number
    primary_ipv4_subnet_offset = number
    primary_ipv4_subnet_step   = number
    primary_ipv6_cidr          = string
    secondaries = map(object({
      ipv4_cidr          = string
      ipv4_subnet_size   = number
      ipv4_subnet_offset = number
      ipv4_subnet_step   = number
    }))
  })
  nullable = false
  default = {
    primary_ipv4_cidr          = "172.16.0.0/12"
    primary_ipv4_subnet_size   = 24
    primary_ipv4_subnet_offset = 0
    primary_ipv4_subnet_step   = 1
    primary_ipv6_cidr          = null
    secondaries                = {}
  }
  description = <<-EOD
  Sets the primary IPv4 CIDR and regional subnet size to use with the network,
  an optional IPv6 ULA CIDR to use with the network, and any optional secondary
  IPv4 CIDRs and sizes.
  EOD
}

variable "options" {
  type = object({
    mtu                           = number
    delete_default_routes         = bool
    enable_restricted_apis_access = bool
    regional_routing_mode         = bool
    ipv6_ula                      = bool
  })
  nullable = false
  validation {
    condition     = floor(var.options.mtu) == var.options.mtu && var.options.mtu >= 1300 && var.options.mtu <= 8896
    error_message = "Options do not pass validation; MTU must be an integer between 1300 and 8896 inclusive, routing_mode must be one of 'GLOBAL' or 'REGIONAL' and any nat_tag entry has to be RFC1035 compliant."
  }
  default = {
    mtu                           = 1460
    delete_default_routes         = true
    enable_restricted_apis_access = true
    regional_routing_mode         = false
    ipv6_ula                      = false
  }
  description = <<-EOD
  The set of options to use when creating the VPC network. The default value will create a VPC network with MTU of 1460,
  GLOBAL routing mode, and IPv6 ULA disabled. Default routes (0.0.0.0/0, ::0) to the default gateway are deleted; routes
  will be added to support Restricted (default) or Private Google APIs access unless PSC for Google APIs is enabled
  through the `psc` variable.
  EOD
}

variable "flow_logs" {
  type = object({
    aggregation_interval = string
    flow_sampling        = number
    metadata             = string
    metadata_fields      = set(string)
    filter_expr          = string
  })
  nullable = true
  validation {
    condition     = var.flow_logs == null ? true : contains(["INTERVAL_5_SEC", "INTERVAL_30_SEC", "INTERVAL_1_MIN", "INTERVAL_5_MIN", "INTERVAL_10_MIN", "INTERVAL_15_MIN"], var.flow_logs.aggregation_interval) && var.flow_logs.flow_sampling >= 0 && var.flow_logs.flow_sampling <= 1 && contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA", "CUSTOM_METADATA"], var.flow_logs.metadata)
    error_message = "The flow_logs variable does not pass validation."
  }
  default     = null
  description = <<-EOD
  If not null, enable flow log collection in Cloud Logging using the provided parameters. If null (default), flow log
  collection will be disabled.
  EOD
}

variable "nat" {
  type = object({
    tags           = set(string)
    logging_filter = string
  })
  nullable = true
  validation {
    condition     = var.nat == null ? true : alltrue([for tag in(var.nat.tags == null ? [] : var.nat.tags) : can(regex("^[a-z][a-z0-9-]{0,62}$", tag))]) && contains(["ALL", "ERRORS_ONLY", "TRANSLATIONS_ONLY", "unspecified"], coalesce(try(var.nat.logging_filter, null), "unspecified"))
    error_message = "If nat is not null, every tag entry has to be RFC1035 compliant, and, if not empty, the logging_filter entry must be one of 'ERRORS_ONLY', 'TRANSLATIONS_ONLY', or 'ALL'"
  }
  default     = null
  description = <<-EOD
  If not null, Cloud NAT instances and supporting Cloud Routers will be added to each subnet along with supporting
  routes with tags, if applicable. Log collection is controlled by the presence of a non empty logging_filter field.
  EOD
}

variable "psc" {
  type = object({
    address = string
    service_directory = object({
      namespace = string
      region    = string
    })
  })
  nullable = true
  validation {
    condition     = var.psc == null ? true : (can(cidrhost(format("%s/32", var.psc.address), 0)) || can(cidrhost(format("%s/128", var.psc.address), 0))) && (var.psc.service_directory == null || (can(regex("^[a-z][a-z0-9_-]{0,62}$", var.psc.service_directory.namespace)) && can(regex("^(?:[a-z]{2,}-[a-z]{2,}[0-9]|unspecified)$", coalesce(try(var.psc.service_directory.region, null), "unspecified")))))
    error_message = "If psc is not null, it must have a valid IPv4 or IPv6 address to assign, and an optional valid service_directory integration namespace and optional region."
  }
  default     = null
  description = <<-EOD
  If set, create a Private Service Connect for Google APIs resource to provide Private or Restricted Google APIs access
  via a PSC in the VPC. If a valid service_directory field is present automatic DNS registration via Service Directory
  will be activated. The value of `options.enable_restricted_apis_access` determines if the PSC will be to Restricted
  (default) or Private Google APIs bundle.
  EOD
}

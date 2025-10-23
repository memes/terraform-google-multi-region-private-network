variable "project_id" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
  default  = "restricted"
}

variable "description" {
  type     = string
  nullable = true
  default  = "custom vpc"
}

variable "labels" {
  type     = map(string)
  nullable = true
  default  = {}
}

variable "regions" {
  type     = list(string)
  nullable = false
}

variable "cidrs" {
  type = object({
    primary_ipv4_cidr          = optional(string, "172.16.0.0/12")
    primary_ipv4_subnet_size   = optional(number, 24)
    primary_ipv4_subnet_offset = optional(number, 0)
    primary_ipv4_subnet_step   = optional(number, 1)
    primary_ipv6_cidr          = optional(string, null)
    secondaries = optional(map(object({
      ipv4_cidr          = string
      ipv4_subnet_size   = optional(number, 24)
      ipv4_subnet_offset = optional(number, 0)
      ipv4_subnet_step   = optional(number, 1)
    })), null)
  })
  nullable = true
  default = {
    primary_ipv4_cidr          = "172.16.0.0/12"
    primary_ipv4_subnet_size   = 24
    primary_ipv4_subnet_offset = 0
    primary_ipv4_subnet_step   = 1
    primary_ipv6_cidr          = null
    secondaries                = null
  }
  description = <<-EOD
  Sets the primary IPv4 CIDR and regional subnet size to use with the network,
  an optional IPv6 ULA CIDR to use with the network, and any optional secondary
  IPv4 CIDRs and sizes.
  EOD
}

variable "options" {
  type = object({
    mtu                           = optional(number, 1460)
    delete_default_routes         = optional(bool, true)
    enable_restricted_apis_access = optional(bool, true)
    regional_routing_mode         = optional(bool, false)
    ipv6_ula                      = optional(bool, false)
  })
  nullable = true
  default = {
    mtu                           = 1460
    delete_default_routes         = true
    enable_restricted_apis_access = true
    regional_routing_mode         = false
    ipv6_ula                      = false
  }
}

variable "flow_logs" {
  type = object({
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    flow_sampling        = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
    metadata_fields      = optional(set(string), [])
    filter_expr          = optional(string, "true")
  })
  nullable = true
  default  = null
}

variable "nat" {
  type = object({
    tags           = optional(set(string), [])
    logging_filter = optional(string, null)
  })
  nullable = true
  default  = null
}

variable "psc" {
  type = object({
    address = string
    service_directory = optional(object({
      namespace = string
      region    = string
    }), null)
  })
  nullable = true
  default  = null
}

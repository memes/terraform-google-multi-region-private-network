variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = "custom vpc"
}

variable "regions" {
  type = list(string)
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
  default = {
    primary_ipv4_cidr          = "172.16.0.0/12"
    primary_ipv4_subnet_size   = 24
    primary_ipv4_subnet_offset = 0
    primary_ipv4_subnet_step   = 1
    primary_ipv6_cidr          = null
    secondaries                = {}
  }
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
    aggregation_interval = string
    flow_sampling        = number
    metadata             = string
    metadata_fields      = set(string)
    filter_expr          = string
  })
  nullable = true
  default  = null
}

variable "nat" {
  type = object({
    tags           = set(string)
    logging_filter = string
  })
  nullable = true
  default  = null
}

variable "psc" {
  type = object({
    address = string
    service_directory = object({
      namespace = string
      region    = string
    })
  })
  default = null
}

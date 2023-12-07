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
    primary_ipv4_cidr        = string
    primary_ipv4_subnet_size = number
    primary_ipv6_cidr        = string
    secondaries = map(object({
      ipv4_cidr        = string
      ipv4_subnet_size = number
    }))
  })
  default = {
    primary_ipv4_cidr        = "172.16.0.0/12"
    primary_ipv4_subnet_size = 24
    primary_ipv6_cidr        = null
    secondaries              = {}
  }
}

variable "options" {
  type = object({
    mtu                   = number
    delete_default_routes = bool
    restricted_apis       = bool
    routing_mode          = string
    nat                   = bool
    nat_tags              = set(string)
    flow_logs             = bool
    nat_logs              = bool
    ipv6_ula              = bool
    private_apis          = bool
  })
  default = {
    mtu                   = 1460
    delete_default_routes = true
    restricted_apis       = true
    routing_mode          = "GLOBAL"
    nat                   = false
    nat_tags              = null
    flow_logs             = false
    nat_logs              = false
    ipv6_ula              = false
    private_apis          = false
  }
}

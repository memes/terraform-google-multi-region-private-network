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
    primary             = string
    primary_subnet_size = number
    secondaries = map(object({
      cidr        = string
      subnet_size = number
    }))
  })
  default = {
    primary             = "172.16.0.0/12"
    primary_subnet_size = 24
    secondaries         = {}
  }
}

variable "routes" {
  type    = list(map(string))
  default = []
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
  })
  default = {
    mtu                   = 1460
    delete_default_routes = true
    restricted_apis       = true
    routing_mode          = "GLOBAL"
    nat                   = false
    nat_tags              = null
    flow_logs             = false
  }
}

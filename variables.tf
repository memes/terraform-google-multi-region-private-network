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
    condition     = var.regions == null ? false : length(var.regions) > 0 && length(join("", [for region in var.regions : can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", region)) ? "x" : ""])) == length(var.regions)
    error_message = "There must be at least one entry, and it must be a valid Google Cloud region name."
  }
  description = <<-EOD
  The list of Compute Engine regions in which to create the VPC subnetworks.
  EOD
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
  description = <<-EOD
  Sets the primary CIDR and regional subnet size to use with the network, and any
  optional secondary CIDRs and sizes.
  EOD
}

variable "routes" {
  type        = list(map(string))
  default     = []
  description = <<-EOD
  An optional set of routes to add to the VPC network. Format is the same as the
  `routes` variable for Google's network module.
  EOD
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
  description = <<-EOD
  The set of options to use when creating the VPC network.
  EOD
}

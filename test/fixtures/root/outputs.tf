#
# Module under test outputs
#
output "self_link" {
  value = module.test.self_link
}

output "id" {
  value = module.test.id
}

output "subnets_by_name_json" {
  value = jsonencode(module.test.subnets_by_name)
}

output "subnets_by_region_json" {
  value = jsonencode(module.test.subnets_by_region)
}

# Output some of the inputs as JSON objects to make it easier to process in kitchen
output "cidrs_json" {
  value = jsonencode(var.cidrs)
}

output "options_json" {
  value = jsonencode(var.options)
}

output "flow_logs_json" {
  value = jsonencode(var.flow_logs)
}

output "nat_json" {
  value = jsonencode(var.nat)
}

output "psc_json" {
  value = jsonencode(var.psc)
}

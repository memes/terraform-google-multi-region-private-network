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

#
# Module under test outputs
#
output "self_link" {
  value = module.test.self_link
}

output "subnets_json" {
  value = jsonencode(module.test.subnets)
}

# Output some of the inputs as JSON objects to make it easier to process in kitchen
output "cidrs_json" {
  value = jsonencode(var.cidrs)
}

output "routes_json" {
  value = jsonencode(var.routes)
}

output "options_json" {
  value = jsonencode(var.options)
}

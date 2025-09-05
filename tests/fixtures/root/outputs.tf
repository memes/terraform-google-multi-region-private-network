#
# Module under test outputs
#
output "self_link" {
  value = module.test.self_link
}

output "id" {
  value = module.test.id
}

output "subnets_by_name" {
  value = module.test.subnets_by_name
}

output "subnets_by_region" {
  value = module.test.subnets_by_region
}

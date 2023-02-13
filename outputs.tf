output "self_link" {
  value = module.network.network_self_link
}

output "subnets" {
  value = { for k, v in module.network.subnets : v.region => v.self_link }
}

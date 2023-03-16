output "self_link" {
  value       = google_compute_network.network.self_link
  description = <<-EOD
  The fully-qualified self-link URI of the created VPC network.
  EOD
}

output "subnets" {
  value = { for k, v in google_compute_subnetwork.subnet : v.name => {
    region          = v.region
    self_link       = v.self_link
    primary_cidr    = v.ip_cidr_range
    secondary_cidrs = v.secondary_ip_range
  } }
  description = <<-EOD
  A map of subnet name to region, self_link, and CIDRs.
  EOD
}


output "subnets_by_region" {
  value = { for k, v in google_compute_subnetwork.subnet : v.region => {
    name            = v.name
    self_link       = v.self_link
    primary_cidr    = v.ip_cidr_range
    secondary_cidrs = v.secondary_ip_range
  } }
  description = <<-EOD
  A map of subnet region to name, self_link, and CIDRs.
  EOD
}

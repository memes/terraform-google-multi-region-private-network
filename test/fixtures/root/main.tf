terraform {
  required_version = ">= 1.2"
}

module "test" {
  source      = "./../../../"
  project_id  = var.project_id
  name        = var.name
  description = var.description
  regions     = var.regions
  cidrs       = var.cidrs
  options     = var.options
}

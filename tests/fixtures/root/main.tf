# This fixture is a thin wrapper around the root module; same input variables and defaults, same outputs.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.1"
    }
  }
}

provider "google" {
  default_labels = merge({
    "test_source"  = "memes_terraform_google_multi_region_private_network"
    "test_fixture" = "root"
  }, var.default_labels)
}

module "test" {
  source      = "./../../../"
  project_id  = var.project_id
  name        = var.name
  description = var.description
  regions     = var.regions
  cidrs       = var.cidrs
  options     = var.options
  flow_logs   = var.flow_logs
  nat         = var.nat
  psc         = var.psc
}

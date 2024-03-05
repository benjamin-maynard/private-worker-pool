// Configure Google Provider
provider "google" {
    project = local.project_id
}

// Specify Required Providers
terraform {
  required_providers {
    google = {
      version = "5.14.0"
    }
  }
}

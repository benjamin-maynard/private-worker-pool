locals {

  // Project to deploy in
  project_id = "appmod-golden-demo-dev"

  // Region to deploy resources to. We could set this at the provider level but intentionally
  // hard referencing it so its clear what resources are global, and what ones are regional
  deploy_region = "us-central1"

  // us-central1 VPC subnet
  us-central1_subnet     = "10.167.4.0/24" // Subnet CIDR for our us-central1 subnet
  static_ip_nat_instance = "10.167.4.123"  // Static IP that is assigned to the NAT VM
  nat_tag                = "natfwd"        // Network tag that is assigned to the NAT VM

  # Service Networking Ranges
  service_networking_reserved_range_network = "10.167.5.0"                                                                                           // Network Address for reserved range
  service_networking_reserved_range_prefix  = 24                                                                                                     // Prefix length for reserved range
  service_networking_reserved_range_cidr    = "${local.service_networking_reserved_range_network}/${local.service_networking_reserved_range_prefix}" // CIDR for reserved range

}

// We need to reference the project number, so look this up with a Data Source
data "google_project" "this" {
  project_id = local.project_id
}

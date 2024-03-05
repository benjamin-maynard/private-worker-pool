resource "google_compute_network" "main" {
  name                    = "cb-worker-pool-test"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "us-central1-main" {
  name                     = "us-central1-main"
  network                  = google_compute_network.main.self_link
  region                   = local.deploy_region
  private_ip_google_access = true
  ip_cidr_range            = local.us-central1_subnet
}

// Reserve our range for Service Networking
resource "google_compute_global_address" "service-networking-reserved" {
  name          = "servicenetworking-reserved-range"
  address_type  = "INTERNAL"
  address       = local.service_networking_reserved_range_network
  purpose       = "VPC_PEERING"
  prefix_length = local.service_networking_reserved_range_prefix
  network       = google_compute_network.main.self_link
}

// Create the VPC Peering for Service Networking
resource "google_service_networking_connection" "service-networking" {
  network                 = google_compute_network.main.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.service-networking-reserved.name]
}

// Export the VPC routes to the Service Networking Connection
resource "google_compute_network_peering_routes_config" "service-networking" {
  depends_on           = [google_service_networking_connection.service-networking]
  peering              = google_service_networking_connection.service-networking.peering
  network              = google_compute_network.main.name
  export_custom_routes = true
  import_custom_routes = false
}

// Create a self-managed NAT instance for controlling egress
resource "google_compute_instance" "self-managed-nat" {

  name         = "nat-instance"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  can_ip_forward = true
  tags           = [local.nat_tag] // Create a tag for this VM so we can reference it by tag in the route table

  network_interface {

    subnetwork = google_compute_subnetwork.us-central1-main.self_link
    network_ip = local.static_ip_nat_instance

    access_config {
      // Ephemeral public IP
    }

  }

  // Script to enable IP Forwarding within the OS
  metadata_startup_script = <<EOT
#! /bin/bash
set -e

sysctl -w net.ipv4.ip_forward=1
IFACE=$(ip -brief link | tail -1 | awk  {'print $1'})
iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
EOT


}

// Add an entry to the route table for the VPC to send all internet traffic to this NAT VM
// We have to specify two more specific routes instead of 0.0.0.0/0 as it is not possible to
// override the default 0/0 route in the VPC that the Private Worker Pool exists in.
// This route will also catch all traffic for all VM's in the VPC, so would want to use a dedicated
// VPC for this.
resource "google_compute_route" "worker-pool-egress" {
  for_each = toset([
    "0.0.0.0/1",
    "128.0.0.0/1"
  ])
  name        = "wp-egr-${replace(replace(each.key, ".", "-"), "/", "-")}" // Need unique names
  dest_range  = each.key
  next_hop_ip = local.static_ip_nat_instance
  network     = google_compute_network.main.self_link
  priority    = 1000 // Higher number is lower priority
}

// We can't have our NAT VM routing via itself, so createa  higher priority route applying only to
// the Network Tag we assigned to our NAT VM that routes via the default IGW, for the same specific
// routes
resource "google_compute_route" "proxy-vm-route-internet" {
  for_each = toset([
    "0.0.0.0/1",
    "128.0.0.0/1"
  ])
  name             = "pvm-igw-${replace(replace(each.key, ".", "-"), "/", "-")}" // Need unique names
  dest_range       = each.key
  next_hop_gateway = "default-internet-gateway"
  network          = google_compute_network.main.self_link
  priority         = 100 // Lower number is higher priority
  tags             = [local.nat_tag]
}

// Make sure our 199.36.153.8/30 (private.googleapis.com traffic goes directly via the IGW instead of via
// the NAT VM
resource "google_compute_route" "google-apis-route-internet" {
  for_each = toset([
    "199.36.153.8/30"
  ])
  name             = "gapi-${replace(replace(each.key, ".", "-"), "/", "-")}" // Need unique names
  dest_range       = each.key
  next_hop_gateway = "default-internet-gateway"
  network          = google_compute_network.main.self_link
  priority         = 99
}


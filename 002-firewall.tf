// Create a GCE_FIREWALL tag key that we will use to identify our NAT VM.
// These are different to Network Tags, and are specifically tags for
// Firewalls - https://cloud.google.com/firewall/docs/tags-firewalls-overview
resource "google_tags_tag_key" "vmtype" {
  parent      = "projects/${local.project_id}"
  short_name  = "vmtype"
  description = "The type of the VM"
  purpose     = "GCE_FIREWALL"
  purpose_data = {
    network = "${local.project_id}/${google_compute_network.main.name}"
  }
}

// Create a tag value of selfmanagednat which we will assign to our NAT VM, and use
// to identify the VM in tests
resource "google_tags_tag_value" "self-managed-nat" {
  parent      = "tagKeys/${google_tags_tag_key.vmtype.name}"
  short_name  = "selfmanagednat"
  description = "Self Managed NAT Instance"

}

// Bind our Compute Engine VM to that Tag Value so our subsequent Firewall Rules apply to it
resource "google_tags_location_tag_binding" "self-managed-nat" {
  parent    = "//compute.googleapis.com/projects/${data.google_project.this.number}/zones/${google_compute_instance.self-managed-nat.zone}/instances/${google_compute_instance.self-managed-nat.instance_id}"
  tag_value = "tagValues/${google_tags_tag_value.self-managed-nat.name}"
  location  = google_compute_instance.self-managed-nat.zone
}

// Create our Network Firewall Policy for the Global Network Firewall Policy
# https://cloud.google.com/firewall/docs/network-firewall-policies
resource "google_compute_network_firewall_policy" "main" {
  name        = "main"
  description = "main-policy"
}

// Associate the Firewall Policy to our VPC
resource "google_compute_network_firewall_policy_association" "main" {
  name              = "main"
  attachment_target = google_compute_network.main.self_link
  firewall_policy   = google_compute_network_firewall_policy.main.id
}

// Allow all traffic from our Cloud Build Private Worker Pool to the NAT VM
// If there are other VM's in the VPC the scope of the rule should include them
// as the route applies to all VM's in the VPC
resource "google_compute_network_firewall_policy_rule" "allow-all-ingress-nat" {

  firewall_policy = google_compute_network_firewall_policy.main.id
  description     = "Allow Ingress NAT"
  priority        = 998 // The lower the value, the higher the priority (not intuitive)
  enable_logging  = true
  action          = "allow"
  direction       = "INGRESS"
  disabled        = false

  target_secure_tags {
    name = "tagValues/${google_tags_tag_value.self-managed-nat.name}"
  }

  match {
    src_ip_ranges = [local.service_networking_reserved_range_cidr]
    layer4_configs {
      ip_protocol = "all"
    }

  }
}

// Allow HTTPS egress to the private.googleapis.com range in the VPC
resource "google_compute_network_firewall_policy_rule" "allow-private-googleapis-com" {
  firewall_policy = google_compute_network_firewall_policy.main.id
  description     = "Allow private.googleapis.com"
  priority        = 999 // The lower the value, the higher the priority (not intuitive)
  enable_logging  = true
  action          = "allow"
  direction       = "EGRESS"
  disabled        = false

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports       = [443]
    }
    dest_ip_ranges = ["199.36.153.8/30"]
  }
}

// Allow access to the known Docker HUB FQDN's - Google will periodically resolves
// these domains and add firewall rules for them. This is not an ideal approach,
// as Docker may periodically change their FQDN's. Better approach would be to use
// a remote repository: https://cloud.google.com/artifact-registry/docs/repositories/create-dockerhub-remote-repository
resource "google_compute_network_firewall_policy_rule" "allow-docker-hub-fqdn" {

  firewall_policy = google_compute_network_firewall_policy.main.id
  description     = "Allow Docker Hub Access"
  priority        = 1000 // The lower the value, the higher the priority (not intuitive)
  enable_logging  = true
  action          = "allow"
  direction       = "EGRESS"
  disabled        = false

  // Connection comes from the Docker VM, so we apply it here
  target_secure_tags {
    name = "tagValues/${google_tags_tag_value.self-managed-nat.name}"
  }

  match {
    layer4_configs {
      ip_protocol = "tcp"
      ports       = [443]
    }

    dest_fqdns = [
      # https://docs.docker.com/desktop/allow-list/
      "docker.io",
      "registry-1.docker.io",
      "registry.docker.io",
      "auth.docker.io",
      "login.docker.io",
      "cdn.auth0.com",
      "production.cloudflare.docker.com"
    ]

  }

}

// Finally, prevent any other egress from the VPC, with the lowest priorirty
resource "google_compute_network_firewall_policy_rule" "deny-default-egress" {
  firewall_policy = google_compute_network_firewall_policy.main.id
  description     = "Deny Default Egress"
  priority        = 2000
  enable_logging  = true
  action          = "deny"
  direction       = "EGRESS"
  disabled        = false
  match {
    layer4_configs {
      ip_protocol = "all"
    }
    dest_ip_ranges = ["0.0.0.0/0"]
  }
}

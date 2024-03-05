// Create a private zone for googleapis.com which we will use to re-map
// IP's used for *.googleapis.com
resource "google_dns_managed_zone" "googleapis-com" {
  name        = "googleapis-com"
  dns_name    = "googleapis.com."
  description = "Google API's Private Zone"
  visibility  = "private"

  private_visibility_config {

    // Export to our VPC
    networks {
      network_url = google_compute_network.main.id
    }

  }
}

// Export googleapis.com to Service Networking
resource "google_service_networking_peered_dns_domain" "servicenetworking-googleapis-com-private-googleapis-com" {
  name       = "private-googleapis-com"
  network    = google_compute_network.main.name
  dns_suffix = "googleapis.com."
  service    = "servicenetworking.googleapis.com"
}

// Create a private.googleapis.com A record in the googleapis.com Zone.
// with values from the 199.36.153.8/30 range
// https://cloud.google.com/vpc/docs/configure-private-google-access#config-domain
resource "google_dns_record_set" "private-googleapis-com" {
  name = "private.googleapis.com."
  type = "A"
  rrdatas = [
    "199.36.153.8",
    "199.36.153.9",
    "199.36.153.10",
    "199.36.153.11"
  ]
  managed_zone = google_dns_managed_zone.googleapis-com.name
}

// Create a wildcard CNAME record that catches all Google API's requests,
// and mapps them to private.googleapis.com IP's via the CNAME
resource "google_dns_record_set" "star-googleapis-com" {
  name = "*.googleapis.com."
  type = "CNAME"
  rrdatas = [
    google_dns_record_set.private-googleapis-com.name
  ]
  managed_zone = google_dns_managed_zone.googleapis-com.name
}

// We also need to capture Artifact Registry traffic too, so create a zone for
// *.pkg.dev
resource "google_dns_managed_zone" "pkg-dev" {
  name        = "pkg-dev"
  dns_name    = "pkg.dev."
  description = "Artifact Registry Private Zone"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.main.id
    }
  }
}

// // Export pkg.dev to Service Networking
resource "google_service_networking_peered_dns_domain" "servicenetworking-googleapis-com-pkg-dev" {
  name       = "pkg-dev"
  network    = google_compute_network.main.name
  dns_suffix = "pkg.dev."
  service    = "servicenetworking.googleapis.com"
}

// Create a wildcard record to catch all Google API's and send to the private range
resource "google_dns_record_set" "star-pkg-dev" {
  name = "*.pkg.dev."
  type = "CNAME"
  rrdatas = [
    google_dns_record_set.private-googleapis-com.name
  ]
  managed_zone = google_dns_managed_zone.pkg-dev.name
}

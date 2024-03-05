// Create a Dedicated Service Account for Cloud Build
resource "google_service_account" "cloudbuild-service-account" {
  account_id = "gcb-worker-service-account"
}

// Make sure that Service Account can write logs for the Build Job
resource "google_project_iam_member" "custom-sa-logger" {
    role = "roles/logging.logWriter"
    member = "serviceAccount:${google_service_account.cloudbuild-service-account.email}"
    project = local.project_id

}

// Create a test Artifact Registry repository
resource "google_artifact_registry_repository" "docker" {
  format        = "DOCKER"
  repository_id = "test-docker-gcb"
  location      = local.deploy_region
}

// Give the Cloud Build Service Account permission to use the AR Repo
resource "google_artifact_registry_repository_iam_member" "cloudbuild-service-account_id" {
  repository = google_artifact_registry_repository.docker.id
  role       = "roles/artifactregistry.admin" // Just for testing, would ideally be less permissive
  location = google_artifact_registry_repository.docker.location
  member = "serviceAccount:${google_service_account.cloudbuild-service-account.email}"
}

// Make the repo path more easily referencable
locals {
  docker_repo_path = "${google_artifact_registry_repository.docker.location}-docker.pkg.dev/${google_artifact_registry_repository.docker.project}/${google_artifact_registry_repository.docker.repository_id}"
}

// Create our Private Pool, disabling External IPs
resource "google_cloudbuild_worker_pool" "private-pool" {
  depends_on = [google_compute_network_peering_routes_config.service-networking]
  name       = "private-pool"
  location   = local.deploy_region
  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-4"
    no_external_ip = true

  }
  network_config {
    peered_network = google_compute_network.main.id
  }

}

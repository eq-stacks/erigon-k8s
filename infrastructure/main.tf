variable "billing_account" {}
variable "credentials_file" {}
variable "org_id" {}
variable "target_project" {}
variable "service_account_project" {}
variable "project_owners" {}
variable "project_host_vpc" {}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.8.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.service_account_project
}

data "google_service_account" "terraform" {
  account_id = "terraform"
}

resource "google_project" "target_project" {
  name                = "Eth1 - Erigon"
  project_id          = var.target_project
  org_id              = var.org_id
  auto_create_network = false

  billing_account = var.billing_account
}

resource "google_project_iam_binding" "eth_validator_project" {
  project = var.target_project
  role    = "roles/owner"
  members = var.project_owners
  depends_on = [
    google_project.target_project
  ]
}

resource "google_compute_shared_vpc_service_project" "service_project" {
  host_project    = var.project_host_vpc
  service_project = google_project.target_project.project_id
}

resource "google_project_service" "container" {
  project = google_project.target_project.id
  service = "container.googleapis.com"

  disable_dependent_services = true
  depends_on = [
    google_project.target_project
  ]
}

resource "google_project_iam_binding" "host_project" {
  project = var.project_host_vpc
  role    = "roles/container.hostServiceAgentUser"
  members = [
    "serviceAccount:service-${google_project.target_project.number}@container-engine-robot.iam.gserviceaccount.com"
  ]
  depends_on = [
    google_project_service.container
  ]
}

resource "google_compute_subnetwork_iam_binding" "subnetwork" {
  project    = var.project_host_vpc
  region     = "us-east4"
  subnetwork = "us-east4-2"
  role       = "roles/compute.networkUser"
  members = [
    "serviceAccount:service-${google_project.target_project.number}@container-engine-robot.iam.gserviceaccount.com",
    "serviceAccount:${google_project.target_project.number}@cloudservices.gserviceaccount.com"
  ]
}

data "google_compute_network" "host_vpc" {
  name    = "host-vpc"
  project = var.project_host_vpc
}

data "google_compute_subnetwork" "us_east4-2" {
  name    = "us-east4-2"
  region  = "us-east4"
  project = var.project_host_vpc
}

resource "google_container_cluster" "testnet" {
  name     = "testnet"
  location = "us-east4-c"
  project  = google_project.target_project.project_id

  # Create the smallest possible default node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = data.google_compute_network.host_vpc.self_link
  subnetwork = "projects/host-vpc-project-10/regions/us-east4/subnetworks/us-east4-2"
  # network = "projects/host-vpc-project-10/global/networks/host-vpc"

  ip_allocation_policy {
    cluster_secondary_range_name  = "us-east4-2-pods"
    services_secondary_range_name = "us-east4-2-services"
  }

  depends_on = [
    google_project_service.container,
    google_project_iam_binding.host_project,
    google_compute_subnetwork_iam_binding.subnetwork
  ]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary"
  cluster    = google_container_cluster.testnet.id
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-standard-4"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    # service_account = google_service_account.default.email
    # oauth_scopes = [
    #   "https://www.googleapis.com/auth/cloud-platform"
    # ]
  }
}
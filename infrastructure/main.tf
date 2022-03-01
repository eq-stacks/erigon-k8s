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

resource "google_compute_shared_vpc_service_project" "eth2_validator_service_project" {
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
}

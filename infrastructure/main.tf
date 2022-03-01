variable "billing_account" {}
variable "credentials_file" {}
variable "org_id" {}
variable "project_eth1_erigon" {}
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

resource "google_project" "erigon_project" {
  name                = "Eth1 - Erigon"
  project_id          = var.project_eth1_erigon
  org_id              = var.org_id
  auto_create_network = false

  billing_account = var.billing_account
}

resource "google_project_iam_binding" "eth_validator_project" {
  project = var.project_eth1_erigon
  role    = "roles/owner"
  members = var.project_owners
  depends_on = [
    google_project.erigon_project
  ]
}

resource "google_compute_shared_vpc_service_project" "eth2_validator_service_project" {
  host_project    = var.project_host_vpc
  service_project = google_project.erigon_project.project_id
}

resource "google_project_service" "container" {
  project = google_project.eth2_validator_project.id
  service = "container.googleapis.com"

  disable_dependent_services = true
  depends_on = [
    google_project.project_eth1_erigon
  ]
}

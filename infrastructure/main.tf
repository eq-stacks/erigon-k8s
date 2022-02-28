variable "billing_account" {}
variable "credentials_file" {}
variable "org_id" {}
variable "project_eth1_erigon" {}
variable "service_account_project" {}

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
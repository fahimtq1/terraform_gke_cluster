terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "fahimdoestech-tf-state-20250916220808" # Replace with your actual bucket name
    prefix = "terraform/state/dev"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.cluster_location
}

module "gke_cluster" {
  source           = "../../modules/gke_cluster"
  project_id       = var.gcp_project_id
  cluster_name     = var.cluster_name
  cluster_location = var.cluster_location
  node_count       = var.node_count
}
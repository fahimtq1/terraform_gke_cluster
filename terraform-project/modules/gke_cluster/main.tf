resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.cluster_location
  project                  = var.project_id
  initial_node_count       = var.node_count
  network                  = "default"
  enable_autopilot         = false

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "default-node-pool"
  location   = var.cluster_location
  project    = var.project_id
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = "e2-small"  # Changed to e2-small for free tier
	disk_type    = "pd-standard"
	oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
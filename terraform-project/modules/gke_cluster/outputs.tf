output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

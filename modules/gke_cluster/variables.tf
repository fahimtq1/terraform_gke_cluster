variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
}

variable "cluster_location" {
  description = "The GCP region or zone for the cluster."
  type        = string
}

variable "node_count" {
  description = "The number of nodes per node pool."
  type        = number
  default     = 1
}
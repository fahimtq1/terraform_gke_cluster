variable "gcp_project_id" {
  type    = string
  default = "fahimdoestech"
}

variable "cluster_name" {
  type    = string
  default = "dev-gke-cluster"
}

variable "cluster_location" {
  type        = string
  default     = "us-central1-a"
  description = "The GCP location (region or zone) for the cluster"
}

variable "node_count" {
  type    = number
  default = 1
}

package main

import future.keywords.if  # Optional but recommended for forward compatibility

deny contains msg if {
    input.resource_changes[_].type == "google_container_node_pool"
    input.resource_changes[_].change.after.node_count > 1
    msg := "GKE clusters in non-prod environments must have 1 or fewer nodes to control costs."
}

deny contains msg if {
    input.resource_changes[_].type == "google_container_node_pool"
    input.resource_changes[_].change.after.node_config[0].machine_type != "e2-small"
    msg := "GKE clusters in non-prod environments must use e2-small machine type to control costs."
}
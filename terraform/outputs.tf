output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.demo.name
}

output "get_credentials" {
  description = "Convenience gcloud command to fetch kubeconfig"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.demo.name} --region ${google_container_cluster.demo.location} --project ${var.project_id}"
}

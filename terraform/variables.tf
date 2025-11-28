variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region for GKE"
  type        = string
  default     = "us-east1"
}

variable "cluster_name" {
  description = "Name of the demo cluster"
  type        = string
  default     = "pyroscope-demo"
}

variable "network" {
  description = "VPC network to use (defaults to 'default')"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork to use (defaults to 'default')"
  type        = string
  default     = "default"
}

variable "node_count" {
  description = "Number of nodes in the demo node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type for the node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "node_service_account" {
  description = "Service account email for the node pool; leave empty to use the default compute service account"
  type        = string
  default     = ""
}

variable "preemptible" {
  description = "Use preemptible VMs to reduce cost for the live demo"
  type        = bool
  default     = true
}

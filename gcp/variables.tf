variable "prefix" {
  default = "MYPROJECT"
}

variable "cloud_provider" {
  default = "gcp"
}

variable "region" {
  default = "us-west1"
}

# P4 GPUs not available in us-west1
variable "zone" {
  default = "us-west2-b"
}

variable "machine_type" {
  default = "n1-highmem-2"
}

# Not clear if this should be nvidia-tesla-p4-vws
variable "gpu_type" {
  default = "nvidia-tesla-p4-vws"
}

# The default on AWS, might as well make that the default everywhere
variable "admin_username" {
  default = "ubuntu"
}

variable "your_credentials" {
  default = "USERNAME_gcp_credentials.json"
}

variable "activate_apis" {
  default = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}
variable "prefix" {
  default = "MYPROJECT"
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-b"
}

variable "machine_type" {
  default = "n1-highmem-2"
}

variable "gpu_type" {
  default = "nvidia-tesla-p4-vws"
}

variable "admin_username" {
  default = "testadmin"
}

variable "your_credentials" {
  default = "USERNAME_gcp_credentials.json"
}

variable "azure_pipelines_organization" {
  default = "YOUR_AZURE_PIPELINES_ORGANIZATION"
}

variable "azure_pipelines_token" {
  default = "YOUR_AZURE_PIPELINES_PAT_TOKEN"
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
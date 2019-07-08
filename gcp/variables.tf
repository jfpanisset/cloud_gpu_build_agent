variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-b"
}

variable "machine_type" {
  default = "n1-highmem-2"
}

variable "admin_username" {
  default = "testadmin"
}

variable "your_credentials" {
  default = "panisset_gcp_credentials.json"
}

variable "azure_pipelines_organization" {
  default = "YOUR_AZURE_PIPELINES_ORGANIZATION"
}

variable "azure_pipelines_token" {
  default = "YOUR_AZURE_PIPELINES_PAT_TOKEN"
}

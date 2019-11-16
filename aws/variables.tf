variable "prefix" {
  default = "jf-aswf"
}
variable "aws_region" {
  default = "us-west-2"
}

variable "aws_access_key_id" {
  default = "YOUR_AWS_ACCESS_KEY"
}

variable "aws_secret_access_key" {
  default = "YOUR_AWS_SECRET_KEY"
}

variable "aws_availability_zone" {
  default = "us-west-2a"
}

variable "machine_type" {
  default = "p2.xlarge"
}

// 50GB root volume by default
variable "root_volume_size" {
  default = 50
}

// Ubuntu AMIs on AWS have "ubuntu" as the default admin account
variable "admin_username" {
  default = "ubuntu"
}

variable "azure_pipelines_organization" {
  default = "YOUR_AZURE_PIPELINES_ORGANIZATION"
}

variable "azure_pipelines_token" {
  default = "YOUR_AZURE_PIPELINES_PAT_TOKEN"
}

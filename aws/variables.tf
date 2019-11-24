variable "prefix" {
  default = "jf-aswf"
}

variable "cloud_provider" {
  default = "aws"
}

variable "aws_region" {
  default = "us-west-2"
}

// Prefer setting via TF_VAR_aws_access_key_id environment variable to avoid
// command line parameters ending up in CI logs
variable "aws_access_key_id" {
  default = "YOUR_AWS_ACCESS_KEY"
}

// Prefer setting via TF_VAR_aws_secret_access_key environment variable to avoid
// command line parameters ending up in CI logs
variable "aws_secret_access_key" {
  default = "YOUR_AWS_SECRET_KEY"
}

variable "aws_availability_zone" {
  default = "us-west-2a"
}

variable "machine_type" {
  default = "g3s.xlarge"
}

// 50GB root volume by default
variable "root_volume_size" {
  default = 50
}

// Ubuntu AMIs on AWS have "ubuntu" as the default admin account
variable "admin_username" {
  default = "ubuntu"
}


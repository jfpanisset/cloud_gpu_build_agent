variable "prefix" {
  default = "jf-aswf"
}

variable "cloud_provider" {
  default = "azure"
}

variable "location" {
  default = "westus2"
}

variable "azure_machine_type" {
  default = "Standard_NV6_Promo"
}
variable "azure_linux_publisher" {
  default = "Canonical"
}
variable "azure_linux_offer" {
  default = "UbuntuServer"
}
variable "azure_linux_sku" {
  default = "18.04-LTS"
}
variable "azure_linux_version" {
  default = "latest"
}
variable "azure_linux_hostname" {
  default = "jf-aswf-azlinux"
}

# The default on AWS, might as well make that the default everywhere
variable "admin_username" {
  default = "ubuntu"
}

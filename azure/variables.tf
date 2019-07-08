variable "prefix" {
  default = "jf-aswf"
}
variable "location" {
  default = "westus2"
}

variable "azure_machine_type" {
  default = "Standard_NC6_Promo"
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
variable "admin_username" {
  default = "testadmin"
}

variable "admin_password" {
  default = "Password1234!"
}
variable "azure_pipelines_organization" {
  default = "YOUR_AZURE_PIPELINES_ORGANIZATION"
}

variable "azure_pipelines_token" {
  default = "YOUR_AZURE_PIPELINES_PAT_TOKEN"
}

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.31.0"
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "${var.location}"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-PublicIp1"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.main.id}"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "${var.azure_machine_type}"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "${var.azure_linux_publisher}"
    offer     = "${var.azure_linux_offer}"
    sku       = "${var.azure_linux_sku}"
    version   = "${var.azure_linux_version}"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.azure_linux_hostname}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
   os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("~/.ssh/id_rsa.pub")}"
    }
  }
  tags = {
    environment = "staging"
  }

  connection {
    type        = "ssh"
    user        = "${var.admin_username}"
    private_key = "${file("~/.ssh/id_rsa")}"
    host        = "${azurerm_public_ip.main.ip_address}"
  }
  provisioner "remote-exec" {
    inline = ["sudo apt update && sudo apt install -y python-minimal"]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u ${var.admin_username} -i '${azurerm_public_ip.main.ip_address},' --private-key '~/.ssh/id_rsa' --extra-vars 'azure_pipelines_organization=${var.azure_pipelines_organization}' --extra-vars 'azure_pipelines_token=${var.azure_pipelines_token}' ../provision.yml" 
  }
}

data "azurerm_public_ip" "main" {
  name                = "${azurerm_public_ip.main.name}"
  resource_group_name = "${azurerm_virtual_machine.main.resource_group_name}"
}

output "public_ip_address" {
  value = "${data.azurerm_public_ip.main.ip_address}"
}
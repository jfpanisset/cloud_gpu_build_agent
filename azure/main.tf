# Terraform Backend Configuration
# This is a partial configuration, requires organization= token= workspaces= from
# terraform init command line

# Before Terraform 0.12 you could pass a workspace on the command line using:
# terraform init  -backend-config="workspaces=[{name=foo}]"
# but this is now broken as per https://github.com/hashicorp/terraform/issues/21830}
# So for now we specify the workspace in backend.hcl

terraform {
  required_version = ">= 0.12"
  backend "remote" {}
}

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.44.0"
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resource_group"
  location = var.location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["8.8.8.8", "8.8.4.4"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-PublicIp1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  domain_name_label   = var.prefix

  tags = {
    environment = "main"
  }
}

resource "azurerm_network_security_group" "main" {
    name                = "${var.prefix}-NetworkSecurityGroup"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "main"
    }
}

data "azurerm_public_ip" "main" {
   name                = azurerm_public_ip.main.name
   resource_group_name = azurerm_public_ip.main.resource_group_name
   depends_on          = [azurerm_public_ip.main]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = var.azure_machine_type

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = var.azure_linux_publisher
    offer     = var.azure_linux_offer
    sku       = var.azure_linux_sku
    version   = var.azure_linux_version
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.azure_linux_hostname
    admin_username = var.admin_username
  }
   os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }
  tags = {
    environment = "staging"
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      host        = data.azurerm_public_ip.main.fqdn
    }
    // Dummy command just to wait until ssh is ready for Ansible
    inline = ["cat /etc/issue"]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -vv -u ${var.admin_username} -i '${data.azurerm_public_ip.main.fqdn},' --private-key '~/.ssh/id_rsa' --ssh-common-args '-o StrictHostKeyChecking=no' --extra-vars ansible_python_interpreter=/usr/bin/python3 --extra-vars 'cloud_provider=${var.cloud_provider}' ../provision.yml"
  }
}

output "public_ip_fqdn" {
  value = data.azurerm_public_ip.main.fqdn
}

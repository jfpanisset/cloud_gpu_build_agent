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

# Configure the Google Cloud provider
# Contents of credential file should be in GOOGLE_CLOUD_KEYFILE_JSON environment variable
provider "google" {
#  credentials = file("${var.your_credentials}")
  project     = var.prefix
  region      = var.region
  version     = "=3.10.0"
}

# Enable required APIs on our project
resource "google_project_service" "activate_apis" {
  count = length(var.activate_apis)
  project = var.prefix
  service = element(var.activate_apis, count.index)
  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "api_iam" {
  project = var.prefix
  service = "iam.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "api_compute" {
  project = var.prefix
  service = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
  byte_length = 8
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "${var.prefix}-${random_id.instance_id.hex}"
  machine_type = var.machine_type
  zone         = var.zone
  guest_accelerator { 
    type =  var.gpu_type
    count = 1
  }
  boot_disk {
    initialize_params {
      image = "ubuntu-1804-lts"
    }
  }

  //  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync; pip install flask"

  network_interface {
    network = "default"
    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  metadata = {
    ssh-keys = "${var.admin_username}:${file(pathexpand("~/.ssh/id_rsa.pub"))}"
  }

  scheduling {
    // GPU hosts don't support live migration
    on_host_maintenance = "terminate"
  }

  connection {
    type        = "ssh"
    user        = var.admin_username
    private_key = file(pathexpand("~/.ssh/id_rsa"))
    host        = self.network_interface.0.access_config.0.nat_ip
  }
  provisioner "remote-exec" {
    // Dummy command just to wait until ssh is ready for Ansible
    inline = ["cat /etc/issue"]
  }

  // Ubuntu 18.04 minimal install doesn't have Python 2 by default, and "python-minimal" package seems
  // to have gone MIA. Make sure Ansible uses Python 3 regardless of what's installed on the controller.
  provisioner "local-exec" {
    command = "ansible-playbook -vv -u ${var.admin_username} -i '${self.network_interface.0.access_config.0.nat_ip},' --private-key '~/.ssh/id_rsa' --ssh-common-args '-o StrictHostKeyChecking=no' --extra-vars ansible_python_interpreter=/usr/bin/python3 --extra-vars 'cloud_provider=${var.cloud_provider}' ../provision.yml"
  }

  depends_on = [
    google_project_service.activate_apis
  ]
}

output "public_ip_address" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}


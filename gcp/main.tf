// Configure the Google Cloud provider
provider "google" {
  credentials = "${file("${var.your_credentials}")}"
  project     = "aswf-gpu-build-agent"
  region      = "${var.region}"
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
  byte_length = 8
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "aswf-gpu-build-${random_id.instance_id.hex}"
  machine_type = "${var.machine_type}"
  zone         = "${var.zone}"
  guest_accelerator { 
    type =  "nvidia-tesla-k80"
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
    ssh-keys = "${var.admin_username}:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling {
    // GPU hosts don't support live migration
    on_host_maintenance = "terminate"
  }

  connection {
    type        = "ssh"
    user        = "${var.admin_username}"
    private_key = "${file("~/.ssh/id_rsa")}"
    host        = "${self.network_interface.0.access_config.0.nat_ip}"
  }
  provisioner "remote-exec" {
    inline = ["sudo apt update && sudo apt -y upgrade && sudo apt install -y python-minimal"]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -u ${var.admin_username} -i '${self.network_interface.0.access_config.0.nat_ip},' --private-key '~/.ssh/id_rsa' --ssh-common-args '-o StrictHostKeyChecking=no' --extra-vars 'azure_pipelines_organization=${var.azure_pipelines_organization}' --extra-vars 'azure_pipelines_token=${var.azure_pipelines_token}' ../provision.yml" 
  }
}

output "public_ip_address" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}


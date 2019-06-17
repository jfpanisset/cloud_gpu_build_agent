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
    ssh-keys = "${var.your_username}:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling {
    // GPU hosts don't support live migration
    on_host_maintenance = "terminate"
  }
}

output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}


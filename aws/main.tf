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

# Configure the AWS Provider
provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.aws_region

  version = "~> 2.35.0"
}

// Network setup based on:
// https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f

resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "tf_vpc"
  }
}

resource "aws_subnet" "my_subnet" {
  cidr_block = cidrsubnet(aws_vpc.my_vpc.cidr_block, 3, 1)
  vpc_id = aws_vpc.my_vpc.id
  availability_zone = var.aws_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "tf_subnet"
  }
}

// Will need inbound ssh for Ansible
// Could be more restrictive if we know IP range from where we run Terraform
resource "aws_security_group" "my_security_group" {
  name = "allow-all-sg"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  // Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf_security_group"
  }
}

resource "aws_network_interface" "my_network_interface" {
  subnet_id   = aws_subnet.my_subnet.id
  security_groups = [aws_security_group.my_security_group.id]

  tags = {
    Name = "tf_network_interface"
  }
}

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "tf_internet_gateway"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }
  tags = {
    Name = "tf_route_table"
  }
}

resource "aws_route_table_association" "my_route_table_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

// FIXME: hard coded Ubuntu version
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "my_key_pair" {
  key_name = var.admin_username
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "my_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.machine_type
  key_name      = aws_key_pair.my_key_pair.key_name

  network_interface {
    network_interface_id = aws_network_interface.my_network_interface.id
    device_index         = 0
  }

  root_block_device {
        volume_size = var.root_volume_size
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
    inline = ["sudo apt update && sudo apt -y upgrade"]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -vv -u ${var.admin_username} -i '${self.public_ip},' --private-key '~/.ssh/id_rsa' --ssh-common-args '-o StrictHostKeyChecking=no' --extra-vars ansible_python_interpreter=/usr/bin/python3 --extra-vars 'cloud_provider=${var.cloud_provider}' ../provision.yml"
  }

  tags = {
    Name = var.prefix
  }
}

output "public_ip" {
  value = aws_instance.my_instance.public_ip
  description = "The public IP address of the GPU instance"
}


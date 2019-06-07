provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

# VPC
resource "aws_vpc" "ml-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags {
    Name = "ml-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ml-igw" {
  vpc_id = "${aws_vpc.ml-vpc.id}"

  tags {
    Name = "ml-igw"
  }
}

# Subnet
resource "aws_subnet" "ml-subnet-public" {
  vpc_id                  = "${aws_vpc.ml-vpc.id}"
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "${var.availability_zone}"
  map_public_ip_on_launch = "true"

  tags {
    Name = "ml-subnet-public"
  }
}

# Route Table
resource "aws_route_table" "ml-route-public" {
  vpc_id = "${aws_vpc.ml-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ml-igw.id}"
  }

  tags {
    Name = "ml-route-table-public"
  }
}

resource "aws_route_table_association" "ml-assoc" {
  subnet_id      = "${aws_subnet.ml-subnet-public.id}"
  route_table_id = "${aws_route_table.ml-route-public.id}"
}

# Security Group
### Web
resource "aws_security_group" "ml-web-sg" {
  name        = "ml-web-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.ml-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]
  }

  # jupyter-notebook用
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ml-web-sg"
  }
}

# Key Pair
resource "aws_key_pair" "ml-key" {
  key_name   = "ml-key"
  public_key = "${var.aws_public_key}"
}

# EC2 Instance
resource "aws_instance" "ml-instance" {
  ami           = "${var.instance_ami}"  # Deep Learning AMI
  instance_type = "${var.instance_type}"

  vpc_security_group_ids = [
    "${aws_security_group.ml-web-sg.id}",
  ]

  subnet_id                   = "${aws_subnet.ml-subnet-public.id}"
  associate_public_ip_address = true                                # not EIP

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.gp2_volume_size}"
  }

  tags {
    Name = "tensolflow-test-instance"
  }

  key_name   = "${aws_key_pair.ml-key.key_name}"
  monitoring = true
}

output "ip" {
  value = "${aws_instance.ml-instance.public_ip}"
}

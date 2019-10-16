# VPC
resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "test_vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "test_igw" {
  vpc_id = "${aws_vpc.test_vpc.id}"

  tags = {
    Name = "test_igw"
  }
}

# Subnet
resource "aws_subnet" "test_subnet_public" {
  vpc_id                  = "${aws_vpc.test_vpc.id}"
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "${var.availability_zone}"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "test_subnet_public"
  }
}

# Route Table
resource "aws_route_table" "test_route_public" {
  vpc_id = "${aws_vpc.test_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test_igw.id}"
  }

  tags = {
    Name = "testroute-table-public"
  }
}

resource "aws_route_table_association" "test_assoc" {
  subnet_id      = "${aws_subnet.test_subnet_public.id}"
  route_table_id = "${aws_route_table.test_route_public.id}"
}

# Security Group
### Web
resource "aws_security_group" "test_web_sg" {
  name        = "test_web_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.test_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "${var.my_ips}"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = "${concat(var.my_ips, var.customer_ips)}"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${concat(var.my_ips, var.customer_ips)}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test_web_sg"
  }
}

# Key Pair
resource "aws_key_pair" "test_key" {
  key_name   = "test_key"
  public_key = "${var.aws_public_key}"
}

# EC2 Instance
resource "aws_instance" "test_instance" {
  ami           = "${var.instance_ami}"
  instance_type = "${var.instance_type}"

  volume_tags = {
    Name     = "test_ebs"
    Snapshot = "true" # for dlm
  }

  vpc_security_group_ids = [
    "${aws_security_group.test_web_sg.id}",
  ]

  subnet_id                   = "${aws_subnet.test_subnet_public.id}"
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.gp2_volume_size}"
  }

  tags = {
    Name = "test_instance"
  }

  key_name   = "${aws_key_pair.test_key.key_name}"
  monitoring = true
}

# EIP
resource "aws_eip" "test_eip" {
  instance = "${aws_instance.test_instance.id}"
  vpc      = true

  tags = {
    Name = "test_eip"
  }
}

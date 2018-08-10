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
  count                   = "${length(var.availability_zones)}"
  vpc_id                  = "${aws_vpc.ml-vpc.id}"
  cidr_block              = "${format("10.1.%d.0/24", count.index + 1)}"
  availability_zone       = "${lookup(var.availability_zones, count.index)}"
  map_public_ip_on_launch = "true"

  tags {
    Name = "${format("ml-subnet-public-%d", count.index + 1)}"
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
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.ml-subnet-public.*.id, count.index)}"
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

data "aws_caller_identity" "current" {}

# Spot Fleet Request
resource "aws_spot_fleet_request" "ml-spot-request" {
  iam_fleet_role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-ec2-spot-fleet-tagging-role"

  # spot_price      = "0.1290" # Max Price デフォルトはOn-demand Price
  target_capacity                     = "${var.spot_target_capacity}"
  terminate_instances_with_expiration = true
  wait_for_fulfillment                = "true"                        # fulfillするまでTerraformが待つ

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.ml-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.ml-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.ml-subnet-public.*.id, 0)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size = "${var.gp2_volume_size}"
      volume_type = "gp2"
    }

    tags {
      Name = "ml-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.ml-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.ml-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.ml-subnet-public.*.id, 1)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size = "${var.gp2_volume_size}"
      volume_type = "gp2"
    }

    tags {
      Name = "ml-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.ml-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.ml-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.ml-subnet-public.*.id, 2)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size = "${var.gp2_volume_size}"
      volume_type = "gp2"
    }

    tags {
      Name = "ml-instance"
    }
  }
}

data "aws_instance" "ml-instance" {
  filter {
    name   = "tag:Name"
    values = ["ml-instance"]
  }

  depends_on = ["aws_spot_fleet_request.ml-spot-request"]
}

output "ip" {
  value      = "${data.aws_instance.ml-instance.public_ip}"
  depends_on = ["aws_spot_fleet_request.ml-spot-request"]
}

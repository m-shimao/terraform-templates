provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

# IAMロール
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["spotfleet.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "spot-fleet-role" {
  name               = "c5-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_policy_attachment" "policy-attach" {
  name       = "c5-role-policy"
  roles      = ["${aws_iam_role.spot-fleet-role.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# VPC
resource "aws_vpc" "c5-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags {
    Name = "c5-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "c5-igw" {
  vpc_id = "${aws_vpc.c5-vpc.id}"

  tags {
    Name = "c5-igw"
  }
}

# Subnet
resource "aws_subnet" "c5-subnet-public" {
  count                   = "${length(var.availability_zones)}"
  vpc_id                  = "${aws_vpc.c5-vpc.id}"
  cidr_block              = "${format("10.1.%d.0/24", count.index + 1)}"
  availability_zone       = "${lookup(var.availability_zones, count.index)}"
  map_public_ip_on_launch = "true"

  tags {
    Name = "${format("c5-subnet-public-%d", count.index + 1)}"
  }
}

# Route Table
resource "aws_route_table" "c5-route-public" {
  vpc_id = "${aws_vpc.c5-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.c5-igw.id}"
  }

  tags {
    Name = "c5-route-table-public"
  }
}

resource "aws_route_table_association" "c5-assoc" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.c5-subnet-public.*.id, count.index)}"
  route_table_id = "${aws_route_table.c5-route-public.id}"
}

# Security Group
### Web
resource "aws_security_group" "c5-web-sg" {
  name        = "c5-web-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.c5-vpc.id}"

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
    Name = "c5-web-sg"
  }
}

# Key Pair
resource "aws_key_pair" "c5-key" {
  key_name   = "c5-key"
  public_key = "${var.aws_public_key}"
}

data "aws_caller_identity" "current" {}

# Spot Fleet Request
resource "aws_spot_fleet_request" "c5-spot-request" {
  iam_fleet_role = "${aws_iam_role.spot-fleet-role.arn}"

  # spot_price      = "0.1290" # Max Price デフォルトはOn-demand Price
  target_capacity                     = "${var.spot_target_capacity}"
  terminate_instances_with_expiration = true
  wait_for_fulfillment                = "true"                        # fulfillするまでTerraformが待つ

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.c5-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.c5-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.c5-subnet-public.*.id, 0)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp2_root_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = true
    }

    ebs_block_device {
      device_name           = "c5-data-volume"
      volume_size           = "${var.gp2_data_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = false
    }

    tags {
      Name = "c5-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.c5-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.c5-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.c5-subnet-public.*.id, 1)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp2_root_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = true
    }

    ebs_block_device {
      device_name           = "c5-data-volume"
      volume_size           = "${var.gp2_data_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = false
    }

    tags {
      Name = "c5-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.c5-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.c5-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.c5-subnet-public.*.id, 2)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp2_root_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = true
    }

    ebs_block_device {
      device_name           = "c5-data-volume"
      volume_size           = "${var.gp2_data_volume_size}"
      volume_type           = "gp2"
      delete_on_termination = false
    }

    tags {
      Name = "c5-instance"
    }
  }
}

data "aws_instance" "c5-instance" {
  filter {
    name   = "tag:Name"
    values = ["c5-instance"]
  }

  depends_on = ["aws_spot_fleet_request.c5-spot-request"]
}

output "ip" {
  value      = "${data.aws_instance.c5-instance.public_ip}"
  depends_on = ["aws_spot_fleet_request.c5-spot-request"]
}

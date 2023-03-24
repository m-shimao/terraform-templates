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
  name               = "shimao-demo-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_policy_attachment" "policy-attach" {
  name       = "shimao-demo-role-policy"
  roles      = ["${aws_iam_role.spot-fleet-role.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# VPC
resource "aws_vpc" "shimao-demo-vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "shimao-demo-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "shimao-demo-igw" {
  vpc_id = "${aws_vpc.shimao-demo-vpc.id}"

  tags = {
    Name = "shimao-demo-igw"
  }
}

# Subnet
resource "aws_subnet" "shimao-demo-subnet-public" {
  count                   = "${length(var.availability_zones)}"
  vpc_id                  = "${aws_vpc.shimao-demo-vpc.id}"
  cidr_block              = "${format("10.1.%d.0/24", count.index + 1)}"
  availability_zone       = "${lookup(var.availability_zones, count.index)}"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${format("shimao-demo-subnet-public-%d", count.index + 1)}"
  }
}

# Route Table
resource "aws_route_table" "shimao-demo-route-public" {
  vpc_id = "${aws_vpc.shimao-demo-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.shimao-demo-igw.id}"
  }

  tags = {
    Name = "shimao-demo-route-table-public"
  }
}

resource "aws_route_table_association" "shimao-demo-assoc" {
  count          = "${length(var.availability_zones)}"
  subnet_id      = "${element(aws_subnet.shimao-demo-subnet-public.*.id, count.index)}"
  route_table_id = "${aws_route_table.shimao-demo-route-public.id}"
}

# Security Group
### Web
resource "aws_security_group" "shimao-demo-web-sg" {
  name        = "shimao-demo-web-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.shimao-demo-vpc.id}"

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

  tags = {
    Name = "shimao-demo-web-sg"
  }
}

# Key Pair
resource "aws_key_pair" "shimao-demo-key" {
  key_name   = "shimao-demo-key"
  public_key = "${var.aws_public_key}"
}

data "aws_caller_identity" "current" {}

# Spot Fleet Request
resource "aws_spot_fleet_request" "shimao-demo-spot-request" {
  iam_fleet_role = "${aws_iam_role.spot-fleet-role.arn}"
  target_capacity                     = "${var.spot_target_capacity}"
  terminate_instances_with_expiration = true
  wait_for_fulfillment                = "true"                        # fulfillするまでTerraformが待つ
  allocation_strategy                 = "lowestPrice"
  fleet_type                          = "request"

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.shimao-demo-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.shimao-demo-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.shimao-demo-subnet-public.*.id, 0)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp3_volume_size}"
      volume_type           = "gp3"
      delete_on_termination = false
    }

    tags = {
      Name = "shimao-demo-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.shimao-demo-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.shimao-demo-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.shimao-demo-subnet-public.*.id, 1)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp3_volume_size}"
      volume_type           = "gp3"
      delete_on_termination = false
    }

    tags = {
      Name = "shimao-demo-instance"
    }
  }

  launch_specification {
    ami                         = "${var.spot_instance_ami}"
    instance_type               = "${var.spot_instance_type}"
    key_name                    = "${aws_key_pair.shimao-demo-key.key_name}"
    vpc_security_group_ids      = ["${aws_security_group.shimao-demo-web-sg.id}"]
    subnet_id                   = "${element(aws_subnet.shimao-demo-subnet-public.*.id, 2)}"
    associate_public_ip_address = true

    root_block_device {
      volume_size           = "${var.gp3_volume_size}"
      volume_type           = "gp3"
      delete_on_termination = false
    }

    tags = {
      Name = "shimao-demo-instance"
    }
  }
}

data "aws_instance" "shimao-demo-instance" {
  filter {
    name   = "tag:Name"
    values = ["shimao-demo-instance"]
  }

  depends_on = ["aws_spot_fleet_request.shimao-demo-spot-request"]
}

output "ip" {
  value      = "${data.aws_instance.shimao-demo-instance.public_ip}"
  depends_on = ["aws_spot_fleet_request.shimao-demo-spot-request"]
}

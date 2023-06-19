terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "default"
}

data "aws_ami" "ml-gpu-ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning AMI GPU PyTorch*Ubuntu*"]
  }
}

resource "aws_iam_policy" "s3-policy" {
  name = "shimao-s3-access-role-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.my_bucket_name}/*"
      },
      {
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:ListBucket",
          "s3:GetBucketLocation"

        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.my_bucket_name}"
      },
    ]
  })
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "access-role" {
  name               = "shimao-demo-access-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "s3-policy-attach" {
  role       = aws_iam_role.access-role.id
  policy_arn = aws_iam_policy.s3-policy.arn
}


# VPC
resource "aws_vpc" "shimao-demo2-vpc" {
  cidr_block           = "10.2.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "shimao-demo2-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "shimao-demo2-igw" {
  vpc_id = aws_vpc.shimao-demo2-vpc.id

  tags = {
    Name = "shimao-demo2-igw"
  }
}

# Subnet
resource "aws_subnet" "shimao-demo2-subnet-public" {
  vpc_id                  = aws_vpc.shimao-demo2-vpc.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = "true"

  tags = {
    Name = "shimao-demo2-subnet-public"
  }
}

# Route Table
resource "aws_route_table" "shimao-demo2-route-public" {
  vpc_id = aws_vpc.shimao-demo2-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shimao-demo2-igw.id
  }

  tags = {
    Name = "shimao-demo2-route-table-public"
  }
}

resource "aws_route_table_association" "shimao-demo2-assoc" {
  subnet_id      = aws_subnet.shimao-demo2-subnet-public.id
  route_table_id = aws_route_table.shimao-demo2-route-public.id
}

# Security Group
### Web
resource "aws_security_group" "shimao-demo2-web-sg" {
  name        = "shimao-demo2-web-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.shimao-demo2-vpc.id

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
    Name = "shimao-demo2-web-sg"
  }
}

# Key Pair
resource "aws_key_pair" "shimao-demo2-key" {
  key_name   = "shimao-demo2-key"
  public_key = file(var.ssh_pub_path)
}

resource "aws_iam_instance_profile" "instance-role" {
  name = "shimao-demo-instance-role"
  role = aws_iam_role.access-role.name
}

resource "aws_spot_instance_request" "shimao-demo2-spot-request" {
  ami                  = data.aws_ami.ml-gpu-ubuntu.id
  instance_type        = var.spot_instance_type
  spot_type            = var.spot_type
  wait_for_fulfillment = "true"
  key_name             = aws_key_pair.shimao-demo2-key.key_name
  security_groups      = ["${aws_security_group.shimao-demo2-web-sg.id}"]
  subnet_id            = aws_subnet.shimao-demo2-subnet-public.id
  iam_instance_profile = aws_iam_instance_profile.instance-role.id
  count                = var.spot_instance == "true" ? 1 : 0

  root_block_device {
    volume_size           = var.gp3_volume_size
    volume_type           = "gp3"
    delete_on_termination = false
    tags = {
      Owner = "shimao"
    }
  }

  tags = {
    Name = "shimao-demo2-instance"
  }
}

resource "aws_instance" "shimao-demo2-instance" {
  ami                         = data.aws_ami.ml-gpu-ubuntu.id
  instance_type               = var.spot_instance_type
  key_name                    = aws_key_pair.shimao-demo2-key.key_name
  subnet_id                   = aws_subnet.shimao-demo2-subnet-public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.shimao-demo2-web-sg.id}"]
  iam_instance_profile        = aws_iam_instance_profile.instance-role.id
  count                       = var.spot_instance == "true" ? 0 : 1

  root_block_device {
    volume_size           = var.gp3_volume_size
    volume_type           = "gp3"
    delete_on_termination = false
  }

  tags = {
    Name = "shimao-demo2-instance"
    Owner = "shimao"
  }
}

# resource "aws_spot_instance_request" "shimao-demo-spot-request-copy" {
#   ami                  = "ami-0d55bdef84fcb0750"
#   instance_type        = var.spot_instance_type
#   spot_type            = var.spot_type
#   wait_for_fulfillment = "true"
#   key_name             = aws_key_pair.shimao-demo2-key.key_name
#   security_groups      = ["${aws_security_group.shimao-demo2-web-sg.id}"]
#   subnet_id            = aws_subnet.shimao-demo2-subnet-public.id
#
#   root_block_device {
#     volume_size           = var.gp3_volume_size
#     volume_type           = "gp3"
#     delete_on_termination = false
#     tags = {
#       Owner = "shimao"
#     }
#   }
#
#   tags = {
#     Name = "shimao-demo2-instance-copy1"
#   }
# }

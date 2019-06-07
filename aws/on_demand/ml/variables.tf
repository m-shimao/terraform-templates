variable "my_ip_address" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_public_key" {}

variable "region" {
  default = "us-west-2"
}

variable "availability_zone" {
  default = "us-west-2a"
}

variable "instance_ami" {
  default = "ami-058f26d848e91a4e8" # Deep Learning AMI (Ubuntu) Version 23.0
}

variable "instance_type" {
  default = "p2.xlarge"
}

variable "gp2_volume_size" {
  default = "100"
}

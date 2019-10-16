variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_public_key" {}

variable "my_ips" {
  default = [
  ]
}

variable "customer_ips" {
  default = [
  ]
}

variable "region" {
  default = "us-west-2"
}

variable "availability_zone" {
  default = "us-west-2b"
}

variable "instance_ami" {
  default = "ami-04b762b4289fba92b" # Amazon Linux 2
}

variable "instance_type" {
  default = "t3a.nano"
}

variable "gp2_volume_size" {
  default = "20"
}

variable "my_ip_address" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_public_key" {}

variable "region" {
  default = "us-west-2"
}

variable "availability_zones" {
  default = {
    "0" = "us-west-2a"
    "1" = "us-west-2b"
    "2" = "us-west-2c"
  }
}

variable "spot_instance_ami" {
  default = "ami-089f21a8142e2195b" # Deep Learning AMI (Ubuntu) Version 14.0
}

variable "spot_instance_type" {
  default = "c5.4xlarge"
}

variable "spot_target_capacity" {
  default = "1"
}

variable "gp2_root_volume_size" {
  default = "75"
}

variable "gp2_data_volume_size" {
  default = "500"
}

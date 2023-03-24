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
  default = "ami-02c662a26e55f3144"
}

variable "spot_instance_type" {
  default = "g5.2xlarge"
}

variable "spot_target_capacity" {
  default = "1"
}

variable "gp3_volume_size" {
  default = "120"
}

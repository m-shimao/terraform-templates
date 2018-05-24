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
  default = "ami-0faada77" # Deep Learning AMI (Ubuntu) Version 9.0
}
variable "spot_instance_type" {
  default = "p2.xlarge"
}
variable "spot_target_capacity" {
  default = "1"
}
variable "gp2_volume_size" {
  default = "100"
}

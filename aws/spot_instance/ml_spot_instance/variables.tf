variable "my_ip_address" {}

variable "region" {
  default = "us-west-2"
}

variable "ssh_pub_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "availability_zone" {
  default = "us-west-2c"
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

variable "spot_price" {
  type        = string
  default     = "1.3"
  description = "Maximum price to pay for spot instance"
}

variable "spot_type" {
  type        = string
  default     = "one-time"
  description = "Spot instance type, this value only applies for spot instance type."
}

variable "spot_instance" {
  type        = string
  default     = "true"
  description = "This value is true if we want to use a spot instance instead of a regular one"
}

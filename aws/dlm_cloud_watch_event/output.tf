output "test_instance_public_ip" {
  value = "${aws_eip.test_eip.public_ip}"
}

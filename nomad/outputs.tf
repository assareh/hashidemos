output "nomad_server_http" {
  value = "http://${aws_instance.bastion.public_ip}:4646"
}

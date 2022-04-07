output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh" {
  value = "ssh -i ${local.private_key_filename} -o IdentitiesOnly=yes ubuntu@${aws_instance.bastion.public_ip}"
}

output "consul_local_bind" {
  value = "https://localhost:9091/ui/"
}

output "consul_private_endpoint_url" {
  value = hcp_consul_cluster.primary.consul_private_endpoint_url
}

output "consul_ssh_tunnel" {
  value = "ssh -i ${local.private_key_filename} -o IdentitiesOnly=yes ubuntu@${aws_instance.bastion.public_ip} -L 9091:${trimprefix(hcp_consul_cluster.primary.consul_private_endpoint_url, "https://")}:443"
}

output "consul_token" {
  value = nonsensitive(hcp_consul_cluster.primary.consul_root_token_secret_id)
}

output "consul_version" {
  value = hcp_consul_cluster.primary.consul_version
}

output "ssh_key" {
  value = nonsensitive(tls_private_key.bastion_ssh_key.private_key_pem)
}

output "vault_local_bind" {
  value = "https://localhost:9090/ui/vault/auth?namespace=admin&with=token"
}

output "vault_private_endpoint_url" {
  value = hcp_vault_cluster.primary.vault_private_endpoint_url
}

output "vault_ssh_tunnel" {
  value = "ssh -i ${local.private_key_filename} -o IdentitiesOnly=yes ubuntu@${aws_instance.bastion.public_ip} -L 9090:${trimprefix(hcp_vault_cluster.primary.vault_private_endpoint_url, "https://")}"
}

output "vault_token" {
  value = nonsensitive(hcp_vault_cluster_admin_token.admin.token)
}

output "vault_version" {
  value = hcp_vault_cluster.primary.vault_version
}

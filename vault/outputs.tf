output "nomad_vault_token" {
  value = nonsensitive(vault_token.nomad-server.client_token)
}

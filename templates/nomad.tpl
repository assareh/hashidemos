#!/bin/bash

# The purpose of this script is to configure and start Consul and Nomad.

# Capture and redirect
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/${ssh_username}/setup_nomad.log 2>&1

# Everything below will go to the file 'setup_nomad.log':

# Print executed commands for debugging
set -x

# Set hostname because it's used for Consul and Nomad names
sudo hostnamectl set-hostname nomad-server
echo '127.0.1.1       nomad-server.unassigned-domain        nomad-server' | sudo tee -a /etc/hosts

# Create the Consul config
%{ if consul_ca_file != "" }
echo '${consul_ca_file}' | base64 -d > /etc/consul.d/ca.pem
%{ endif }

%{ if consul_config_file != "" }
echo '${consul_config_file}' | base64 -d > /etc/consul.d/config.json
%{ endif }

echo '{"ca_file":"/etc/consul.d/ca.pem", "acl":{"tokens":{"default":"${consul_token}"}}}' > /etc/consul.d/overrides.json

# Set permissions
sudo mv /home/${ssh_username}/consul.hcl /etc/consul.d/consul.hcl
sudo chown -R consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/*

# Start Consul
sudo systemctl enable consul
sudo systemctl start consul

# Save Nomad license
echo ${nomad_license} | sudo tee -a /etc/nomad.d/license.hclic

# Auth to Vault
sed -i 's|VAULT_ADDR|${vault_addr}|g' /home/${ssh_username}/vault-agent-bootstrap.hcl
cd /home/${ssh_username} && vault agent -config vault-agent-bootstrap.hcl

# Save Vault token for Nomad
mv vault-token-via-agent /home/${ssh_username}/nomad.env
sed -i '1s/^/VAULT_TOKEN=/' /home/${ssh_username}/nomad.env
sudo mv /home/${ssh_username}/nomad.env /etc/nomad.d/nomad.env

# Save Vault cluster address in Nomad config
sed -i 's|VAULT_ADDR|${vault_addr}|g' /home/${ssh_username}/nomad.hcl
sudo mv /home/${ssh_username}/nomad.hcl /etc/nomad.d/.

# Set permissions
sudo chown -R nomad:nomad /etc/nomad.d
sudo chmod 640 /etc/nomad.d/nomad.hcl /etc/nomad.d/license.hclic
sudo chmod 400 /etc/nomad.d/nomad.env

# Start Nomad
sudo systemctl enable nomad
sudo systemctl start nomad

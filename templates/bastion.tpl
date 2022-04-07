#!/bin/bash

# The purpose of this script is to configure and start Consul,
# and configure the environment with addresses and things.

# Capture and redirect
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/${ssh_username}/setup_bastion.log 2>&1

# Everything below will go to the file 'setup_bastion.log':

# Print executed commands for debugging
set -x

# Set hostname because it's used for Consul
sudo hostnamectl set-hostname hashidemos-bastion
echo '127.0.1.1       hashidemos-bastion.unassigned-domain        hashidemos-bastion' | sudo tee -a /etc/hosts

# Create the Consul config
%{ if consul_ca_file != "" }
echo '${consul_ca_file}' | base64 -d > /etc/consul.d/ca.pem
%{ endif }

%{ if consul_config_file != "" }
echo '${consul_config_file}' | base64 -d > /etc/consul.d/config.json
%{ endif }

echo '{"ca_file":"/etc/consul.d/ca.pem", "acl":{"tokens":{"default":"${consul_token}"}}}' > /etc/consul.d/overrides.json

# Set permissions
sudo chown -R consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/*

# Start Consul
sudo systemctl enable consul
sudo systemctl start consul

# Configure environment
echo export VAULT_ADDR="${vault_addr}" | sudo tee -a /home/${ssh_username}/.bashrc
echo export VAULT_TOKEN="${vault_token}" | sudo tee -a /home/${ssh_username}/.bashrc

# Run a Terraform Cloud Agent
sudo docker run -d -e TFC_AGENT_TOKEN=${tfc_agent_token} -e TFC_AGENT_NAME=ec2 hashicorp/tfc-agent:latest

# Save the private key (can remove once Boundary is in place)
echo '${private_key}' | sudo tee -a /home/${ssh_username}/bastion-ssh-key.pem
chmod 400 /home/${ssh_username}/bastion-ssh-key.pem
#!/bin/bash

# The purpose of this script is to configure and start Consul and Nomad.

# Capture and redirect
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/${ssh_username}/setup_worker.log 2>&1

# Everything below will go to the file 'setup_worker.log':

# Print executed commands for debugging
set -x

# Create the Consul config
%{ if consul_ca_file != "" }
echo '${consul_ca_file}' | base64 -d > /etc/consul.d/ca.pem
%{ endif }

%{ if consul_config_file != "" }
echo '${consul_config_file}' | base64 -d > /etc/consul.d/config.json
%{ endif }

echo '{"ca_file":"/etc/consul.d/ca.pem", "acl":{"tokens":{"default":"${consul_token}"}}}' > /etc/consul.d/overrides.json

# Set permissions
sudo mv /home/${ssh_username}/consul.hcl /etc/consul.d/consul_bind.hcl
sudo chown -R consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/*

# Start Consul
sudo systemctl enable consul
sudo systemctl start consul

# Create the Nomad config
cat <<EOF >/home/${ssh_username}/nomad.hcl
# Full configuration options can be found at https://www.nomadproject.io/docs/configuration

advertise {
  http = "{{ GetInterfaceIP \`ens5\` }}"
  rpc  = "{{ GetInterfaceIP \`ens5\` }}"
  serf = "{{ GetInterfaceIP \`ens5\` }}"
}

bind_addr = "0.0.0.0"

client {
  enabled = true
  servers = ["${nomad_addr}:4647"]
}

data_dir = "/opt/nomad/data"

leave_on_terminate = true

log_level = "INFO"
EOF

sudo mv /home/${ssh_username}/nomad.hcl /etc/nomad.d/.

# Save Nomad license
echo ${nomad_license} | sudo tee -a /etc/nomad.d/license.hclic

# Set permissions
sudo chown -R nomad:nomad /etc/nomad.d
sudo chmod 640 /etc/nomad.d/nomad.hcl /etc/nomad.d/license.hclic

# Start Nomad
sudo systemctl enable nomad
sudo systemctl start nomad

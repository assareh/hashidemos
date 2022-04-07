# Hashidemos

This is intended to be a complete Hashistack demo environment.
- Packer and HCP Packer are used to create and publish machine images.
- Terraform Cloud for Business is used to provision the infrastructure.
- HCP Consul is used to provide service discovery and service mesh across clouds.
- HCP Vault is used to provide secrets management.
- Nomad is used to schedule application workloads on pools of worker nodes.
- HCP Boundary is used to provide secure access to servers and worker nodes.
- HCP Waypoint is used to deploy an application.

## control plane infrastructure
- HCP vault and consul clusters with lifecycle prevent destroy
- Nomad server EC2 depends on those
- create VPCs in Azure and GCP and VPNs (refer to the HCP GCP AWS demo repo for networking and example)
- create node pools of workers

## control workspace
- this workspace creates the control plane infra, plus a hashidemos-vault workspace for vault provider

TODO
- Nomad is broken until I can figure out HCP Consul TLS client certs
- k3s and consul admin partitions
- sample application(s) with a database (transit-app-example, hashicups, etc)
- perhaps give nomad server a dns record
- packer pipeline somewhere so it has aws access, and have a base then app specific
- lock down NSGs
- get DNS forwarded to consul
- i think ip address outputs need to be on data sources so they stay up to date
- maybe use mitchell's multi workspace provider
- tags not propogating to aws workers for some reason
- nomad dc#, TLS and ACLs
- document and diagram
- should be able to estimate the costs to a certain extent

## prerequisites / steps
- [Packer](https://github.com/assareh/packer) has been run
- Configure [HCP Packer run task]() on this workspace
- Configure [prevent workspace delete]() sentinel policy on this workspace
- nomad enterprise license, other tfvars
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration), [HCP](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs#authenticating-with-hcp), [TFC](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs#authentication) credentials
Note the TFE_TOKEN environment variable must be a user or team token.

## notes
- You will need to save the contents of the `ssh_key` terraform output as `bastion-ssh-key.pem` on your local machine.
# -------------------- variables without defaults -------------------->
variable "allowed-source-ip" {
  description = "Your IP address to allow traffic from in CIDR notation."
}

variable "nomad_license" {
  description = "Nomad Enterprise license from HashiCorp."
  type        = string
}

variable "oauth_token" {}

variable "org" {}

variable "owner" {
  description = "Your name here, this is used to tag resources."
  type        = string
}

// variable "prefix" {
//   description = "This prefix will be included in the name of most resources."
// }

variable "se-region" {
  description = "Your region assignment here, this is used to tag resources. NOT cloud region"
  type        = string
  default     = null
}

# -------------------- the rest -------------------->

variable "hcp_packer_channel" {
  default = "devtest"
}

variable "aws_tgw_bgp_asn" {
  description = "BGP ASN that will be configured on the AWS Transit Gateway. Defaults to 64512"
  default     = 64512
  type        = number
}

variable "aws_hcp_tgw_ram_name" {
  description = "Name of the AWS RAM that will be created to allow resource sharing between accounts"
  type        = string
  default     = "hcp-vault-ram"
}

variable "transit_gw_attachment_id" {
  description = "Name of the transit gateway attachment for collapsed network in HVN"
  type        = string
  default     = "hcp-hvn-transit-gw"
}

variable "hvn_route_id" {
  description = "The ID of the HCP HVN route."
  type        = string
  default     = "hcp-hvn-route"
}

variable "purpose" {
  type    = string
  default = "Demo HashiStack"
}

variable "terraform" {
  type    = string
  default = "true"
}

variable "ttl" {
  type    = string
  default = "-1"
}
variable "ssh_username" {
  type    = string
  default = "ubuntu"
}


// Tags
locals {
  common_tags = {
    owner     = "${var.owner}"
    purpose   = "${var.purpose}"
    se-region = "${var.se-region}"
    terraform = "${var.terraform}" # true/false
    ttl       = "${var.ttl}"       # hours
  }

  private_key_filename = "bastion-ssh-key.pem"
}

variable "ip_cidr_hvn" {
  description = "IP CIDR for HashiCorp Virtual Network"
  default     = "172.25.16.0/20"
}


variable "hcp_region" {
  description = "The region where the resources are created."
  default     = "us-west-2"
}

variable "aws_region" {
  description = "The region where the resources are created."
  default     = "us-west-2"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t3a.small"
}

variable "admin_username" {
  description = "Administrator user name for mysql"
  default     = "hashicorp"
}

variable "height" {
  default     = "400"
  description = "Image height in pixels."
}

variable "width" {
  default     = "600"
  description = "Image width in pixels."
}

variable "placeholder" {
  default     = "placekitten.com"
  description = "Image-as-a-service URL. Some other fun ones to try are fillmurray.com, placecage.com, placebeard.it, loremflickr.com, baconmockup.com, placeimg.com, placebear.com, placeskull.com, stevensegallery.com, placedog.net"
}

variable "hcp_vault_tier" {
  default     = "dev"
  description = "HCP Vault tier"
}

variable "hcp_vault_public" {
  default     = false
  description = "Make HCP Vault cluster public"
}

variable "hcp_consul_tier" {
  default     = "development"
  description = "HCP Consul tier"
}

variable "hcp_consul_public" {
  default     = false
  description = "Make HCP Consul cluster public"
}

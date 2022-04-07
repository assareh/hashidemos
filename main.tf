resource "tls_private_key" "bastion_ssh_key" {
  algorithm = "RSA"
}

# -------------------- HCP resources -------------------->
# create an hvn
# attach it to a transit gateway
# create a consul cluster
# create a vault cluster

resource "hcp_hvn" "primary" {
  cidr_block     = var.ip_cidr_hvn
  cloud_provider = "aws"
  hvn_id         = "hashidemos-primary"
  region         = var.hcp_region
}

resource "aws_ram_principal_association" "hcp_aws_ram" {
  principal          = hcp_hvn.primary.provider_account_id
  resource_share_arn = aws_ram_resource_share.hcp_ram.arn
}

resource "hcp_aws_transit_gateway_attachment" "hvn_transit_gw" {
  hvn_id                        = hcp_hvn.primary.hvn_id
  resource_share_arn            = aws_ram_resource_share.hcp_ram.arn
  transit_gateway_attachment_id = var.transit_gw_attachment_id
  transit_gateway_id            = aws_ec2_transit_gateway.hashidemos.id
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "hvn_aws_tgw_accept" {
  transit_gateway_attachment_id = hcp_aws_transit_gateway_attachment.hvn_transit_gw.provider_transit_gateway_attachment_id
}

resource "hcp_hvn_route" "hvn_tgw_route" {
  destination_cidr = var.address_space
  hvn_link         = hcp_hvn.primary.self_link
  hvn_route_id     = var.hvn_route_id
  target_link      = hcp_aws_transit_gateway_attachment.hvn_transit_gw.self_link
}

resource "hcp_consul_cluster" "primary" {
  cluster_id      = "hashidemos-primary"
  hvn_id          = hcp_hvn.primary.hvn_id
  public_endpoint = var.hcp_consul_public
  tier            = var.hcp_consul_tier

  // lifecycle {
  //   prevent_destroy = true
  // }
}

resource "hcp_vault_cluster" "primary" {
  cluster_id      = "hashidemos-primary"
  hvn_id          = hcp_hvn.primary.hvn_id
  public_endpoint = var.hcp_vault_public
  tier            = var.hcp_vault_tier

  // lifecycle {
  //   prevent_destroy = true
  // }
}

resource "hcp_vault_cluster_admin_token" "admin" {
  cluster_id = hcp_vault_cluster.primary.cluster_id
}

# -------------------- AWS resources -------------------->
# create a vpc, subnet, transit gateway, etc
# create a bastion host
# create a tfc-agent host and associated iam instance profile
# create an iam user for vault aws auth method to use

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

resource "aws_vpc" "hashidemos" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true
}

resource "aws_subnet" "hashidemos" {
  cidr_block = var.subnet_prefix
  vpc_id     = aws_vpc.hashidemos.id
}

resource "aws_ec2_transit_gateway" "hashidemos" {
  amazon_side_asn                 = var.aws_tgw_bgp_asn
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hashidemos" {
  subnet_ids         = [aws_subnet.hashidemos.id]
  transit_gateway_id = aws_ec2_transit_gateway.hashidemos.id
  vpc_id             = aws_vpc.hashidemos.id
}

# creates a resource access manager for sharing the tgw across accounts
resource "aws_ram_resource_share" "hcp_ram" {
  allow_external_principals = true
  name                      = var.aws_hcp_tgw_ram_name
}

# associates the resource access manager arn with the tgw arn
resource "aws_ram_resource_association" "hcp_ram_asc" {
  resource_arn       = aws_ec2_transit_gateway.hashidemos.arn
  resource_share_arn = aws_ram_resource_share.hcp_ram.arn
}

resource "aws_security_group" "hashidemos" {
  name   = "hashidemos-security-group"
  vpc_id = aws_vpc.hashidemos.id

  ingress {
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
    from_port   = -1
    to_port     = -1
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed-source-ip]
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["10.0.0.0/8", var.ip_cidr_hvn]
    prefix_list_ids = []
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
}

resource "aws_internet_gateway" "hashidemos" {
  vpc_id = aws_vpc.hashidemos.id
}

resource "aws_route_table" "hashidemos" {
  vpc_id = aws_vpc.hashidemos.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hashidemos.id
  }

  route {
    cidr_block         = var.ip_cidr_hvn
    transit_gateway_id = aws_ec2_transit_gateway.hashidemos.id
  }
}

resource "aws_route_table_association" "hashidemos" {
  route_table_id = aws_route_table.hashidemos.id
  subnet_id      = aws_subnet.hashidemos.id
}

resource "aws_key_pair" "hashidemos" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.bastion_ssh_key.public_key_openssh
}

data "hcp_packer_iteration" "hashidemos" {
  bucket_name = "hashidemos"
  channel     = var.hcp_packer_channel
}

data "hcp_packer_image" "hashidemos" {
  bucket_name    = "hashidemos"
  cloud_provider = "aws"
  iteration_id   = data.hcp_packer_iteration.hashidemos.ulid
  region         = var.aws_region
}

resource "aws_instance" "bastion" {
  ami                         = data.hcp_packer_image.hashidemos.cloud_image_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.agent.name
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashidemos.key_name
  subnet_id                   = aws_subnet.hashidemos.id
  vpc_security_group_ids      = [aws_security_group.hashidemos.id]

  user_data = templatefile("${path.module}/templates/bastion.tpl", {
    consul_http_addr   = hcp_consul_cluster.primary.consul_private_endpoint_url
    consul_ca_file     = hcp_consul_cluster.primary.consul_ca_file
    consul_config_file = hcp_consul_cluster.primary.consul_config_file
    consul_token       = hcp_consul_cluster.primary.consul_root_token_secret_id
    ssh_username       = var.ssh_username
    tfc_agent_token    = tfe_agent_token.aws.token
    vault_addr         = hcp_vault_cluster.primary.vault_private_endpoint_url
    vault_token        = hcp_vault_cluster_admin_token.admin.token
  })
}

resource "aws_iam_instance_profile" "agent" {
  name = "hashidemos-tfc-agent-profile"
  role = aws_iam_role.agent.name
}

resource "aws_iam_role" "agent" {
  name               = "hashidemos-tfc-agent-role"
  assume_role_policy = data.aws_iam_policy_document.agent_assume_role_policy_definition.json
}

resource "aws_iam_role_policy_attachment" "agent_ec2_role_attach" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

data "aws_iam_policy_document" "agent_assume_role_policy_definition" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

// resource "aws_iam_role_policy" "agent_policy" {
//   name = "${var.prefix}-ecs-tfc-agent-policy"
//   role = aws_iam_role.agent.id

//   policy = data.aws_iam_policy_document.agent_policy_definition.json
// }

// data "aws_iam_policy_document" "agent_policy_definition" {
//   statement {
//     effect    = "Allow"
//     actions   = ["sts:AssumeRole"]
//     resources = [aws_iam_role.terraform_dev_role.arn]
//   }
// }

// resource "aws_iam_role_policy_attachment" "agent_task_policy" {
//   role       = aws_iam_role.agent.name
//   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
// }

// data "aws_iam_policy_document" "dev_assume_role_policy_definition" {
//   statement {
//     effect  = "Allow"
//     actions = ["sts:AssumeRole"]
//     principals {
//       identifiers = ["ecs-tasks.amazonaws.com"]
//       type        = "Service"
//     }
//     principals {
//       identifiers = [aws_iam_role.agent.arn]
//       type        = "AWS"
//     }
//   }
// }

locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

provider "aws" {
  alias  = "sanstags"
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "VaultDemoPermissionsBoundary"
}

resource "aws_iam_user" "demo_user" {
  provider = aws.sanstags

  name = format(
    "vault-%s-hcp-aws-auth-backend-demo",
    split("@", local.my_email)[0]
  )

  tags = { vault-demo : local.my_email } # this is required; no others allowed

  permissions_boundary = data.aws_iam_policy.permissions_boundary.arn
}

resource "aws_iam_user_policy" "demo_user" {
  name   = "AWSEC2VaultAuth"
  user   = aws_iam_user.demo_user.name
  policy = data.aws_iam_policy_document.demo_user.json
}

data "aws_iam_policy_document" "demo_user" {
  statement {
    actions   = ["ec2:DescribeInstances", "iam:GetInstanceProfile"]
    resources = ["*"]
  }
}

resource "aws_iam_access_key" "vault" {
  user    = aws_iam_user.demo_user.name
}

# -------------------- TFC resources -------------------->
# create a remote agent
# create a workspace for vault provider stuffs
# create a workspace for consul provider stuffs
# create a workspace for nomad server
# create workspaces of worker nodes

provider "tfe" {
}

resource "tfe_agent_pool" "aws" {
  name         = "hashidemos-aws"
  organization = var.org
}

resource "tfe_agent_token" "aws" {
  agent_pool_id = tfe_agent_pool.aws.id
  description   = "aws"
}

resource "tfe_workspace" "hashidemos-vault" {
  depends_on = [hcp_vault_cluster_admin_token.admin]

  auto_apply   = true
  name         = "hashidemos-vault"
  organization = var.org
  # queue_all_runs    = false
  terraform_version = "1.1.7"
  working_directory = "vault"

  vcs_repo {
    identifier     = "assareh/hashidemos"
    oauth_token_id = var.oauth_token
  }
}

resource "tfe_variable" "aws_access_key_id" {
  category     = "terraform"
  key          = "aws_access_key_id"
  value        = aws_iam_access_key.vault.id
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_variable" "aws_account_id" {
  category     = "terraform"
  key          = "aws_account_id"
  value        = data.aws_caller_identity.current.account_id
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_variable" "aws_secret_access_key" {
  category     = "terraform"
  key          = "aws_secret_access_key"
  sensitive    = true
  value        = aws_iam_access_key.vault.secret
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_variable" "vault_addr" {
  category     = "env"
  key          = "VAULT_ADDR"
  value        = hcp_vault_cluster.primary.vault_public_endpoint_url
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_variable" "vault_token" {
  category     = "env"
  key          = "VAULT_TOKEN"
  sensitive    = true
  value        = hcp_vault_cluster_admin_token.admin.token
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_variable" "nomad_token_bound_cidrs" {
  category     = "terraform"
  key          = "nomad_token_bound_cidrs"
  value        = var.subnet_prefix
  workspace_id = tfe_workspace.hashidemos-vault.id
}

resource "tfe_workspace" "hashidemos-nomad" {
  depends_on = [tfe_workspace.hashidemos-vault]

  agent_pool_id  = tfe_agent_pool.aws.id
  auto_apply     = true
  execution_mode = "agent"
  name           = "hashidemos-nomad"
  organization   = var.org
  # queue_all_runs    = false
  terraform_version = "1.1.7"
  working_directory = "nomad"

  vcs_repo {
    identifier     = "assareh/hashidemos"
    oauth_token_id = var.oauth_token
  }
}

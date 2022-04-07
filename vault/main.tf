# -------------------- Vault resources -------------------->
# need to configure Vault with nomad server policies per
# https://www.nomadproject.io/docs/integrations/vault-integration#token-role-based-integration

provider "vault" {
  # It is strongly recommended to configure this provider through the
  # environment variables described above, so that each user can have
  # separate credentials set in the environment.
  #
  # This will default to using $VAULT_ADDR
  # But can be set explicitly
  namespace = "admin"
}

resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

resource "vault_aws_auth_backend_client" "example" {
  backend    = vault_auth_backend.aws.path
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "vault_aws_auth_backend_role" "nomad" {
  backend                         = vault_auth_backend.aws.path
  role                            = "nomad"
  auth_type                       = "ec2"
  bound_account_ids               = [var.aws_account_id]
  // bound_vpc_ids                   = ["vpc-b61106d4"]
  // bound_subnet_ids                = ["vpc-133128f1"]
  // bound_iam_role_arns             = ["arn:aws:iam::123456789012:role/MyRole"]
  // bound_iam_instance_profile_arns = ["arn:aws:iam::123456789012:instance-profile/MyProfile"]
  // inferred_entity_type            = "ec2_instance"
  // inferred_aws_region             = "us-east-1"
  token_ttl                       = 60
  token_max_ttl                   = 120
  token_policies                  = ["default", "nomad-server"]
}

resource "vault_policy" "nomad-server" {
  name = "nomad-server"

  policy = <<EOT
# Allow creating tokens under "nomad-cluster" token role. The token role name
# should be updated if "nomad-cluster" is not used.
path "auth/token/create/nomad-cluster" {
  capabilities = ["update"]
}

# Allow looking up "nomad-cluster" token role. The token role name should be
# updated if "nomad-cluster" is not used.
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}

# Allow looking up the token passed to Nomad to validate # the token has the
# proper capabilities. This is provided by the "default" policy.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow looking up incoming tokens to validate they have permissions to access
# the tokens they are requesting. This is only required if
# `allow_unauthenticated` is set to false.
path "auth/token/lookup" {
  capabilities = ["update"]
}

# Allow revoking tokens that should no longer exist. This allows revoking
# tokens for dead tasks.
path "auth/token/revoke-accessor" {
  capabilities = ["update"]
}

# Allow checking the capabilities of our own token. This is used to validate the
# token upon startup.
path "sys/capabilities-self" {
  capabilities = ["update"]
}

# Allow our own token to be renewed.
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# this is for the nomad servers, per https://www.nomadproject.io/docs/integrations/vault-integration#token-role-based-integration
resource "vault_token_auth_backend_role" "nomad-cluster" {
  role_name              = "nomad-cluster"
  orphan                 = true
  renewable              = true
  token_bound_cidrs      = [var.nomad_token_bound_cidrs]
  token_explicit_max_ttl = "0"
  token_period           = "1800"

  allowed_policies = []
}

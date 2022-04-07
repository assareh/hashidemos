resource "aws_instance" "nomad" {
  ami                         = data.hcp_packer_image.hashidemos.cloud_image_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nomad.name
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.hashidemos.key_name
  subnet_id                   = aws_subnet.hashidemos.id
  vpc_security_group_ids      = [aws_security_group.hashidemos.id]

  user_data = templatefile("${path.module}/templates/nomad.tpl", {
    consul_http_addr   = hcp_consul_cluster.primary.consul_private_endpoint_url
    consul_ca_file     = hcp_consul_cluster.primary.consul_ca_file
    consul_config_file = hcp_consul_cluster.primary.consul_config_file
    consul_token       = hcp_consul_cluster.primary.consul_root_token_secret_id
    nomad_license      = var.nomad_license
    ssh_username       = var.ssh_username
    vault_addr         = hcp_vault_cluster.primary.vault_private_endpoint_url
  })
}

resource "aws_iam_instance_profile" "nomad" {
  name = "hashidemos-nomad-profile"
  role = aws_iam_role.nomad.name
}

resource "aws_iam_role" "nomad" {
  name               = "hashidemos-nomad-role"
  assume_role_policy = data.aws_iam_policy_document.nomad_assume_role_policy_definition.json
}

data "aws_iam_policy_document" "nomad_assume_role_policy_definition" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

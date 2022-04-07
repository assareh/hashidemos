// resource "aws_security_group" "worker" {
//   name   = "hashidemos-worker"
//   vpc_id = var.vpc_id
// }

// resource "aws_security_group_rule" "worker_internal_api" {
//   description       = "Allow worker nodes to reach other on port 8200 for API"
//   security_group_id = aws_security_group.worker.id
//   type              = "ingress"
//   from_port         = 8200
//   to_port           = 8200
//   protocol          = "tcp"
//   self              = true
// }

// resource "aws_security_group_rule" "worker_internal_raft" {
//   description       = "Allow worker nodes to communicate on port 8201 for replication traffic, request forwarding, and Raft gossip"
//   security_group_id = aws_security_group.worker.id
//   type              = "ingress"
//   from_port         = 8201
//   to_port           = 8201
//   protocol          = "tcp"
//   self              = true
// }

resource "aws_iam_instance_profile" "worker" {
  name = "hashidemos-tfc-worker-profile"
  role = aws_iam_role.worker.name
}

resource "aws_iam_role" "worker" {
  name               = "hashidemos-tfc-worker-role"
  assume_role_policy = data.aws_iam_policy_document.worker_assume_role_policy_definition.json
}

data "aws_iam_policy_document" "worker_assume_role_policy_definition" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_launch_template" "worker" {
  name          = "hashidemos-worker"
  image_id      = var.image_id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = var.userdata_script
  vpc_security_group_ids = var.vpc_security_group_ids

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 100
      throughput            = 150
      iops                  = 3000
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_autoscaling_group" "worker" {
  name                = "hashidemos-worker"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.worker_subnets

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }
}

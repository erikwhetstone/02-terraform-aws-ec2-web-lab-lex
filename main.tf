# The security group starts with no rules. The AWS provider removes the
# default allow-all egress rule, so only the two rules below exist.
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-"
  description = "Lab 2 web server: HTTP in from allowed_http_cidr, HTTPS out"
  vpc_id      = data.aws_vpc.selected.id

  # name_prefix plus create_before_destroy lets Terraform build a
  # replacement group before removing the old one.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-sg"
  }
}

# HTTP only from the learner's network. There is no port 22 rule: this lab
# uses no SSH and no key pair.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from allowed_http_cidr only"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.allowed_http_cidr
}

# Amazon Linux 2023 package repositories use HTTPS. DNS, the instance
# metadata service, and Amazon Time Sync use link-local or VPC resolver
# addresses that security groups do not filter, so 443 is the only egress.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out for package installation"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data                   = local.user_data
  user_data_replace_on_change = true

  # T3 instances default to unlimited mode, which bills for sustained CPU
  # above baseline. Standard mode throttles instead of charging.
  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 only. A hop limit of 1 keeps metadata tokens on the instance.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # 8 GiB is the size of the Amazon Linux 2023 image. It is fixed here so a
  # learner cannot grow storage cost by accident.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.name_prefix}-root"
    }
  }

  tags = {
    Name = local.name_prefix
  }

  lifecycle {
    # The SSM parameter moves to each new AL2023 release. Without this, a
    # re-plan would replace a healthy instance whenever AWS publishes one.
    # To adopt a newer image deliberately, run a plan with -replace.
    ignore_changes = [ami]

    postcondition {
      condition     = self.public_ip != ""
      error_message = "The instance has no public IPv4 address, so the website cannot be reached."
    }
  }
}

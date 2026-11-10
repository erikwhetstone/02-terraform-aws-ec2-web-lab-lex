# Lab 1 owns the network. This lab only reads the VPC and subnet by ID and
# never creates, changes, or destroys network resources.
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.public_subnet_id

  lifecycle {
    # Blocking guardrail. A check block would only warn and let the
    # instance launch into the wrong network.
    postcondition {
      condition     = self.vpc_id == data.aws_vpc.selected.id
      error_message = "public_subnet_id does not belong to vpc_id. Copy both values from the same Lab 1 workspace."
    }
  }
}

# Lab 1 associates each public subnet with the public route table. Reading
# that table proves the subnet can reach the Internet before anything is
# created, instead of discovering an unreachable website after apply.
data "aws_route_table" "selected" {
  subnet_id = data.aws_subnet.selected.id

  lifecycle {
    postcondition {
      condition = anytrue([
        for route in self.routes :
        route.cidr_block == "0.0.0.0/0" && try(startswith(route.gateway_id, "igw-"), false)
      ])
      error_message = "public_subnet_id has no default route to an Internet Gateway. Use an entry from the Lab 1 public_subnet_ids output, not a private subnet."
    }
  }
}

# AWS publishes the latest Amazon Linux 2023 AMI ID as a public SSM
# parameter, so no account-specific or Region-specific AMI ID is hardcoded.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

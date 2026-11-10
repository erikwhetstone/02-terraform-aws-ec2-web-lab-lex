variable "aws_region" {
  description = "AWS Region where the EC2 web lab will be deployed. Must match the Region of the Lab 1 network."
  type        = string
}

variable "expected_aws_account_id" {
  description = "AWS account ID expected for this deployment. Used as a safety guardrail against deploying into the wrong account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must contain exactly 12 digits."
  }
}

variable "owner_name" {
  description = "Learner or administrator responsible for this deployment. Shown on the success page, so the allowed characters are limited."
  type        = string

  validation {
    condition     = length(trimspace(var.owner_name)) > 0
    error_message = "owner_name must not be empty."
  }

  # The value is written into an HTML page and Terraform has no HTML-escape
  # function, so markup characters are rejected here instead.
  validation {
    condition     = can(regex("^[A-Za-z0-9 ._-]+$", var.owner_name))
    error_message = "owner_name may contain only letters, digits, spaces, periods, underscores, and hyphens."
  }
}

variable "deployment_id" {
  description = "Unique identifier for this lab deployment. Used in resource names and shown on the success page."
  type        = string

  validation {
    condition     = length(trimspace(var.deployment_id)) > 0
    error_message = "deployment_id must not be empty."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,40}$", var.deployment_id))
    error_message = "deployment_id may contain only letters, digits, periods, underscores, and hyphens, up to 40 characters."
  }
}

variable "expiration_date" {
  description = "Expected cleanup date for this training deployment in YYYY-MM-DD format."
  type        = string

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.expiration_date))
    error_message = "expiration_date must use YYYY-MM-DD format."
  }
}

variable "project_name" {
  description = "Generic project identifier used when naming and tagging resources."
  type        = string
  default     = "terraform-aws-security-training"
}

variable "vpc_id" {
  description = "ID of the VPC created by Lab 1. Copy the vpc_id output from the Lab 1 workspace."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must be vpc- followed by 8 to 17 lowercase hexadecimal characters."
  }
}

variable "public_subnet_id" {
  description = "ID of one public subnet created by Lab 1. Copy one entry of the public_subnet_ids output from the Lab 1 workspace."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8,17}$", var.public_subnet_id))
    error_message = "public_subnet_id must be subnet- followed by 8 to 17 lowercase hexadecimal characters."
  }
}

variable "allowed_http_cidr" {
  description = "IPv4 CIDR block allowed to reach the website on port 80. Use your own public IP address as a /32, for example 203.0.113.10/32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_http_cidr))
    error_message = "allowed_http_cidr must be a valid IPv4 CIDR block, for example 203.0.113.10/32."
  }

  # AWS rejects a CIDR whose address has host bits set beyond the prefix,
  # such as 203.0.113.10/24. Catch it here with a clearer message.
  validation {
    condition     = try(cidrhost(var.allowed_http_cidr, 0) == split("/", var.allowed_http_cidr)[0], false)
    error_message = "allowed_http_cidr must start at its network address. For a single IP address, use /32."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Restricted to a low-cost allowlist for training."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro"], var.instance_type)
    error_message = "This lab permits only t3.micro. Extending the allowlist also requires updating the IAM training policy."
  }
}

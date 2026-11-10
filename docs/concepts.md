# Concepts

This page explains the Terraform and AWS ideas behind the Lab 2 code.

## Consuming another lab's outputs

Lab 1 publishes `vpc_id` and `public_subnet_ids` as outputs. Lab 2 accepts
them as ordinary Terraform variables, which the learner copies into the
Lab 2 workspace.

This is deliberately manual. It shows exactly which values connect the two
labs and keeps each workspace independent. A later option is the
`tfe_outputs` data source, which reads another workspace's outputs
directly but requires state sharing between workspaces and an HCP
Terraform token.

## Resources and data sources

A `resource` block is something Terraform creates, tracks in state, and
destroys. A `data` block is something Terraform only reads.

Lab 2 reads the VPC, subnet, and route table with data sources because Lab
1 owns them. If Lab 2 declared them as resources, it would try to create a
second network or fight Lab 1 over the same objects.

The HCP Terraform workspace Resources count includes data sources, so it
reads higher than the four resources Lab 2 creates.

## Layered guardrails

| Layer | Where | Blocks the run? | Lab 2 example |
|---|---|---|---|
| Variable validation | `variables.tf` | Yes, before AWS is contacted | `allowed_http_cidr` must be a CIDR |
| Provider account restriction | `provider.tf` | Yes, before any AWS change | `allowed_account_ids` |
| Data-source postcondition | `data.tf` | Yes, during plan | Subnet must be in the VPC and route to an Internet Gateway |
| Resource postcondition | `main.tf` | Yes, after the resource is created | Instance must have a public IPv4 address |
| Check block | `checks.tf` | No, warning only | HTTP access wider than /24 |
| IAM policy conditions | AWS | Yes, at the API call | Only `t3.micro` with IMDSv2 and encryption |

Use a blocking layer whenever a mistake would deploy into the wrong place
or cost money. Use a check block for advice.

`terraform validate` does not evaluate postconditions or check blocks. The
first real plan is part of testing.

## User data and `templatefile()`

User data is a script EC2 runs once, at first boot. `locals.tf` renders
`templates/user-data.sh.tftpl` with `templatefile()`, replacing
placeholders such as `${owner_name}` with variable values. The result
installs NGINX and writes the success page.

Before installing NGINX, the script creates a 1 GiB swap file on the
encrypted root volume. A `t3.micro` has 1 GiB of memory, and testing this lab
showed dnf being killed by the kernel for lack of memory while it loaded
repository metadata. The swap file costs nothing extra because it uses
space already on the 8 GiB volume. The install is also retried up to three
times, and `rpm -q nginx` makes the script fail visibly if NGINX is still
missing.

`user_data_replace_on_change = true` makes Terraform replace the instance
when the rendered script changes. Without it, the new script would be
saved but never run, and the page would show stale values.

The page is written inside a quoted heredoc (`<<'HTML'`), so the shell
does not interpret anything in it. Terraform has already substituted the
values. Because those values land in HTML, `owner_name` and
`deployment_id` accept only safe characters.

## The AMI and `ignore_changes`

`data.aws_ssm_parameter.al2023` always returns the newest Amazon Linux 2023
AMI. Changing an instance's AMI requires replacing it, so without
protection every new AWS release would make a plan replace a healthy
instance.

`ignore_changes = [ami]` tells Terraform to keep the AMI the instance was
launched with. To adopt a newer image deliberately, start a run with the
**Replace resources** option set to `aws_instance.web`.

## IMDSv2

The instance metadata service supplies instance details and, when a role is
attached, temporary credentials. IMDSv1 answers any local HTTP request,
which server-side request forgery can abuse. IMDSv2 requires a session
token obtained with a PUT request first.

`http_tokens = "required"` turns off IMDSv1. `http_put_response_hop_limit = 1`
stops the token from being usable beyond the instance itself, such as from
a container on the host.

## Security group rule resources

The proof-of-concept used inline `ingress` and `egress` blocks. Lab 2 uses
separate `aws_vpc_security_group_ingress_rule` and
`aws_vpc_security_group_egress_rule` resources, which the AWS provider
recommends. Each rule has its own ID and tags, and changing one rule does
not rewrite the others.

When `aws_security_group` is created, the provider removes the AWS default
allow-all egress rule, so the only rules are the two Lab 2 declares.

`name_prefix` with `create_before_destroy` lets Terraform build a
replacement group with a unique name before deleting the old one.

## Default tags

`default_tags` in `provider.tf` adds the standard tag set to every taggable
resource. Each resource adds only a `Name`. The tags answer who created a
resource, which lab and deployment own it, and when it should be removed.
The IAM policy uses `Purpose = Training` to decide what may be destroyed.

## T3 CPU credits

T3 instances run below a baseline CPU level and earn credits to burst
above it. In the default unlimited mode, sustained use beyond earned
credits is billed per vCPU-hour. Lab 2 sets standard mode, which throttles
the instance to baseline instead. For a static web page, throttling is
harmless and the cost stays fixed.

## Why there is no SSH

SSH needs an open port, a key pair to store and protect, and a way to
distribute it. Lab 2 needs none of these: everything the instance does is
in user data, and the boot log is readable through the EC2 console output.
Lab 4 adds Systems Manager Session Manager for interactive access without
opening any inbound port.

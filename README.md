# Terraform AWS EC2 Web Lab

Lab 2 of the Terraform AWS Security Training series. This lab deploys one
Amazon Linux 2023 EC2 instance running NGINX into the network built by
Lab 1, using HCP Terraform for remote execution and state.

## Lab Goal

Deploy a small, hardened web server into an existing network, prove it
works, and destroy it cleanly.

The success page shows who deployed it, which deployment it belongs to,
which lab created it, the Region, and the cleanup date. Every value comes
from your Terraform variables, not from the source code.

## What You Will Learn

- How one lab consumes another lab's outputs through Terraform variables
- The difference between resources Terraform creates and data sources it only reads
- How layered guardrails work: variable validation, provider account
  restriction, data-source postconditions, and non-blocking check blocks
- How EC2 user data and `templatefile()` turn variables into a working server
- Why IMDSv2, encrypted EBS, standard CPU credits, and no SSH are the defaults
- Why an AMI read from an SSM parameter needs `ignore_changes`, and how to
  replace an instance on purpose
- How to read a plan and a destroy plan before confirming either one

## Architecture

![Lab 2 architecture](diagrams/architecture.png)

Lab 2 creates four resources inside the Lab 1 VPC:

| Resource | Purpose |
|---|---|
| `aws_security_group.web` | Firewall for the instance, with no default rules |
| `aws_vpc_security_group_ingress_rule.http` | TCP 80 from `allowed_http_cidr` only |
| `aws_vpc_security_group_egress_rule.https` | TCP 443 out, for package installation |
| `aws_instance.web` | Amazon Linux 2023 `t3.micro` running NGINX |

Lab 2 does not create a VPC, subnet, route, gateway, key pair, Elastic IP,
load balancer, or IAM role. Traffic flows and ownership are detailed in
[docs/architecture.md](docs/architecture.md).

## How This Lab Connects to Lab 1

Lab 1 publishes `vpc_id` and `public_subnet_ids` as outputs. You copy
`vpc_id` and one entry of `public_subnet_ids` into this lab's workspace as
the Terraform variables `vpc_id` and `public_subnet_id`.

Lab 2 reads those network objects with data sources and never changes
them. Before anything is created, the plan stops if the subnet is not in
the VPC, or if the subnet has no default route to an Internet Gateway.

Because the Lab 2 instance sits in a Lab 1 subnet, destroy Lab 2 before Lab 1.

## Why There Is No SSH

SSH needs an open port, a key pair to protect, and a way to distribute it.
This lab needs none of them. Everything the instance does is in its user
data script, and the boot log is readable through the EC2 console output.
Lab 4 adds Systems Manager Session Manager for interactive access without
opening any inbound port.

## Security Decisions

### AWS Account Guardrail

The provider sets `allowed_account_ids = [var.expected_aws_account_id]`.
If the workspace credentials belong to any other account, Terraform stops
before making a change. A `check` block alone would only warn.

### Credentials Are Not Stored in Source Code

The AWS access key and secret are Sensitive Environment variables in HCP
Terraform. The instance has no IAM role and no credentials of its own.

### Network Access

- Inbound: TCP 80 from the single CIDR in `allowed_http_cidr`, normally your own `/32`
- Outbound: TCP 443 only, instead of the AWS default of all traffic
- No port 22 rule, no key pair

### Instance Hardening

- IMDSv2 required, with a hop limit of 1
- Encrypted gp3 root volume, fixed at 8 GiB
- Standard CPU credit mode, so sustained CPU use is throttled rather than billed

### IAM Policy Conditions

The training policy enforces the same rules as Terraform, independently.
It allows `ec2:RunInstances` only for `t3.micro` with IMDSv2 and encrypted
volumes, and it can terminate instances or delete security groups only
when they are tagged `Purpose = Training`.

### Auto Apply

Auto Apply stays off. Every plan and every destroy plan is reviewed before
it is confirmed.

### Resource Ownership

The provider's `default_tags` apply the standard series tags to every
resource. `Owner`, `DeploymentId`, `Lab`, and `ExpiresOn` identify who
created a resource, which workspace owns it, and when it should be removed.

The full security baseline and the training simplifications are in
[SECURITY.md](SECURITY.md).

## Cost Estimate

| Scenario | Approximate cost (us-east-1, list price) |
|---|---|
| 1 to 2 hour lab session | about $0.02 to $0.04 |
| Forgotten for 30 days | about $11.88 |
| Instance stopped for 30 days | about $0.64 (root volume only) |

The most expensive resource is the instance itself. A forgotten Lab 2
deployment alone exceeds the series $10 budget in about 26 days. Rates,
Free Tier caveats, and what keeps billing while stopped are in [COSTS.md](COSTS.md).

## Prerequisites

- Lab 0 completed, including the AWS Budget
- Lab 1 applied in its own HCP Terraform workspace, with its outputs available
- An HCP Terraform organization connected to GitHub through the HCP Terraform GitHub App
- The training IAM user from Lab 0 with both training policies attached:
  the Lab 1 network policy and this lab's
  [examples/iam/training-policy.json](examples/iam/training-policy.json)
- Your public IPv4 address, from `curl -s https://checkip.amazonaws.com`

## Repository Structure

```text
02-terraform-aws-ec2-web-lab/
|-- README.md
|-- SECURITY.md
|-- COSTS.md
|-- TROUBLESHOOTING.md
|-- CHANGELOG.md
|-- LICENSE
|-- .gitignore
|-- .terraform.lock.hcl
|-- versions.tf
|-- provider.tf
|-- variables.tf
|-- data.tf
|-- locals.tf
|-- main.tf
|-- checks.tf
|-- outputs.tf
|-- templates/
|   `-- user-data.sh.tftpl
|-- examples/
|   |-- terraform.tfvars.example
|   `-- iam/
|       `-- training-policy.json
|-- docs/
|   |-- architecture.md
|   |-- concepts.md
|   |-- deployment-guide.md
|   `-- cleanup-guide.md
`-- diagrams/
    `-- architecture.png
```

## Terraform File Walkthrough

### `versions.tf`

Pins the Terraform and AWS provider versions shared with Lab 1, so both
labs run against the same tested provider.

### `provider.tf`

Sets the Region, restricts every run to `expected_aws_account_id`, and
applies the standard tags with `Lab = "ec2-web"`.

### `variables.tf`

Declares every input and rejects bad values before AWS is contacted.
`owner_name` and `deployment_id` accept only safe characters because they
are written into an HTML page. `allowed_http_cidr` must be a valid IPv4
CIDR that starts at its network address.

### `data.tf`

Reads the Lab 1 VPC, subnet, and route table, and the current Amazon Linux
2023 AMI ID from a public SSM parameter. Postconditions stop the plan if the
subnet is outside the VPC or has no route to an Internet Gateway.

### `locals.tf`

Builds the resource name prefix from `deployment_id` and renders the user
data template.

### `main.tf`

Creates the security group, its two rules, and the instance. The instance
ignores AMI changes, so a new Amazon Linux release does not replace a
healthy server.

### `checks.tf`

Warns, without blocking, if HTTP access is wider than /24 or if the
expiration date has passed.

### `outputs.tf`

Publishes the website URL and the IDs used to validate the deployment.

### `templates/user-data.sh.tftpl`

First-boot script. It adds a 1 GiB swap file, installs NGINX, and writes
the success page. The swap file exists because a `t3.micro` has only 1 GiB
of memory, and testing showed the package manager being killed without it.

The concepts behind these choices are explained in [docs/concepts.md](docs/concepts.md).

## Terraform State

HCP Terraform stores this lab's state. GitHub stores only source code.

State for this lab contains the instance ID, public IP address, security
group IDs, and the rendered user data, which includes your owner name and
deployment ID. Never commit state, plan files, or `terraform.tfvars`. The
repository `.gitignore` blocks them, and `.terraform.lock.hcl` is committed
so every run uses the same provider build.

## HCP Terraform Workspace Setup

Create a Version Control Workflow workspace connected to your copy of this
repository, with **Apply method** set to **Manual apply** and **Automatic
speculative plans** unchecked. Step-by-step instructions are in
[docs/deployment-guide.md](docs/deployment-guide.md).

### Terraform Variables

| Key | Required | Example | Source |
|---|---|---|---|
| `aws_region` | Yes | `us-east-1` | Must match the Lab 1 Region |
| `expected_aws_account_id` | Yes | 12 digits | Your training account |
| `owner_name` | Yes | `Jane-Learner` | Letters, digits, spaces, `.`, `_`, `-` |
| `deployment_id` | Yes | `jane-ec2-web-01` | Up to 40 characters, no spaces |
| `expiration_date` | Yes | `2026-12-31` | Your cleanup date |
| `vpc_id` | Yes | `vpc-...` | Lab 1 output `vpc_id` |
| `public_subnet_id` | Yes | `subnet-...` | One entry of Lab 1 output `public_subnet_ids` |
| `allowed_http_cidr` | Yes | `203.0.113.10/32` | Your public IP followed by `/32` |
| `instance_type` | No | `t3.micro` | Default and only allowed value |
| `project_name` | No | `terraform-aws-security-training` | Default |

An example is in [examples/terraform.tfvars.example](examples/terraform.tfvars.example).

### AWS Authentication

| Key | Category | Sensitive |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Environment variable | Yes |
| `AWS_SECRET_ACCESS_KEY` | Environment variable | Yes |
| `AWS_REGION` | Environment variable | No |
| `AWS_DEFAULT_REGION` | Environment variable | No |

The HCP Terraform Add variable form defaults to Terraform variable. Change
the category for these four keys.

## IAM Permissions

[examples/iam/training-policy.json](examples/iam/training-policy.json) is a
training baseline, not a universal production policy. It allows:

- Read-only EC2 describe calls needed for plan and refresh
- `ssm:GetParameter` on the public Amazon Linux AMI parameters only
- Security group creation and rule management
- `ec2:RunInstances` only for `t3.micro`, with IMDSv2 required and encrypted volumes
- `ec2:TerminateInstances` and `ec2:DeleteSecurityGroup` only on resources
  tagged `Purpose = Training`
- Tagging at creation, or retagging resources already tagged `Purpose = Training`

Attach it alongside the Lab 1 policy. Do not attach `AdministratorAccess`.

## Initialize Terraform

HCP Terraform runs `terraform init` remotely at the start of every run,
using the committed lock file.

If you change the code, check it locally before pushing:

```bash
terraform init -backend=false
terraform fmt -check -diff
terraform validate
```

Do not run a local `terraform apply`. It would create resources tracked in
a local state file instead of the HCP Terraform workspace. `validate` also
does not evaluate postconditions or check blocks; the first HCP plan does.

## Review the Terraform Plan

Start a run in HCP Terraform. Before confirming, check:

- The summary is `Plan: 4 to add, 0 to change, 0 to destroy`
- There are no check warnings
- The ingress rule is TCP 80 from your `/32`, and no port 22 rule exists
- The instance is `t3.micro` with `http_tokens = "required"`,
  `cpu_credits = "standard"`, and an encrypted 8 GiB gp3 root volume
- The instance `tags_all` shows the nine standard tags plus `Name`

The full checklist is in [docs/deployment-guide.md](docs/deployment-guide.md).

## Apply

Confirm the plan only after the checklist passes. First boot creates the
swap file and installs NGINX, which can take up to 5 minutes after the
apply completes.

## Validate the Web Server

1. Open the `website_url` output from the network in `allowed_http_cidr`.
2. Confirm the page shows your owner name, deployment ID, `ec2-web`,
   Region, and expiration date.
3. Confirm IMDSv2, encryption, CPU credit mode, security group rules, and
   tags with the AWS CLI commands in [docs/deployment-guide.md](docs/deployment-guide.md).
4. Start a **Plan only** run and confirm it reports `No changes`.

## Terraform Outputs

| Output | Use |
|---|---|
| `website_url` | Open this to see the success page |
| `public_ip` | Changes if the instance is stopped and started |
| `instance_id` | Used by the validation and cleanup commands |
| `availability_zone` | Zone of the selected Lab 1 subnet |
| `security_group_id` | Used to check the two rules |
| `ami_id` | Amazon Linux 2023 image the instance launched from |
| `vpc_id` | Lab 1 VPC used by this lab |
| `public_subnet_id` | Lab 1 subnet used by this lab |

## Destroy

Destroy Lab 2 before Lab 1. In the workspace, open **Settings >
Destruction and Deletion** and queue a destroy plan. Confirm it lists only
the four Lab 2 resources, then confirm it.

## Verify Cleanup

Confirm no instance, security group, or volume tagged with your
`DeploymentId` remains, using the commands in
[docs/cleanup-guide.md](docs/cleanup-guide.md).

If your account uses Amazon GuardDuty Runtime Monitoring, GuardDuty adds
its own VPC endpoint to the Lab 1 VPC while the instance runs. Remove it
before destroying Lab 1, as the cleanup guide explains.

## Troubleshooting

### Invalid Value for `allowed_http_cidr`

Enter your address with a prefix length, such as `203.0.113.10/32`. A bare
IP address fails validation.

### Wrong AWS Account

The provider stops if the credentials do not belong to
`expected_aws_account_id`. Correct the key or the variable. Never remove
`allowed_account_ids`.

### Connection Refused or Timed Out

Refused means the request reached the instance but NGINX is not listening
yet, so check the boot log. Timed out means the request never arrived, so
check `allowed_http_cidr` and use `http://`, not `https://`.

### Lab 1 Subnets Stuck Deleting

A GuardDuty-managed VPC endpoint is still in the Lab 1 VPC. Follow the
GuardDuty section of the [cleanup guide](docs/cleanup-guide.md).

### Partial Apply Failure

Do not delete resources in the console. Fix the cause and start a new run.

More entries are in [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## What Comes Next

Lab 3 adds secure S3 object storage. Later labs replace direct public
access to this instance with Systems Manager administration and an
Application Load Balancer.

- Previous lab: [Lab 1 - Network Foundation](https://github.com/lshillingford/01-terraform-aws-network-foundation-lab)
- Series overview: [Terraform AWS Security Training](https://github.com/lshillingford/00-terraform-aws-security-training)

## Important Reminder

This instance bills by the hour, and a forgotten deployment costs about
$11.88 per month. Destroy Lab 2 as soon as you finish validating it, and
destroy Lab 1 afterward if you are not continuing to the next lab.

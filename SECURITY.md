# Security

This document answers the series security baseline questions for Lab 2
and lists what has been simplified for training.

## 1. What identities can deploy it?

Only the training IAM user whose access key is stored in the HCP Terraform
workspace. The user holds two customer managed policies: the Lab 1 network
policy and [examples/iam/training-policy.json](examples/iam/training-policy.json).
Neither grants administrator access. Runs start only when a person queues
or confirms them in HCP Terraform; Auto Apply is off.

## 2. What is publicly reachable?

TCP port 80 on the instance's public IPv4 address, and only from the CIDR in
`allowed_http_cidr`. No other inbound port is open. There is no port 22
rule, no key pair, and no SSH daemon access path.

## 3. What remains private?

The Lab 1 private subnets are not used. The instance metadata service is
reachable only from the instance itself (IMDSv2 with a hop limit of 1).
Terraform state is stored in HCP Terraform, not in Git.

## 4. Where are credentials stored?

The AWS access key and secret are HCP Terraform Environment variables
marked Sensitive. They are write-only in the HCP Terraform UI and API and
never appear in the repository. The instance has no IAM role and no
credentials of its own.

## 5. What data is encrypted?

The gp3 root volume, including the swap file the boot script creates on it,
is encrypted with the AWS managed EBS key. The IAM
policy denies launches with unencrypted volumes. HTTP traffic to the
website is not encrypted; see the simplifications below.

## 6. What logs are produced?

- HCP Terraform keeps a log of every plan and apply.
- AWS CloudTrail Event history records the management API calls made by the
  training user for 90 days at no charge.
- The first-boot script writes to `/var/log/cloud-init-output.log`, which
  can be read without SSH through the EC2 console output.

No VPC Flow Logs, NGINX log shipping, or paid logging is enabled, to keep
the lab at or near list-price zero beyond the instance itself.

## 7. What prevents deployment into the wrong account?

The provider setting `allowed_account_ids = [var.expected_aws_account_id]`
stops every run before any AWS change if the credentials belong to another
account. A `check` block alone would only warn, so it is not used for this.

The plan also stops if:

- `public_subnet_id` is not in `vpc_id`
- the subnet has no default route to an Internet Gateway

## 8. What controls cost and resource size?

- `instance_type` accepts only `t3.micro`, and the IAM policy independently
  denies any other type.
- The root volume is fixed at 8 GiB.
- CPU credits use standard mode, so sustained CPU use is throttled instead
  of billed as surplus credits.
- No Elastic IP, NAT Gateway, or load balancer is created.

## 9. How is infrastructure destroyed safely?

Through an HCP Terraform destroy plan that is reviewed before
confirmation. The IAM policy can terminate instances and delete security
groups only when they carry `Purpose = Training`, which the provider's
default tags apply to every Lab 2 resource. Lab 2 must be destroyed before
Lab 1. See [docs/cleanup-guide.md](docs/cleanup-guide.md).

## 10. What has been simplified for training?

| Simplification | Production practice | Where the series addresses it |
|---|---|---|
| Long-lived IAM access key in HCP Terraform | Short-lived credentials through OIDC workload identity | Lab 8 |
| Plain HTTP on a public IP | HTTPS behind a load balancer or CloudFront | Labs 5 and 7 |
| Instance directly on the Internet | Instance in a private subnet behind a load balancer | Lab 5 and the capstone |
| No administration path | Systems Manager Session Manager with an instance role | Lab 4 |
| Security group rule actions allowed on all resources | Rule actions scoped by resource tag | Planned for a later version |
| HTTPS egress to `0.0.0.0/0` | VPC endpoints or a controlled egress path | Later labs |
| No centralized logging | VPC Flow Logs, CloudTrail trails, and log aggregation | Later labs |

## Handling of user input

`owner_name` and `deployment_id` are written into an HTML page by the user
data script. Terraform has no HTML-escape function, so both variables
reject characters outside letters, digits, spaces, periods, underscores,
and hyphens.

Do not place secrets in user data. Anyone with `ec2:DescribeInstanceAttribute`
can read it.

## Reporting a problem

This is a training repository. Open an issue describing the problem
without including account IDs, credentials, or resource IDs from your
environment.

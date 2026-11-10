# Costs

Prices are AWS list prices for us-east-1, checked on 2026-11-10, before
Free Tier or credits. Prices change and vary by Region. Confirm them in
the AWS Pricing Calculator before you rely on them.

## Expected session

| Item | Value |
|---|---|
| Expected session duration | 1 to 2 hours, from apply to destroy |
| Expected session cost | about $0.02 to $0.04 |
| Most expensive resource | The `t3.micro` instance hours |

## Billable resources

| Resource | Rate | Per hour | 30 days (730 hours) |
|---|---|---|---|
| `t3.micro` On-Demand, Linux | $0.0104 per hour | $0.0104 | $7.59 |
| Public IPv4 address (auto-assigned) | $0.005 per hour | $0.0050 | $3.65 |
| gp3 root volume, 8 GiB | $0.08 per GB-month | about $0.0009 | $0.64 |
| **Total** | | **about $0.0163** | **about $11.88** |

Not billed for this lab: the security group and its rules, the Lab 1 VPC
and subnets, and normal low data transfer for a test page. CPU credits are
in standard mode, so no surplus charge applies. In the default unlimited
mode, sustained CPU above baseline would be billed per vCPU-hour.

## Estimated monthly cost if forgotten

About **$11.88** per month. A forgotten Lab 2 deployment by itself exceeds
the series $10 budget in about 26 days. The Lab 0 budget warnings at $5 and
$8 would arrive after roughly 13 and 20 days of Lab 2 running alone.
Budget alerts are notifications, not automatic shutdown.

## What keeps billing when the instance is stopped

| Resource | Billed while stopped? |
|---|---|
| Instance hours | No |
| Auto-assigned public IPv4 address | No. AWS releases it at stop, and a different address is assigned at the next start |
| gp3 root volume | Yes, about $0.64 per month |

Stopping is not cleanup. Destroy the deployment.

## Free Tier and credit caveats

- Free Tier eligibility depends on your account's age and AWS Free Tier plan.
  Check the AWS Billing console before assuming any usage is free.
- Where the 12-month EC2 Free Tier applies, it has included 750 hours per
  month of an eligible micro instance type and 750 hours per month of
  in-use public IPv4 addresses. Confirm `t3.micro` eligibility for your account.
- Free Tier hours are shared across all instances and Regions in the account.

This document uses list prices so the estimate holds for any learner.

Account-level security services, such as Amazon GuardDuty Runtime
Monitoring, bill separately for the instances they monitor. They are not
included in this estimate.

## Required cleanup

1. Destroy Lab 2 through an HCP Terraform destroy plan.
2. Confirm no instance, volume, or security group tagged with your
   `DeploymentId` remains. See [docs/cleanup-guide.md](docs/cleanup-guide.md).
3. Destroy Lab 1 only after Lab 2 is gone, if you are not continuing to the next lab.

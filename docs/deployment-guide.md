# Deployment Guide

Follow these steps in order. Each step is a single action.

## Prepare

1. Confirm Lab 1 is applied. In the Lab 1 workspace, open **Outputs** and
   note `vpc_id` and the first entry of `public_subnet_ids`.
2. Confirm both training policies are attached to the training IAM user.
3. Find your public IPv4 address:
   ```bash
   curl -s https://checkip.amazonaws.com
   ```

## Connect the repository

4. Fork or copy this repository into your GitHub account.
5. In GitHub, open **Settings > Applications > Installed GitHub Apps >
   Terraform Cloud > Configure** and grant access to your Lab 2 repository.

## Create the workspace

6. In HCP Terraform, choose **New > Workspace > Version Control Workflow**.
7. Choose **GitHub App** and select your Lab 2 repository.
8. Under **Advanced options**, set **Apply method** to **Manual apply** and
   leave **Automatic speculative plans** unchecked.
9. Create the workspace. Do not start a run yet.
10. In **Settings > General**, select the Terraform version used by the
    series and save.
11. In **Settings > Version Control**, confirm **Automatic speculative
    plans** is unchecked. This matters for any workspace connected to a
    public repository.

## Add variables

12. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as **Environment
    variables**, both marked **Sensitive**.
13. Add `AWS_REGION` and `AWS_DEFAULT_REGION` as Environment variables.
14. Add the Terraform variables listed in the README, section 9. Enter
    `allowed_http_cidr` as your address followed by `/32`.

## Plan

15. Choose **New run**, select **Plan and apply (standard)**, and start it.
16. Review the plan against this checklist:

| Check | Expected |
|---|---|
| Summary | `Plan: 4 to add, 0 to change, 0 to destroy` |
| Check warnings | None |
| Ingress rule | `from_port = 80`, `to_port = 80`, `cidr_ipv4` is your `/32` |
| Egress rule | `from_port = 443`, `to_port = 443`, `cidr_ipv4 = "0.0.0.0/0"` |
| Port 22 | Not present anywhere |
| `instance_type` | `t3.micro` |
| `associate_public_ip_address` | `true` |
| `credit_specification.cpu_credits` | `standard` |
| `metadata_options.http_tokens` | `required` |
| `metadata_options.http_put_response_hop_limit` | `1` |
| `root_block_device` | `gp3`, `8`, `encrypted = true` |
| `tags_all` on the instance | Nine standard tags plus `Name`, with `Lab = "ec2-web"` |

## Apply

17. If every check passes, choose **Confirm & apply**, then **Confirm plan**.
18. Wait up to 5 minutes after the apply completes. First boot creates a
    swap file and installs NGINX before the page is served.

## Validate

Run these with an administrator or read-only AWS CLI profile for the
training account. Replace the values in angle brackets with your outputs.

19. Confirm the website returns HTTP 200:
    ```bash
    curl -s -o /dev/null -w '%{http_code}\n' http://<public_ip>
    ```
20. Open `website_url` in a browser and confirm the page shows your owner
    name, deployment ID, `ec2-web`, Region, and expiration date.
21. Confirm IMDSv2 is required. Expect `required`:
    ```bash
    aws ec2 describe-instances --instance-ids <instance_id> --query 'Reservations[].Instances[].MetadataOptions.HttpTokens' --output text
    ```
22. Confirm the root volume is encrypted gp3. Expect `gp3`, `8`, `True`:
    ```bash
    aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=<instance_id> --query 'Volumes[].[VolumeType,Size,Encrypted]' --output table
    ```
23. Confirm standard CPU credits. Expect `standard`:
    ```bash
    aws ec2 describe-instance-credit-specifications --instance-ids <instance_id> --query 'InstanceCreditSpecifications[].CpuCredits' --output text
    ```
24. Confirm exactly two security group rules, TCP 80 in and TCP 443 out:
    ```bash
    aws ec2 describe-security-group-rules --filters Name=group-id,Values=<security_group_id> --query 'SecurityGroupRules[].[IsEgress,IpProtocol,FromPort,ToPort,CidrIpv4]' --output table
    ```
25. Confirm the tagged resources for your deployment:
    ```bash
    aws ec2 describe-tags --filters Name=key,Values=DeploymentId Name=value,Values=<deployment_id> --query 'Tags[].[ResourceType,ResourceId]' --output text | sort -u
    ```
    Expect an instance, a volume, a security group, and two security group rules.
    The network interface is not tagged. If the instance was replaced, the old
    instance and volume can still appear for up to an hour after termination.

## Confirm a clean re-plan

26. Choose **New run**, select **Plan only**, and start it.
27. Confirm the result is `No changes. Your infrastructure matches the
    configuration.` Any planned change here is a defect to investigate
    before release.

When you are finished, follow the [cleanup guide](cleanup-guide.md).

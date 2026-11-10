# Troubleshooting

Each entry lists the symptom, the cause, and the fix. Do not delete AWS
resources by hand while troubleshooting. Inspect HCP Terraform state first.

## Plan errors

### `Invalid value for variable` on `allowed_http_cidr`

**Symptom:** Two errors: the value must be a valid IPv4 CIDR block, and it
must start at its network address.

**Cause:** The value is a bare IP address such as `203.0.113.10`, without a
prefix length.

**Fix:** Edit the Terraform variable to `203.0.113.10/32`, using your own
address, and start a new run.

The failed plan may list only 3 resources to create. Terraform skips the
ingress rule because it depends on the invalid variable. After the fix,
the plan shows all 4.

### `allowed_http_cidr must start at its network address`

**Cause:** The address has host bits set beyond the prefix, such as
`203.0.113.10/24`. AWS rejects this form.

**Fix:** Use `/32` for a single address, or the network address of the
range, such as `203.0.113.0/24`.

### `AWS account ID not allowed`

**Cause:** The credentials in the workspace belong to a different account
than `expected_aws_account_id`. The provider stopped before any change.

**Fix:** Correct either the access key or the account ID variable. Never
remove `allowed_account_ids` to make the error go away.

### `public_subnet_id does not belong to vpc_id`

**Cause:** The two IDs were copied from different Lab 1 deployments, or
mistyped.

**Fix:** Copy both from the Outputs of the same Lab 1 workspace.

### `public_subnet_id has no default route to an Internet Gateway`

**Cause:** A private subnet ID was used. Lab 1 private subnets have no
Internet route by design.

**Fix:** Use an entry from the Lab 1 `public_subnet_ids` output, not
`private_subnet_ids`.

### The route table lookup returns no results

**Symptom:** The plan fails while reading `data.aws_route_table.selected`.

**Cause:** The subnet has no explicit route table association, which happens
with subnets not created by Lab 1.

**Fix:** Use a subnet from Lab 1, which associates each public subnet with
the public route table.

### `No valid credential sources found`

**Cause:** The AWS keys were added as Terraform variables instead of
Environment variables. The HCP Terraform Add variable form defaults to
Terraform variable.

**Fix:** Delete both keys and add them again with category Environment
variable and Sensitive checked.

### Check block warnings

`http_access_is_narrow` warns when `allowed_http_cidr` is wider than /24.
`expiration_date_is_future` warns when the date has passed or is not a real
calendar date. Warnings do not stop the run. Fix the variable unless the
wider access or the date is intentional.

## Apply errors

### `UnauthorizedOperation` or `AccessDenied`

**Cause:** The training user lacks a permission the provider needs, or a
policy condition denied the request.

**Fix:**

1. Confirm both training policies are attached to the user.
2. Confirm `instance_type` is `t3.micro`. The policy denies other types.
3. If the error includes an encoded message, an administrator can decode
   it with `aws sts decode-authorization-message --encoded-message <message>`.
4. Add only the missing action to the policy, publish a new policy
   version, and run again.

### Partial apply

**Symptom:** The apply failed after creating some resources, or a resource
is marked tainted.

**Fix:** Do not delete anything in the console. Fix the cause and start a
new run. Terraform creates what is missing and replaces what is tainted.
If the resource is healthy and the taint is the only problem, an
administrator can untaint it rather than replace it.

## Website problems

### Connection refused or timed out: which one tells you where to look

| Browser or curl result | Meaning |
|---|---|
| Connection refused | Your request reached the instance, but nothing is listening on port 80. The security group and network path are working. Check the boot log. |
| Timed out | The request never reached the instance. Check `allowed_http_cidr`, the URL scheme, and the network path. |

Test from a terminal with `curl -sv --max-time 10 -o /dev/null http://<public_ip>`.

### Connection refused, and the boot log shows dnf was killed

**Symptom:** The boot log contains `Out of memory: Killed process ... (dnf)`
and `Killed dnf install -y nginx`.

**Cause:** A `t3.micro` has 1 GiB of memory and no swap. dnf can exceed that
while loading repository metadata at first boot.

**Fix:** The user data creates a 1 GiB swap file before running dnf and
retries the install. If you see this on an older copy of the lab, update
the template and apply. The instance is replaced because the user data changed.

### The page times out

Check these in order:

1. `allowed_http_cidr` matches the address your browser uses. VPNs and
   proxies change it. Compare with https://checkip.amazonaws.com in the
   same browser.
2. Wait 3 minutes after apply. NGINX installs on first boot.
3. Read the boot log without SSH:
   `aws ec2 get-console-output --instance-id <instance_id> --latest --output text | grep -iE 'nginx|dnf|error|fail|killed'`
4. Confirm the URL starts with `http://`, not `https://`. Lab 2 serves HTTP only.

### `dnf install` fails in the boot log

**Cause:** The instance cannot reach the package repositories over HTTPS.

**Fix:** Confirm the egress rule for TCP 443 exists, and that the subnet
routes `0.0.0.0/0` to the Lab 1 Internet Gateway.

### The public IP changed

An auto-assigned public IPv4 address is released when the instance stops.
Read the new address from a fresh plan's outputs, or from the EC2 console.

## Re-plan surprises

### A re-plan wants to replace the instance

| Cause | Expected? |
|---|---|
| A variable used by the success page changed | Yes. `user_data_replace_on_change` rebuilds the instance so the page matches. |
| `allowed_http_cidr` changed | No replacement. Only the ingress rule is updated in place. |
| A new Amazon Linux AMI was published | No. `ignore_changes = [ami]` prevents this. |

To move to the newest AMI on purpose, start a run with the **Replace
resources** planning option set to `aws_instance.web`.

### A push queued a plan that creates everything

Every push to the connected branch queues a plan. If the lab is destroyed,
that plan shows a full create. Discard it.

## Destroy problems

### Lab 1 destroy fails with `DependencyViolation`

**Cause:** The Lab 2 instance's network interface is still in a Lab 1 subnet.

**Fix:** Destroy Lab 2 first, then queue a new Lab 1 destroy plan.

### Partial destroy

Do not delete the remaining resources by hand. Fix the cause, such as a
missing permission, and queue a new destroy plan that lists only what remains.

## IAM policy simulator

### `ssm:GetParameter` shows `implicitDeny`

**Cause:** Without `--resource-arns`, the simulator tests against the
resource `*`, which never matches a statement scoped to a parameter path.

**Fix:** Simulate with the real parameter ARN:

```bash
aws iam simulate-principal-policy --policy-source-arn <user-arn> --action-names ssm:GetParameter --resource-arns arn:aws:ssm:us-east-1::parameter/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
```

### Conditioned actions show `implicitDeny`

`ec2:TerminateInstances`, `ec2:DeleteSecurityGroup`, and `ec2:RunInstances`
need context entries, such as `aws:ResourceTag/Purpose=Training` or
`ec2:InstanceType=t3.micro`, to simulate the real request.

# Cleanup Guide

Destroy Lab 2 as soon as you finish validating it. Lab 2 must be destroyed
before Lab 1.

## Destroy Lab 2

1. In the Lab 2 workspace, open **Settings > Destruction and Deletion**.
2. Choose **Queue destroy plan** and confirm the workspace name.
3. Review the destroy plan. Expect `Plan: 0 to add, 0 to change, 4 to destroy`:
   the instance, the security group, and the two rules. Nothing from Lab 1
   may appear.
4. Choose **Confirm & apply**, then **Confirm plan**.
5. Confirm the apply reports `Resources: 0 added, 0 changed, 4 destroyed`.

## Verify cleanup

Run these with an administrator or read-only AWS CLI profile. Replace
`<deployment_id>` with your value. Each command must return nothing.

6. No instance remains, other than terminated:
   ```bash
   aws ec2 describe-instances --filters Name=tag:DeploymentId,Values=<deployment_id> Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text
   ```
7. No security group remains:
   ```bash
   aws ec2 describe-security-groups --filters Name=tag:DeploymentId,Values=<deployment_id> --query 'SecurityGroups[].GroupId' --output text
   ```
8. No volume remains:
   ```bash
   aws ec2 describe-volumes --filters Name=tag:DeploymentId,Values=<deployment_id> --query 'Volumes[].VolumeId' --output text
   ```

A terminated instance stays visible in the console for about an hour. It
is not billed.

## After the destroy

9. Discard any plan that a later push queues. With the lab destroyed, it
   shows a full create.
10. If you are not continuing to the next lab, destroy Lab 1 using its own
    cleanup guide.

## Destroying Lab 1 in accounts with GuardDuty Runtime Monitoring

If GuardDuty Runtime Monitoring manages the EC2 agent automatically, it
creates a VPC endpoint and a security group in any VPC where an instance
runs. These are created by AWS, not Terraform, and they stop the Lab 1
private subnets and VPC from deleting. The Lab 1 destroy shows the private
subnets in **Deleting** for many minutes.

Destroy Lab 2 first, then run these with an administrator AWS CLI profile.
Replace `<vpc_id>` with the Lab 1 `vpc_id` output.

1. Find the GuardDuty endpoint. Look for the service
   `com.amazonaws.<region>.guardduty-data`:
   ```bash
   aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<vpc_id> --query 'VpcEndpoints[].[VpcEndpointId,ServiceName,State]' --output table
   ```
2. Delete that endpoint, using its ID:
   ```bash
   aws ec2 delete-vpc-endpoints --vpc-endpoint-ids <vpce_id>
   ```
3. Wait until no network interfaces remain in the VPC. This prints
   `interfaces gone` when finished:
   ```bash
   until [ -z "$(aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=<vpc_id> --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)" ]; do sleep 15; done; echo "interfaces gone"
   ```
4. Find the GuardDuty security group:
   ```bash
   aws ec2 describe-security-groups --filters Name=vpc-id,Values=<vpc_id> Name=group-name,Values=GuardDutyManagedSecurityGroup-* --query 'SecurityGroups[].GroupId' --output text
   ```
5. Delete it, using its ID:
   ```bash
   aws ec2 delete-security-group --group-id <sg_id>
   ```

If the Lab 1 destroy is still running, it finishes on its own. If it timed
out, queue a new Lab 1 destroy plan; it lists only the resources that remain.

Deleting these two GuardDuty resources is safe once no instance runs in the
VPC. GuardDuty creates them again the next time an instance launches there.
They are the only resources in this lab you delete by hand, because
Terraform does not own them.

## If the destroy fails partway

Do not delete the remaining resources in the console. Read the error, fix
the cause (often a missing IAM permission), and queue a new destroy plan.
It lists only what remains. Confirm it after review.

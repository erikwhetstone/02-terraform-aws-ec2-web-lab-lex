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

## If the destroy fails partway

Do not delete the remaining resources in the console. Read the error, fix
the cause (often a missing IAM permission), and queue a new destroy plan.
It lists only what remains. Confirm it after review.

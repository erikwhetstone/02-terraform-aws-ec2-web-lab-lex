locals {
  lab_name = "ec2-web"

  # Every resource name starts with deployment_id, so an administrator can
  # match a resource to the HCP Terraform workspace that owns it.
  name_prefix = "${var.deployment_id}-web"

  # User data runs once, at first boot. It installs NGINX and writes a
  # success page built from this deployment's own variables.
  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    owner_name      = var.owner_name
    deployment_id   = var.deployment_id
    lab_name        = local.lab_name
    aws_region      = var.aws_region
    expiration_date = var.expiration_date
  })
}

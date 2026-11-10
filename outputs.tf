output "website_url" {
  description = "Open this URL from the network in allowed_http_cidr. First boot can take up to 5 minutes before NGINX answers."
  value       = "http://${aws_instance.web.public_ip}"
}

output "instance_id" {
  description = "ID of the EC2 web server instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IPv4 address of the instance. Billed hourly while assigned and changes if the instance is stopped and started."
  value       = aws_instance.web.public_ip
}

output "availability_zone" {
  description = "Availability Zone of the selected Lab 1 public subnet."
  value       = aws_instance.web.availability_zone
}

output "security_group_id" {
  description = "ID of the web server security group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI the instance was launched from."
  value       = aws_instance.web.ami
}

output "vpc_id" {
  description = "Lab 1 VPC used by this lab."
  value       = data.aws_vpc.selected.id
}

output "public_subnet_id" {
  description = "Lab 1 public subnet used by this lab."
  value       = data.aws_subnet.selected.id
}

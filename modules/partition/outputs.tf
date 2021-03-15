output "public_subnet" {
  value       = aws_subnet.public_subnet
  description = "The public subnet of this partition."
}

output "sg_private_resource" {
  value       = aws_security_group.private_resource
  description = "The security group to assign to resources in the private subnet."
}
output "public_subnet" {
  value       = aws_subnet.public_subnet
  description = "The public subnet of this partition."
}
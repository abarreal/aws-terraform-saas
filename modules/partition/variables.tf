variable "workload" {
  type        = string
  description = "The name of the workload."
  default     = "SaaS-Demo"
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]*$", var.workload))
    error_message = "The name of the partition must match ^[a-zA-Z0-9\\-]*$."
  }
}

variable "aws_region" {
  type        = string
  description = "The region in which all resources will be deployed."
  default     = "us-east-2"
}

variable "partition_name" {
  type        = string
  description = "The name of the partition (e.g. Stage, Production, Marketing)."
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]*$", var.partition_name))
    error_message = "The name of the partition must match ^[a-zA-Z0-9\\-]*$."
  }
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which to instantiate the partition."
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR range of the VPC in which to instantiate the partition."
  default     = "10.0.0.0/16"
}

variable "igw_id" {
  type        = string
  description = "The ID of the Internet gateway of the VPC."
}

variable "pub_subnet_cidr" {
  type        = string
  description = "The CIDR range for the public subnet."
  default     = "10.0.0.0/24"
}

variable "nat_subnet_cidr" {
  type        = string
  description = "The CIDR range for the private subnet."
  default     = "10.0.1.0/24"
}
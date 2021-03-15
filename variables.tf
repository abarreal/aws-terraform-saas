variable "workload" {
  type        = string
  description = "The name of the workload."
  default     = "SaaS-Demo"
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]*$", var.workload))
    error_message = "The workload name must match ^[a-zA-Z0-9\\-]*$."
  }
}

variable "aws_region" {
  type        = string
  description = "The AWS region in which resources should be instantiated."
  default     = "us-east-2"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR range for the VPC."
  default     = "10.0.0.0/16"
}

variable "repository_name" {
  type        = string
  description = "The name of the repository holding the code for the web application."
  default     = "SaaS-Demo"
}

variable "source_branch_name" {
  type        = string
  description = "The source branch from which the CI/CD pipeline will pull source code."
  default     = "master"
}
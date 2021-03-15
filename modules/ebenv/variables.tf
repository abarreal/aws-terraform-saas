variable "workload" {
  type        = string
  description = "The name of the workload."
  default     = "SaaS-Demo"
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]*$", var.workload))
    error_message = "The workload name must match ^[a-zA-Z0-9\\-]*$."
  }
}

variable "app_name" {
  type        = string
  description = "The name of the Elastic Beanstalk application."
}

variable "env_name" {
  type        = string
  description = "The name of the environment (e.g. Stage, Production)."
}

variable "solution_stack_name" {
  type        = string
  description = "The EB solution stack name to use."
  default     = "64bit Amazon Linux 2 v5.3.0 running Node.js 14"
}

variable "instance_profile_name" {
  type        = string
  description = "The name of the instance profile to use."
}

variable "service_role_arn" {
  type        = string
  description = "The ARN of the service role to use."
}

variable "allowed_instance_types" {
  type        = string
  description = "Comma separated list of allowed instance types."
  default     = "t3.nano,t2.nano"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the environment should be created."
}

variable "subnets" {
  type        = string
  description = "Comma separated list of subnet IDs for the ASG."
}
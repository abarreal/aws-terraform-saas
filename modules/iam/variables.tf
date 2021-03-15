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
  description = "The region in which the resources will be hostd."
  default     = "us-east-2"
}

variable "repository_name" {
  type        = string
  description = "The name of the CodeCommit repository holding app code."
}

variable "artifact_store_bucket_name" {
  type        = string
  description = "The name of the S3 bucket in which the pipeline will store artifacts."
}

variable "pipeline_log_group_name" {
  type        = string
  description = "The name of the log group for the pipeline to log to."
}

variable "cb_test_project_name" {
  type        = string
  description = "The name of the CodeBuild project with which the pipeline runs tests."
}

variable "eb_web_app_name" {
  type        = string
  description = "The name of the web application in Elastic Beanstalk."
}
variable "workload" {
  type        = string
  description = "The name of the workload."
  default     = "SaaS-Demo"
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]*$", var.workload))
    error_message = "The name of the workload must match ^[a-zA-Z0-9\\-]*$."
  }
}

variable aws_region {
  type        = string
  description = "The region in which to run pipeline stages."
  default     = "us-east-2"
}

variable "source_repository_name" {
  type        = string
  description = "The name of the CodeCommit repository from which to pull source code."
}

variable "source_branch_name" {
  type        = string
  description = "The name of the branch from which to pull source code."
  default     = "master"
}

variable "log_group_name" {
  type        = string
  description = "The name of the log group to be created for the pipeline."
}

variable "log_retention_in_days" {
  type        = number
  description = "Log retention in days for the pipeline log group."
  default     = 1
}

variable "pipeline_service_role_arn" {
  type        = string
  description = "The ARN of the service role for the CI/CD pipeline."
}

variable "artifact_reader_role_arn" {
  type        = string
  description = "The ARN of a service role that can read artifacts and write logs."
}

variable "artifact_store_bucket_name" {
  type            = string
  description     = "The name of the bucket that will hold CI/CD artifacts."
  validation {
    condition     = can(regex("^[a-z0-9\\-]*$", var.artifact_store_bucket_name))
    error_message = "The name of the artifact store bucket must match ^[a-z0-9\\-]*$."
  }
}

variable "codebuild_test_project_name" {
  type        = string
  description = "The name of the CodeBuild project for the test stage."
}

variable "buildspec_test_stage" {
  type        = string
  description = "The name of the buildspec file for the test stage."
  default     = "buildspec.test.yml"
}

variable "eb_app_name" {
  type        = string
  description = "The name of the Elastic Beanstalk application."
}

variable "eb_stage_environment_name" {
  type        = string
  description = "The name of the staging environment in EB."
}

variable "eb_prod_environment_name" {
  type        = string
  description = "The name of the production environment in EB."
}
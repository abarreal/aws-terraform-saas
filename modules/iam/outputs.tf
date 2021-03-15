output "elastic_beanstalk_service_role" {
  value       = aws_iam_role.eb_service_role
  description = "The service role for Elastic Beanstalk."
}

output "elastic_beanstalk_instance_profile" {
  value       = aws_iam_instance_profile.eb_instance_profile
  description = "The instance profile for Elastic Beanstalk."
}

output "pipeline_service_role" {
  value       = aws_iam_role.pipeline_role
  description = "Service role for the CI/CD pipeline."
}

output "artifact_store_reader_role" {
  value       = aws_iam_role.artifact_store_reader
  description = "A role for CI/CD CodeBuild stages that only need to read artifacts."
}
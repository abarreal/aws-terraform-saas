locals {
  common_tags = {
    Workload = var.workload
  }
  artifact_store_tags = {
    Name = "${var.workload}-ArtifactStore"
  }
  log_group_tags = {
    Name = "${var.workload}-CICD"
  }
  pipeline_tags = {
    Name = "${var.workload}-CICD"
  }
  codebuild_test_stage_tags = {
    Name = "${var.workload}-TestStage"
  }
  app_artifact_name = "${var.workload}App"
}

# Define the artifact store: an S3 bucket in which to store artifacts generated
# by the CI/CD pipeline.
resource "aws_s3_bucket" "artifact_store" {
  bucket = var.artifact_store_bucket_name
  acl    = "private"
  tags   = merge(local.artifact_store_tags, local.common_tags) 
}

# Define the pipeline to to log to.
resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = merge(local.log_group_tags, local.common_tags)
}

# Define the project in CodeBuild to run local tests.
resource "aws_codebuild_project" "test_stage" {
  name           = var.codebuild_test_project_name
  description    = "${var.workload} - Test stage of the CI/CD pipeline."
  build_timeout  = 5
  queued_timeout = 5
  service_role   = var.artifact_reader_role_arn
  
  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_test_stage
  }
  
  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = var.log_group_name
      stream_name = "TestStage"
      status      = "ENABLED"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  tags = merge(local.codebuild_test_stage_tags, local.common_tags)
}

# Define the pipeline itself.
resource "aws_codepipeline" "main" {
  name        = local.pipeline_tags.Name
  role_arn    = var.pipeline_service_role_arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifact_store.bucket
  }

  stage {
    name = "Source"
    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeCommit"
      version  = 1
      region   = var.aws_region

      configuration = {
        RepositoryName       = var.source_repository_name
        BranchName           = var.source_branch_name
        PollForSourceChanges = false
        OutputArtifactFormat = "CODE_ZIP"
      }

      output_artifacts = [local.app_artifact_name]
    }
  }

  stage {
    name = "Test"
    action {
      name     = "Test"
      category = "Test"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = 1
      region   = var.aws_region

      configuration = {
        ProjectName = local.codebuild_test_stage_tags.Name
      }

      input_artifacts = [local.app_artifact_name]
    }  
  }

  stage {
    name = "Stage"
    action {
      name     = "Stage"
      category = "Deploy"
      provider = "ElasticBeanstalk"
      owner    = "AWS"
      version  = 1
      region   = var.aws_region

      configuration = {
        ApplicationName = var.eb_app_name
        EnvironmentName = var.eb_stage_environment_name
      }

      input_artifacts = [local.app_artifact_name]
    }
  }

  stage {
    name = "Approve"
    action {
      name     = "Approve"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = 1
    }
  }

  stage {
    name = "Production"
    action {
      name     = "Production"
      category = "Deploy"
      provider = "ElasticBeanstalk"
      owner    = "AWS"
      version  = 1
      region   = var.aws_region

      configuration = {
        ApplicationName = var.eb_app_name
        EnvironmentName = var.eb_prod_environment_name
      }

      input_artifacts = [local.app_artifact_name]
    }
  }

  tags = merge(local.pipeline_tags, local.common_tags)
}
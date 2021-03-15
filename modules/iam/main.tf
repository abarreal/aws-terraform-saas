# Defines roles and policies for the SaaS architecture.
# Get access to the caller identity (account ID).
data "aws_caller_identity" "current" {}

locals {
  # Define a shorthand for the account ID.
  account_id = data.aws_caller_identity.current.account_id
}

locals {
  # Define the ARN of the CodeCommit repository holding application code.
  # Application developers will get read/write access to this repository.
  repo_arn = "arn:aws:codecommit:${var.aws_region}:${local.account_id}:${var.repository_name}"
  # Define the ARN of the artifact store S3 bucket.
  artifact_store_arn = "arn:aws:s3:::${var.artifact_store_bucket_name}"
  # Define the ARN of the log group to which the pipeline will log.
  pipeline_log_group_arn = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.pipeline_log_group_name}"
  # Define the ARN of the log group that CodeBuild writes to.
  cb_log_group_arn = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/codebuild/${var.workload}"
  # Define the ARN of the CodeBuild project for the test stage.
  cb_test_stage_project = "arn:aws:codebuild:${var.aws_region}:${local.account_id}:project/${var.cb_test_project_name}"
  # Define the ARN of the web application in Elastic Beanstalk.
  eb_web_app_env_arn = "arn:aws:elasticbeanstalk:${var.aws_region}:${local.account_id}:environment/${var.eb_web_app_name}"
  # Define the ARN of the EB application.
  eb_web_app_arn = "arn:aws:elasticbeanstalk:${var.aws_region}:${local.account_id}:application/${var.eb_web_app_name}"
  # Define the ARN of the set of application versions for the app.
  eb_web_app_versions = "arn:aws:elasticbeanstalk:${var.aws_region}:${local.account_id}:applicationversion/${var.eb_web_app_name}/*"

  common_tags = {
    Workload = var.workload
  }
}

#==============================================================================
#==============================================================================
# Define generic policies.

data "aws_iam_policy_document" "account_access" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "codebuild_access" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pipeline_access" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "codepipeline.amazonaws.com",
        "codebuild.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "eb_access" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_access" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

#==============================================================================
#==============================================================================
# Define a role and policies for app developers.

data "aws_iam_policy_document" "app_dev_policy" {
  statement {
    actions = [
      "codecommit:GitPush",
      "codecommit:GitPull"
    ]
    resources = [local.repo_arn]
  }
}

resource "aws_iam_policy" "app_dev_policy" {
  name        = "${var.workload}-AppDeveloper"
  description = "Grants developer access to the repository holding app code."
  policy      = data.aws_iam_policy_document.app_dev_policy.json
}

resource "aws_iam_role" "app_dev_role" {
  name                = "${var.workload}-AppDeveloper"
  assume_role_policy  = data.aws_iam_policy_document.account_access.json
  managed_policy_arns = [aws_iam_policy.app_dev_policy.arn]
  tags                = local.common_tags
}

#==============================================================================
#==============================================================================
# Define roles and policies for the CI/CD pipeline to perform its functions.

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Define a policy that allows pulling source code from the Code Commit
# repository, as well as other tasks that the CI/CD pipeline must execute.

data "aws_iam_policy_document" "source_code_reader_policy" {
  statement {
    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GitPull",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:CancelUploadArchive"
    ]
    resources = [local.repo_arn]
  }
}

resource "aws_iam_policy" "source_code_reader_policy" {
  name        = "${var.workload}-SourceCodeReader"
  description = "Allows the CI/CD pipeline to use the code repository."
  policy      = data.aws_iam_policy_document.source_code_reader_policy.json
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Define a policy that allows reading from the artifact store.

data "aws_iam_policy_document" "artifact_store_reader_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${local.artifact_store_arn}/*"]
  }
}

resource "aws_iam_policy" "artifact_store_reader_policy" {
  name        = "${var.workload}-ArtifactStoreReader"
  description = "Allow reading from the artifact store."
  policy      = data.aws_iam_policy_document.artifact_store_reader_policy.json
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Define a policy that allows writing logs to the log group used by the
# CI/CD pipeline, and to a log group used by CodeBuild.

data "aws_iam_policy_document" "pipeline_log_writer_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${local.pipeline_log_group_arn}:*",
      "${local.cb_log_group_arn}:*"
    ]
  }
}

resource "aws_iam_policy" "pipeline_log_writer_policy" {
  name        = "${var.workload}-PipelineLogWriter"
  description = "Allows logging to the pipeline log group."
  policy      = data.aws_iam_policy_document.pipeline_log_writer_policy.json
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Define a role that can read artifacts from the artifact store. It will be 
# used by code build, so it needs some permissions to write logs as well.

resource "aws_iam_role" "artifact_store_reader" {
  name               = "${var.workload}-ArtifactReader"
  assume_role_policy = data.aws_iam_policy_document.codebuild_access.json
  managed_policy_arns = [
    aws_iam_policy.artifact_store_reader_policy.arn,
    aws_iam_policy.pipeline_log_writer_policy.arn
  ]
  tags = local.common_tags
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Define a role for the CI/CD pipeline. The policy is the same as the one
# generated by default by CodePipeline when requested to create a service role.

data "aws_iam_policy_document" "codepipeline_service_role_policy" {

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = [
        "cloudformation.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  statement {
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetRepository",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:ListFunctions"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "opsworks:CreateDeployment",
      "opsworks:DescribeApps",
      "opsworks:DescribeCommands",
      "opsworks:DescribeDeployments",
      "opsworks:DescribeInstances",
      "opsworks:DescribeStacks",
      "opsworks:UpdateApp",
      "opsworks:UpdateStack"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:ValidateTemplate"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetBuildBatches",
      "codebuild:StartBuildBatch"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "devicefarm:ListProjects",
      "devicefarm:ListDevicePools",
      "devicefarm:GetRun",
      "devicefarm:GetUpload",
      "devicefarm:CreateUpload",
      "devicefarm:ScheduleRun"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "servicecatalog:ListProvisioningArtifacts",
      "servicecatalog:CreateProvisioningArtifact",
      "servicecatalog:DescribeProvisioningArtifact",
      "servicecatalog:DeleteProvisioningArtifact",
      "servicecatalog:UpdateProduct"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "cloudformation:ValidateTemplate"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "ec2:DescribeImages"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "states:DescribeExecution",
      "states:DescribeStateMachine",
      "states:StartExecution"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "appconfig:StartDeployment",
      "appconfig:StopDeployment",
      "appconfig:GetDeployment"
    ]
    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "codepipeline_service_role_policy" {
  name        = "${var.workload}-CodePipelineServiceRole"
  description = "Similar to the policy generated by CodePipeline by default."
  policy      = data.aws_iam_policy_document.codepipeline_service_role_policy.json
}

resource "aws_iam_role" "pipeline_role" {
  name                = "${var.workload}-Pipeline"
  assume_role_policy  = data.aws_iam_policy_document.pipeline_access.json
  managed_policy_arns = [
    aws_iam_policy.codepipeline_service_role_policy.arn
  ]
  tags = local.common_tags
}

#==============================================================================
#==============================================================================
# Define a service role for Elastic Beanstalk. Taken without modifications from
# the official documentation.
#
# https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts-roles-service.html

data "aws_iam_policy_document" "eb_service_role" {
  statement {
    actions = [
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetHealth",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:GetConsoleOutput",
      "ec2:AssociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeSecurityGroups",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeNotificationConfigurations",
      "sns:Publish"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eb_service_role" {
  name        = "${var.workload}-ElasticBeanstalkServiceRole"
  description = "Policy for the service role to be set on Elastic Beanstalk."
  policy      = data.aws_iam_policy_document.eb_service_role.json
}

resource "aws_iam_role" "eb_service_role" {
  name                = "${var.workload}-ElasticBeanstalkServiceRole"
  assume_role_policy  = data.aws_iam_policy_document.eb_access.json
  managed_policy_arns = [aws_iam_policy.eb_service_role.arn]
  tags                = local.common_tags
}

#==============================================================================
#==============================================================================
# Define an instance profile for Elastic Beanstalk. Taken without modifications
# from the official documentation.
#
# https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts-roles-instance.html

data "aws_iam_policy_document" "eb_instance_profile_policy" {

  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::elasticbeanstalk-*",
      "arn:aws:s3:::elasticbeanstalk-*/*"
    ]
  }

  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/elasticbeanstalk*"
    ]
  }

  statement {
    actions = [
      "elasticbeanstalk:PutInstanceStatistics"
    ]
    resources = [
      "arn:aws:elasticbeanstalk:*:*:application/*",
      "arn:aws:elasticbeanstalk:*:*:environment/*"
    ]
  }

}

resource "aws_iam_policy" "eb_instance_profile_policy" {
  name        = "${var.workload}-ElasticBeanstalkInstanceProfile"
  description = "Policy for the service role to be set on Elastic Beanstalk."
  policy      = data.aws_iam_policy_document.eb_instance_profile_policy.json
}

resource "aws_iam_role" "eb_instance_profile_role" {
  name                = "${var.workload}-ElasticBeanstalkInstanceProfile"
  assume_role_policy  = data.aws_iam_policy_document.ec2_access.json
  managed_policy_arns = [aws_iam_policy.eb_instance_profile_policy.arn]
  tags                = local.common_tags
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "${var.workload}-ElasticBeanstalkInstanceProfile"
  role = aws_iam_role.eb_instance_profile_role.name
}
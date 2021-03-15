terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
}

locals {
  common_tags = {
    Workload = var.workload
  }
  vpc_tags = {
    Name = "${var.workload}-VPC"
  }
  igw_tags = {
    Name = "${var.workload}-InternetGateway"
  }
  default_sg_tags = {
    Name = "${var.workload}-Default"
  }
  
  # Define the name for the CodeBuild project that will handle the testing
  # stage of the CI/CD pipeline.
  codebuild_test_project_name = "${var.workload}-TestStage"
  # Define the name of the log group to which the CI/CD pipeline should log.
  pipeline_log_group_name = "${var.workload}-CICD"
  # Define the name of the artifact store used by the CI/CD pipeline.
  pipeline_artifact_store_name = "${lower(var.workload)}-artifacts"
  # Define the name of the Elastic Beanstalk web application.
  elastic_beanstalk_web_app_name = var.workload

  # Define the CIDR ranges for the subnets.
  production_cidr_ranges = {
    pub_subnet = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
    prv_subnet = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  }
  stage_cidr_ranges = {
    pub_subnet = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
    prv_subnet = cidrsubnet(aws_vpc.main.cidr_block, 8, 3)
  }
}

#==============================================================================
# IAM
#------------------------------------------------------------------------------
module "iam" {
  source                     = "./modules/iam"
  workload                   = var.workload
  aws_region                 = var.aws_region
  repository_name            = var.repository_name
  artifact_store_bucket_name = local.pipeline_artifact_store_name
  eb_web_app_name            = local.elastic_beanstalk_web_app_name
  pipeline_log_group_name    = local.pipeline_log_group_name
  cb_test_project_name       = local.codebuild_test_project_name
}

#==============================================================================
# VPC
#------------------------------------------------------------------------------

# Instantiate a new VPC to host the architecture.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = false
  instance_tenancy     = "default"
  tags                 = merge(local.common_tags, local.vpc_tags)
}

# Define a closed default security group.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.default_sg_tags, local.common_tags)
}

# Assign an Internet gateway to the VPC.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, local.igw_tags)
}

# Instantiate partitions (isolated public-private subnet pairs, for our 
# purposes) for a staging environment and a productive environment.
module "production_partition" {
  source              = "./modules/partition"
  workload            = var.workload
  aws_region          = var.aws_region
  partition_name      = "Production"
  vpc_id              = aws_vpc.main.id
  vpc_cidr            = aws_vpc.main.cidr_block
  igw_id              = aws_internet_gateway.igw.id
  public_subnet_cidr  = local.production_cidr_ranges.pub_subnet
  private_subnet_cidr = local.production_cidr_ranges.prv_subnet
}

module "staging_partition" {
  source              = "./modules/partition"
  workload            = var.workload
  aws_region          = var.aws_region
  partition_name      = "Stage"
  vpc_id              = aws_vpc.main.id
  vpc_cidr            = aws_vpc.main.cidr_block
  igw_id              = aws_internet_gateway.igw.id
  public_subnet_cidr  = local.stage_cidr_ranges.pub_subnet
  private_subnet_cidr = local.stage_cidr_ranges.prv_subnet
}

#==============================================================================
# Elastic Beanstalk
#------------------------------------------------------------------------------

# Create an application.
resource "aws_elastic_beanstalk_application" "web" {
  name        = local.elastic_beanstalk_web_app_name
  description = "${var.workload} - Web application."
  appversion_lifecycle {
    service_role          = module.iam.elastic_beanstalk_service_role.arn
    max_count             = 30
    delete_source_from_s3 = true
  }
  tags = local.common_tags
}

# Instantiate environments.
module "stage_environment" {
  depends_on             = [ aws_elastic_beanstalk_application.web ]
  source                 = "./modules/ebenv"
  workload               = var.workload
  app_name               = local.elastic_beanstalk_web_app_name
  env_name               = "Stage"
  solution_stack_name    = "64bit Amazon Linux 2 v5.3.0 running Node.js 14"
  instance_profile_name  = module.iam.elastic_beanstalk_instance_profile.name
  service_role_arn       = module.iam.elastic_beanstalk_service_role.arn
  allowed_instance_types = "t3.nano,t2.nano"
  vpc_id                 = aws_vpc.main.id
  subnets                = module.staging_partition.public_subnet.id
}

module "production_environment" {
  depends_on             = [ aws_elastic_beanstalk_application.web ]
  source                 = "./modules/ebenv"
  workload               = var.workload
  app_name               = local.elastic_beanstalk_web_app_name
  env_name               = "Production"
  solution_stack_name    = "64bit Amazon Linux 2 v5.3.0 running Node.js 14"
  instance_profile_name   = module.iam.elastic_beanstalk_instance_profile.name
  service_role_arn       = module.iam.elastic_beanstalk_service_role.arn
  allowed_instance_types = "t3.nano,t2.nano"
  vpc_id                 = aws_vpc.main.id
  subnets                = module.production_partition.public_subnet.id
}

#==============================================================================
# CI/CD Pipeline
#------------------------------------------------------------------------------
module "cicd_pipeline" {
  depends_on = [module.stage_environment, module.production_environment]
  
  source                      = "./modules/pipeline"
  workload                    = var.workload
  aws_region                  = var.aws_region
  source_repository_name      = var.repository_name
  source_branch_name          = var.source_branch_name
  log_group_name              = local.pipeline_log_group_name
  log_retention_in_days       = 1
  pipeline_service_role_arn   = module.iam.pipeline_service_role.arn
  artifact_reader_role_arn    = module.iam.artifact_store_reader_role.arn
  artifact_store_bucket_name  = local.pipeline_artifact_store_name
  codebuild_test_project_name = local.codebuild_test_project_name
  buildspec_test_stage        = "buildspec.test.yml"
  eb_app_name                 = aws_elastic_beanstalk_application.web.name
  eb_stage_environment_name   = module.stage_environment.environment_name
  eb_prod_environment_name    = module.production_environment.environment_name
}

#==============================================================================
# Resource Group
#------------------------------------------------------------------------------
# Instantiate a resource group to keep track of all resources instantiated by
# Terraform for this stack.

resource "aws_resourcegroups_group" "workload" {
  name = var.workload
  resource_query {
    query = jsonencode({
      ResourceTypeFilters = [
        "AWS::AllSupported"
      ]
      TagFilters = [
        {
          Key    = "Workload"
          Values = [var.workload]
        }
      ]
    })
  }
  # Ensure that all resources have been created.
  depends_on = [
    module.iam,
    aws_vpc.main,
    aws_internet_gateway.igw,
    module.production_partition,
    module.staging_partition,
    aws_elastic_beanstalk_application.web
  ]
}
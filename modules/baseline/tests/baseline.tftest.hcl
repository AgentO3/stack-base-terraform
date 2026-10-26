mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      name   = "us-east-1"
    }
  }
}

variables {
  name_prefix       = "base-test"
  environment       = "dev"
  region            = "us-east-1"
  approved_regions  = ["us-east-1", "us-west-2"]
  github_repository = "example/base-terraform"
  state_bucket_name = "example-tfstate"

  tags = {
    Owner       = "platform"
    CostCenter  = "engineering"
    Application = "base-terraform"
  }
}

run "audit_key_is_rotated" {
  command = plan

  assert {
    condition     = aws_kms_key.logs.enable_key_rotation
    error_message = "The audit log KMS key must rotate."
  }
}

run "log_bucket_blocks_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_acls
    error_message = "block_public_acls must be on."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_policy
    error_message = "block_public_policy must be on."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.ignore_public_acls
    error_message = "ignore_public_acls must be on."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.restrict_public_buckets
    error_message = "restrict_public_buckets must be on."
  }
}

run "log_bucket_is_versioned_and_encrypted" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_versioning.logs.versioning_configuration).status == "Enabled"
    error_message = "The audit log bucket must be versioned."
  }

  assert {
    condition = one([
      for rule in aws_s3_bucket_server_side_encryption_configuration.logs.rule :
      one(rule.apply_server_side_encryption_by_default).sse_algorithm
    ]) == "aws:kms"
    error_message = "The audit log bucket must use KMS encryption."
  }

  assert {
    condition = one([
      for rule in aws_s3_bucket_lifecycle_configuration.logs.rule :
      one(rule.expiration).days
    ]) == var.log_retention_days
    error_message = "The audit log bucket must expire objects at log_retention_days."
  }
}

run "account_public_access_block_is_on" {
  command = plan

  assert {
    condition     = aws_s3_account_public_access_block.main.restrict_public_buckets
    error_message = "Account-level S3 public access must be blocked."
  }
}

run "trail_is_multi_region_and_validated" {
  command = plan

  assert {
    condition     = aws_cloudtrail.main.is_multi_region_trail
    error_message = "CloudTrail must be a multi-Region trail."
  }

  assert {
    condition     = aws_cloudtrail.main.enable_log_file_validation
    error_message = "CloudTrail must validate log file integrity."
  }

  assert {
    condition     = aws_cloudtrail.main.include_global_service_events
    error_message = "CloudTrail must include global service events."
  }
}

run "log_groups_have_bounded_retention" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.trail.retention_in_days == var.log_retention_days
    error_message = "The trail log group must set retention_in_days."
  }
}

run "config_recorder_is_enabled" {
  command = plan

  assert {
    condition     = aws_config_configuration_recorder_status.main.is_enabled
    error_message = "AWS Config recording must be enabled."
  }

  assert {
    condition     = one(aws_config_configuration_recorder.main.recording_group).all_supported
    error_message = "AWS Config must record all supported resource types."
  }
}

run "budget_has_forecast_and_actual_alerts" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == tostring(var.monthly_budget_usd)
    error_message = "The budget limit must match monthly_budget_usd."
  }

  assert {
    condition     = aws_budgets_budget.monthly.time_unit == "MONTHLY"
    error_message = "The budget must be evaluated monthly."
  }

  assert {
    condition     = aws_budgets_budget.monthly.budget_type == "COST"
    error_message = "The budget must track cost."
  }
}

run "deploy_role_is_named_for_the_stack" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy.name == "base-test-deploy"
    error_message = "The deploy role must be named after the stack prefix."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "The module must create the GitHub OIDC provider when none is supplied."
  }
}

run "deploy_role_locks_state_in_s3" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.deploy.policy, "arn:aws:s3:::example-tfstate/*")
    error_message = "The deploy role must reach the state bucket objects, which include the .tflock object."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.deploy.policy, "dynamodb:")
    error_message = "The deploy role must not grant DynamoDB actions; state locks use S3 lockfiles (ADR-010)."
  }
}

run "rejects_unapproved_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_malformed_region" {
  command = plan

  variables {
    region = "not-a-region"
  }

  expect_failures = [var.region]
}

run "requires_baseline_tags" {
  command = plan

  variables {
    tags = {
      Owner = "platform"
    }
  }

  expect_failures = [var.tags]
}

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

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }
}

variables {
  environment       = "dev"
  region            = "us-east-1"
  state_bucket_name = "example-tfstate"
  state_lock_table  = "example-tflock"
  model_ids         = ["amazon.nova-lite-v1:0"]

  tags = {
    Owner       = "platform"
    CostCenter  = "engineering"
    Application = "aws-bedrock"
  }
}

run "guardrail_blocks_prompt_attack" {
  command = plan

  assert {
    condition = contains(
      [for filter in one(aws_bedrock_guardrail.main.content_policy_config).filters_config : filter.type],
      "PROMPT_ATTACK"
    )
    error_message = "The guardrail must filter prompt attacks."
  }

  assert {
    condition = alltrue([
      for filter in one(aws_bedrock_guardrail.main.content_policy_config).filters_config :
      filter.input_strength == "HIGH"
    ])
    error_message = "Every content filter must block at HIGH input strength."
  }
}

run "guardrail_redacts_pii" {
  command = plan

  assert {
    condition = contains(
      [for entity in aws_bedrock_guardrail.main.sensitive_information_policy_config[0].pii_entities_config : "${entity.type}:${entity.action}"],
      "EMAIL:ANONYMIZE"
    )
    error_message = "Email addresses must be anonymised."
  }

  assert {
    condition = contains(
      [for entity in aws_bedrock_guardrail.main.sensitive_information_policy_config[0].pii_entities_config : "${entity.type}:${entity.action}"],
      "US_SOCIAL_SECURITY_NUMBER:BLOCK"
    )
    error_message = "Social security numbers must be blocked."
  }
}

run "guardrail_version_is_published" {
  command = plan

  assert {
    condition     = aws_bedrock_guardrail.main.name == "base-bedrock-dev"
    error_message = "The guardrail must be named for the project and environment."
  }

  assert {
    condition     = aws_bedrock_guardrail_version.main.description == "Initial baseline guardrail."
    error_message = "The published version must be described."
  }
}

run "prompt_logging_is_enabled" {
  command = plan

  assert {
    condition     = one(aws_bedrock_model_invocation_logging_configuration.main.logging_config).text_data_delivery_enabled
    error_message = "Prompt and response text logging must be enabled."
  }

  assert {
    condition     = aws_cloudwatch_log_group.prompts.retention_in_days == var.log_retention_days
    error_message = "The prompt log group must set retention_in_days."
  }

  assert {
    condition     = aws_kms_key.prompts.enable_key_rotation
    error_message = "The prompt log key must rotate."
  }
}

run "invoke_role_covers_only_the_approved_models" {
  command = plan

  assert {
    condition     = length(var.model_ids) == 1 && var.model_ids[0] == "amazon.nova-lite-v1:0"
    error_message = "The test must exercise exactly the configured model."
  }

  assert {
    condition     = aws_iam_role.invoke.name == "base-bedrock-dev-invoke"
    error_message = "The invoke role must be named for the project and environment."
  }
}

run "deploy_role_is_project_scoped" {
  command = plan

  assert {
    condition     = aws_iam_role.deploy[0].name == "base-bedrock-dev-deploy"
    error_message = "The deploy role must be named for the project and environment."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.model) == 5 * length(var.alarm_model_ids)
    error_message = "Each monitored model gets five alarms."
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

run "rejects_empty_model_list" {
  command = plan

  variables {
    model_ids = []
  }

  expect_failures = [var.model_ids]
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

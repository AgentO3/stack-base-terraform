locals {
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "base-terraform"
    Project     = "aws-bedrock"
  })

  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  model_arns = [
    for model in var.model_ids :
    "arn:${local.partition}:bedrock:${local.region}::foundation-model/${model}"
  ]

  alarm_metrics = {
    throttles = {
      metric     = "InvocationThrottles"
      statistic  = "Sum"
      threshold  = 1
      comparison = "GreaterThanOrEqualToThreshold"
    }
    server_errors = {
      metric     = "InvocationServerErrors"
      statistic  = "Sum"
      threshold  = 1
      comparison = "GreaterThanOrEqualToThreshold"
    }
    latency = {
      metric     = "InvocationLatency"
      statistic  = "Average"
      threshold  = 10000
      comparison = "GreaterThanThreshold"
    }
    input_tokens = {
      metric     = "InputTokenCount"
      statistic  = "Sum"
      threshold  = 1000000
      comparison = "GreaterThanThreshold"
    }
    output_tokens = {
      metric     = "OutputTokenCount"
      statistic  = "Sum"
      threshold  = 1000000
      comparison = "GreaterThanThreshold"
    }
  }

  project_resources = {
    guardrail   = "arn:${local.partition}:bedrock:${local.region}:${local.account_id}:guardrail/*"
    log_group   = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock/${var.environment}/invocations*"
    alarms      = "arn:${local.partition}:cloudwatch:${local.region}:${local.account_id}:alarm:base-bedrock-${var.environment}-*"
    roles       = "arn:${local.partition}:iam::${local.account_id}:role/base-bedrock-${var.environment}-*"
    policies    = "arn:${local.partition}:iam::${local.account_id}:policy/base-bedrock-${var.environment}-*"
    kms_keys    = "arn:${local.partition}:kms:${local.region}:${local.account_id}:key/*"
    state       = "arn:${local.partition}:s3:::${var.state_bucket_name}"
    state_objs  = "arn:${local.partition}:s3:::${var.state_bucket_name}/*"
    oidc_issuer = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# --- Prompt and response logging -------------------------------------------

resource "aws_kms_key" "prompts" {
  description             = "Base Bedrock ${var.environment} prompt and response logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_alias" "prompts" {
  name          = "alias/base-bedrock-${var.environment}-prompts"
  target_key_id = aws_kms_key.prompts.key_id
}

resource "aws_kms_key_policy" "prompts" {
  key_id = aws_kms_key.prompts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountAdministration"
      Effect    = "Allow"
      Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "prompts" {
  name              = "/aws/bedrock/${var.environment}/invocations"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.prompts.arn

  tags = local.tags
}

resource "aws_iam_role" "invocation_logging" {
  name = "base-bedrock-${var.environment}-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "invocation_logging" {
  name = "write-prompt-logs"
  role = aws_iam_role.invocation_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.prompts.arn}:*"
    }]
  })
}

resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  logging_config {
    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.prompts.name
      role_arn       = aws_iam_role.invocation_logging.arn
    }
    text_data_delivery_enabled  = true
    image_data_delivery_enabled = false
  }

  depends_on = [aws_iam_role_policy.invocation_logging]
}

# --- Guardrail --------------------------------------------------------------

resource "aws_bedrock_guardrail" "main" {
  name                      = "base-bedrock-${var.environment}"
  description               = "Baseline guardrail: harmful content, PII and off-topic requests."
  blocked_input_messaging   = "That request is not allowed by this application's policy."
  blocked_outputs_messaging = "The response was withheld by this application's policy."

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }

    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }

    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }

    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }

    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }

    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }

    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }

    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "investment-advice"
      type       = "DENY"
      definition = "Advice about buying, selling or holding financial instruments."
      examples = [
        "Should I buy index funds now?",
        "Which stock will go up next quarter?",
      ]
    }
  }

  tags = local.tags
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Initial baseline guardrail."
}

# --- Application invocation role -------------------------------------------

resource "aws_iam_role" "invoke" {
  name = "base-bedrock-${var.environment}-invoke"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "ecs-tasks.amazonaws.com"]
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "invoke" {
  name = "invoke-approved-models"
  role = aws_iam_role.invoke.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeApprovedModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = local.model_arns
      },
      {
        Sid    = "ApplyGuardrail"
        Effect = "Allow"
        Action = "bedrock:ApplyGuardrail"
        Resource = [
          aws_bedrock_guardrail.main.guardrail_arn,
          "${aws_bedrock_guardrail.main.guardrail_arn}/*",
        ]
      },
    ]
  })
}

# --- Project-scoped CI deploy role -----------------------------------------

resource "aws_iam_role" "deploy" {
  count = var.create_deploy_role ? 1 : 0

  name = "base-bedrock-${var.environment}-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "deploy" {
  count = var.create_deploy_role ? 1 : 0

  name = "deploy-aws-bedrock"
  role = aws_iam_role.deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.project_resources.state, local.project_resources.state_objs]
      },
      {
        Sid    = "BedrockProject"
        Effect = "Allow"
        Action = [
          "bedrock:CreateGuardrail",
          "bedrock:UpdateGuardrail",
          "bedrock:DeleteGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:ListGuardrails",
          "bedrock:CreateGuardrailVersion",
          "bedrock:DeleteGuardrailVersion",
          "bedrock:GetGuardrailVersion",
          "bedrock:ListGuardrailVersions",
          "bedrock:PutModelInvocationLoggingConfiguration",
          "bedrock:GetModelInvocationLoggingConfiguration",
          "bedrock:DeleteModelInvocationLoggingConfiguration",
          "bedrock:TagResource",
          "bedrock:UntagResource",
        ]
        Resource = local.project_resources.guardrail
      },
      {
        Sid      = "PromptLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:TagResource", "logs:UntagResource"]
        Resource = local.project_resources.log_group
      },
      {
        Sid      = "ProjectRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:UpdateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions"]
        Resource = [local.project_resources.roles, local.project_resources.policies]
      },
      {
        Sid      = "PromptKeys"
        Effect   = "Allow"
        Action   = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:Get*", "kms:List*", "kms:Put*", "kms:Update*", "kms:TagResource", "kms:UntagResource"]
        Resource = local.project_resources.kms_keys
      },
      {
        Sid      = "Alarms"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
        Resource = local.project_resources.alarms
      },
      {
        Sid      = "CallerIdentity"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
}

# --- Alarms ----------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "model" {
  for_each = {
    for pair in setproduct(var.alarm_model_ids, keys(local.alarm_metrics)) :
    "${pair[0]}|${pair[1]}" => { model = pair[0], metric_key = pair[1] }
  }

  alarm_name          = "base-bedrock-${var.environment}-${replace(each.value.model, "/[^a-zA-Z0-9-]/", "-")}-${each.value.metric_key}"
  namespace           = "AWS/Bedrock"
  metric_name         = local.alarm_metrics[each.value.metric_key].metric
  dimensions          = { ModelId = each.value.model }
  statistic           = local.alarm_metrics[each.value.metric_key].statistic
  period              = 300
  evaluation_periods  = 1
  threshold           = local.alarm_metrics[each.value.metric_key].threshold
  comparison_operator = local.alarm_metrics[each.value.metric_key].comparison
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]

  tags = local.tags
}

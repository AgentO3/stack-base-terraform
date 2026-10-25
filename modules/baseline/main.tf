locals {
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "base-terraform"
  })

  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  oidc_provider_arn = var.github_oidc_provider_arn != null ? var.github_oidc_provider_arn : one(aws_iam_openid_connect_provider.github[*].arn)

  state_bucket_resources = var.state_bucket_name == "" ? [] : [
    "arn:${local.partition}:s3:::${var.state_bucket_name}",
    "arn:${local.partition}:s3:::${var.state_bucket_name}/*",
  ]

  state_lock_resources = var.state_lock_table == "" ? [] : [
    "arn:${local.partition}:dynamodb:${local.region}:${local.account_id}:table/${var.state_lock_table}",
  ]

  managed_bucket_arns = [
    "arn:${local.partition}:s3:::${var.name_prefix}-*",
    "arn:${local.partition}:s3:::${var.name_prefix}-*/*",
  ]

  manage_bucket_arns = concat(local.managed_bucket_arns, local.state_bucket_resources)

  iam_role_arns   = ["arn:${local.partition}:iam::${local.account_id}:role/${var.name_prefix}-*"]
  iam_policy_arns = ["arn:${local.partition}:iam::${local.account_id}:policy/${var.name_prefix}-*"]
  oidc_provider_arn_scope = [
    "arn:${local.partition}:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com",
  ]
  kms_key_arns   = ["arn:${local.partition}:kms:${local.region}:${local.account_id}:key/*"]
  log_group_arns = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/cloudtrail/${var.name_prefix}*"]
  trail_arns     = ["arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/*"]
  config_arns    = ["arn:${local.partition}:config:${local.region}:${local.account_id}:*"]
  budget_arns    = ["arn:${local.partition}:budgets::${local.account_id}:budget/*"]
  sns_topic_arns = ["arn:${local.partition}:sns:${local.region}:${local.account_id}:${var.name_prefix}-*"]
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# --- Encryption -------------------------------------------------------------

resource "aws_kms_key" "logs" {
  description             = "${var.name_prefix} audit log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_kms_key_policy" "logs" {
  key_id = aws_kms_key.logs.id

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

# --- Audit log bucket -------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${var.name_prefix}-logs-"
  force_destroy = false

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
        }
      },
    ]
  })
}

# --- CloudTrail -------------------------------------------------------------

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = local.tags
}

resource "aws_iam_role" "cloudtrail" {
  name = "${var.name_prefix}-cloudtrail"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  name = "cloudtrail-cloudwatch-logs"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

resource "aws_sns_topic" "trail" {
  name              = "${var.name_prefix}-trail-events"
  kms_master_key_id = aws_kms_key.logs.id

  tags = local.tags
}

resource "aws_sns_topic_policy" "trail" {
  arn = aws_sns_topic.trail.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudTrailPublish"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.trail.arn
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  sns_topic_name                = aws_sns_topic.trail.name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.logs.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn

  depends_on = [aws_s3_bucket_policy.logs]

  tags = local.tags
}

# --- AWS Config -------------------------------------------------------------

resource "aws_s3_bucket" "config" {
  bucket_prefix = "${var.name_prefix}-config-"
  force_destroy = false

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "expire-config-snapshots"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_delivery" {
  name = "config-delivery"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.config.arn}/config/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl"]
        Resource = aws_s3_bucket.config.arn
      },
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  s3_key_prefix  = "config"

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# --- Account-level S3 guardrail --------------------------------------------

resource "aws_s3_account_public_access_block" "main" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Budget alerts ----------------------------------------------------------

resource "aws_sns_topic" "budget" {
  name              = "${var.name_prefix}-budget"
  kms_master_key_id = aws_kms_key.logs.id

  tags = local.tags
}

resource "aws_sns_topic_policy" "budget" {
  arn = aws_sns_topic.budget.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBudgetsPublish"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.budget.arn
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "budget_email" {
  count = var.budget_notification_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.budget.arn
  protocol  = "email"
  endpoint  = var.budget_notification_email
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.budget.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget.arn]
  }
}

# --- Workload identity for CI ----------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "deploy" {
  name = "${var.name_prefix}-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
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
  name = "deploy-baseline"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = local.state_bucket_resources
      },
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = local.state_lock_resources
      },
      {
        Sid    = "ManagedBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucket*",
          "s3:PutBucket*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",
        ]
        Resource = local.manage_bucket_arns
      },
      {
        Sid      = "AuditKeys"
        Effect   = "Allow"
        Action   = ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:Get*", "kms:List*", "kms:Put*", "kms:Update*", "kms:TagResource", "kms:UntagResource"]
        Resource = local.kms_key_arns
      },
      {
        Sid      = "Trail"
        Effect   = "Allow"
        Action   = ["cloudtrail:CreateTrail", "cloudtrail:UpdateTrail", "cloudtrail:DeleteTrail", "cloudtrail:DescribeTrails", "cloudtrail:GetTrailStatus", "cloudtrail:StartLogging", "cloudtrail:StopLogging", "cloudtrail:PutEventSelectors", "cloudtrail:GetEventSelectors", "cloudtrail:AddTags", "cloudtrail:RemoveTags"]
        Resource = local.trail_arns
      },
      {
        Sid      = "Config"
        Effect   = "Allow"
        Action   = ["config:Put*", "config:Delete*", "config:Describe*", "config:Get*", "config:StartConfigurationRecorder", "config:StopConfigurationRecorder", "config:TagResource", "config:UntagResource"]
        Resource = local.config_arns
      },
      {
        Sid      = "Budgets"
        Effect   = "Allow"
        Action   = ["budgets:CreateBudget", "budgets:ModifyBudget", "budgets:DeleteBudget", "budgets:ViewBudget", "budgets:DescribeBudget*"]
        Resource = local.budget_arns
      },
      {
        Sid      = "AlertTopic"
        Effect   = "Allow"
        Action   = ["sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:Subscribe", "sns:Unsubscribe", "sns:ListSubscriptionsByTopic", "sns:TagResource", "sns:UntagResource"]
        Resource = local.sns_topic_arns
      },
      {
        Sid      = "AuditLogGroups"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:TagResource", "logs:UntagResource"]
        Resource = local.log_group_arns
      },
      {
        Sid      = "BaselineRoles"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:UpdateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions"]
        Resource = concat(local.iam_role_arns, local.iam_policy_arns)
      },
      {
        Sid      = "GitHubOidcProvider"
        Effect   = "Allow"
        Action   = ["iam:CreateOpenIDConnectProvider", "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint", "iam:DeleteOpenIDConnectProvider", "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider"]
        Resource = local.oidc_provider_arn_scope
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

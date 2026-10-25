output "audit_bucket_name" {
  description = "S3 bucket that receives CloudTrail logs."
  value       = aws_s3_bucket.logs.id
}

output "config_bucket_name" {
  description = "S3 bucket that receives AWS Config snapshots."
  value       = aws_s3_bucket.config.id
}

output "kms_key_arn" {
  description = "Customer-managed key used for audit data."
  value       = aws_kms_key.logs.arn
}

output "trail_arn" {
  description = "Multi-Region CloudTrail trail ARN."
  value       = aws_cloudtrail.main.arn
}

output "trail_log_group_name" {
  description = "CloudWatch log group that receives trail events."
  value       = aws_cloudwatch_log_group.trail.name
}

output "config_recorder_name" {
  description = "AWS Config recorder name."
  value       = aws_config_configuration_recorder.main.name
}

output "budget_topic_arn" {
  description = "SNS topic that receives budget alerts."
  value       = aws_sns_topic.budget.arn
}

output "deploy_role_arn" {
  description = "IAM role that GitHub Actions assumes through OIDC."
  value       = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN, created or supplied."
  value       = local.oidc_provider_arn
}

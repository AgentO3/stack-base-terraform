output "audit_bucket_name" {
  value = module.baseline.audit_bucket_name
}

output "config_bucket_name" {
  value = module.baseline.config_bucket_name
}

output "kms_key_arn" {
  value = module.baseline.kms_key_arn
}

output "trail_arn" {
  value = module.baseline.trail_arn
}

output "budget_topic_arn" {
  value = module.baseline.budget_topic_arn
}

output "deploy_role_arn" {
  value = module.baseline.deploy_role_arn
}

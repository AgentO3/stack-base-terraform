provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Environment = "prod"
      ManagedBy   = "terraform"
      Stack       = "base-terraform"
    })
  }
}

module "baseline" {
  source = "../../modules/baseline"

  name_prefix               = "base-prod"
  environment               = "prod"
  region                    = var.region
  approved_regions          = ["us-east-1", "us-west-2"]
  tags                      = var.tags
  log_retention_days        = var.log_retention_days
  monthly_budget_usd        = var.monthly_budget_usd
  budget_notification_email = var.budget_notification_email
  github_repository         = var.github_repository
  github_branch             = var.github_branch
  github_oidc_provider_arn  = var.github_oidc_provider_arn
  state_bucket_name         = var.state_bucket_name
}

variable "region" {
  description = "Primary Region for this environment. Must be on the approved allowlist."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.region)
    error_message = "region must be one of the approved Regions: us-east-1, us-west-2."
  }
}

variable "tags" {
  description = "Baseline tags applied through the provider's default_tags."
  type        = map(string)
  default = {
    Owner       = "platform"
    CostCenter  = "engineering"
    Application = "base-terraform"
  }
}

variable "log_retention_days" {
  description = "Retention for audit logs in this environment."
  type        = number
  default     = 1095
}

variable "monthly_budget_usd" {
  description = "Monthly budget for this account."
  type        = number
  default     = 1000
}

variable "budget_notification_email" {
  description = "Address that receives budget alerts."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repository allowed to deploy this environment, as owner/name."
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to deploy this environment."
  type        = string
  default     = "main"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, if the account already has one."
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "S3 bucket that holds this environment's Terraform state."
  type        = string
}

variable "state_lock_table" {
  description = "DynamoDB table used for state locking."
  type        = string
}

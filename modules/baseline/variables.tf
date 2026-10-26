variable "name_prefix" {
  description = "Prefix for every named resource the baseline creates."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name_prefix))
    error_message = "name_prefix must be 2-31 lowercase letters, digits or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment this baseline belongs to."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "Primary AWS Region. Must be on the organisation's approved allowlist."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.region))
    error_message = "region must be an AWS Region identifier such as us-east-1."
  }
}

variable "approved_regions" {
  description = "Regions the organisation allows. Used to validate region and to scope the baseline."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]

  validation {
    condition     = length(var.approved_regions) > 0
    error_message = "approved_regions must contain at least one Region."
  }
}

variable "tags" {
  description = "Baseline tag set applied to every taggable resource."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Owner", "CostCenter", "Application"] : contains(keys(var.tags), key)
    ])
    error_message = "tags must include Owner, CostCenter and Application."
  }
}

variable "log_retention_days" {
  description = "Retention for CloudTrail and Config log groups and the log bucket."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90 && var.log_retention_days <= 3653
    error_message = "log_retention_days must be between 90 and 3653."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket that holds Terraform remote state. Empty disables the deploy role's state permissions."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly account budget in USD. A notification fires at the configured thresholds."
  type        = number
  default     = 500

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than zero."
  }
}

variable "budget_notification_email" {
  description = "Email address that receives budget alerts. Empty creates the topic without a subscription."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repository allowed to assume the deploy role, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/name."
  }
}

variable "github_branch" {
  description = "Branch whose OIDC subject may assume the deploy role."
  type        = string
  default     = "main"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN. Null creates one in this account."
  type        = string
  default     = null
}

variable "region" {
  description = "Region the project runs in. Must match the environment's approved Region."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.region)
    error_message = "region must be one of the approved Regions: us-east-1, us-west-2."
  }
}

variable "environment" {
  description = "Environment this project deploys into."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Baseline tags applied through the provider's default_tags."
  type        = map(string)
  default = {
    Owner       = "platform"
    CostCenter  = "engineering"
    Application = "aws-bedrock"
  }

  validation {
    condition = alltrue([
      for key in ["Owner", "CostCenter", "Application"] : contains(keys(var.tags), key)
    ])
    error_message = "tags must include Owner, CostCenter and Application."
  }
}

variable "model_ids" {
  description = "Foundation model IDs the application role may invoke."
  type        = list(string)
  default     = ["amazon.nova-lite-v1:0"]

  validation {
    condition     = length(var.model_ids) > 0
    error_message = "model_ids must contain at least one model."
  }
}

variable "alarm_model_ids" {
  description = "Models that get per-model CloudWatch alarms. Keep this short; each model creates five alarms."
  type        = list(string)
  default     = ["amazon.nova-lite-v1:0"]
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic for alarm actions, usually the baseline budget topic. Empty creates alarms without actions."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retention for the prompt and response log group."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90 && var.log_retention_days <= 3653
    error_message = "log_retention_days must be between 90 and 3653."
  }
}

variable "create_deploy_role" {
  description = "Create a project-scoped OIDC deploy role for CI."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "Repository allowed to deploy this project, as owner/name."
  type        = string
  default     = "AgentO3/stack-base-terraform"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be owner/name."
  }
}

variable "github_branch" {
  description = "Branch allowed to deploy this project."
  type        = string
  default     = "main"
}

variable "state_bucket_name" {
  description = "S3 bucket that holds this project's Terraform state."
  type        = string
}

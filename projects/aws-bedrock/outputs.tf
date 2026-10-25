output "guardrail_id" {
  description = "Guardrail ID callers pass to InvokeModel and ApplyGuardrail."
  value       = aws_bedrock_guardrail.main.guardrail_id
}

output "guardrail_arn" {
  description = "Guardrail ARN."
  value       = aws_bedrock_guardrail.main.guardrail_arn
}

output "guardrail_version" {
  description = "Published guardrail version. Callers must pin this, never DRAFT."
  value       = aws_bedrock_guardrail_version.main.version
}

output "invoke_role_arn" {
  description = "Role that application workloads assume to invoke the approved models."
  value       = aws_iam_role.invoke.arn
}

output "prompt_log_group_name" {
  description = "CloudWatch log group that receives prompt and response logs."
  value       = aws_cloudwatch_log_group.prompts.name
}

output "deploy_role_arn" {
  description = "Project-scoped CI role, or null when create_deploy_role is false."
  value       = var.create_deploy_role ? aws_iam_role.deploy[0].arn : null
}

output "alarm_names" {
  description = "CloudWatch alarms created for the monitored models."
  value       = [for alarm in aws_cloudwatch_metric_alarm.model : alarm.alarm_name]
}

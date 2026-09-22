output "arns" {
  description = "ARN of each secret container, keyed by its name"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

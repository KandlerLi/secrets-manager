# home-infra/blocky -- migrated out of bootstrap/terraform-state
# 2026-09-12. See ./README.md for the key this holds, who consumes it,
# and how to rotate it.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.

# AWS-0098 (should use a customer managed key) suppressed, not fixed --
# see this repo's own README.md, "Trivy AWS-0098 (customer-managed key)
# suppressed, not fixed" for why.
#trivy:ignore:AVD-AWS-0098
resource "aws_secretsmanager_secret" "this" {
  name                    = "home-infra/blocky"
  description             = "Blocky's own Postgres query-log password (also read by Grafana's datasource config)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/blocky secret container"
  value       = aws_secretsmanager_secret.this.arn
}

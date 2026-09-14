# k3s-apps/sankey-export -- migrated out of bootstrap/terraform-state
# 2026-09-10 (the pilot). See ./README.md for the keys this holds, who
# consumes them, and how to rotate each.
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
  name                    = "k3s-apps/sankey-export"
  description             = "sankey_export CronJob's own Nextcloud app password"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the k3s-apps/sankey-export secret container"
  value       = aws_secretsmanager_secret.this.arn
}

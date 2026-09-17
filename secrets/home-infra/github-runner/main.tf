# home-infra/github-runner -- migrated out of bootstrap/terraform-state
# 2026-09-12. See ./README.md for the keys this holds, who consumes
# them, and how to rotate each.
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
  name                    = "home-infra/github-runner"
  description             = "GitHub App credentials for every repo's self-hosted GitHub Actions runner (bootstrap/k3s-bootstrap's own modules/github_runner)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/github-runner secret container"
  value       = aws_secretsmanager_secret.this.arn
}

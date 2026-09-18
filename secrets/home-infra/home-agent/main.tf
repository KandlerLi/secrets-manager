# home-infra/home-agent -- migrated out of bootstrap/terraform-state
# 2026-09-11. See ./README.md for the keys this holds, who consumes
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
  name                    = "home-infra/home-agent"
  description             = "home_agent's Anthropic API key (chat), OpenAI API key (Whisper STT only, since 2026-09-18), and its nextcloud_tools sidecar's app password (GHCR credentials split out to k3s-apps/ghcr-pull-token 2026-09-12)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/home-agent secret container"
  value       = aws_secretsmanager_secret.this.arn
}

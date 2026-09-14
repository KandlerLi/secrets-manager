# k3s-apps/ghcr-pull-token -- a genuinely new secret, not a migration.
# Split out of home-infra/home-agent 2026-09-12: that group's own
# home_agent_ghcr_token was never really "home-agent's own" credential
# -- it's a single, account-scoped GitHub PAT (read:packages on
# KandlerLi) that happens to authorize pulling two unrelated private
# packages (ghcr.io/kandlerli/home-agent AND
# ghcr.io/kandlerli/sankey-export), filed under a name that only
# signaled one of its two real consumers. See ./README.md.
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
  name                    = "k3s-apps/ghcr-pull-token"
  description             = "Account-scoped GHCR pull token, shared by modules/home_agent and modules/sankey_export"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the k3s-apps/ghcr-pull-token secret container"
  value       = aws_secretsmanager_secret.this.arn
}

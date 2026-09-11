# home-infra/home-agent -- migrated out of bootstrap/terraform-state
# 2026-09-11. See ./README.md for the keys this holds, who consumes
# them, and how to rotate each.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.

resource "aws_secretsmanager_secret" "this" {
  name                    = "home-infra/home-agent"
  description             = "home_agent's OpenAI/GHCR credentials and its nextcloud_tools sidecar's app password"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/home-agent secret container"
  value       = aws_secretsmanager_secret.this.arn
}

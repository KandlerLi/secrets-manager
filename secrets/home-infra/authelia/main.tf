# home-infra/authelia -- migrating out of bootstrap/terraform-state,
# the last group in the campaign (highest blast radius, deliberately
# left for last). See ./README.md for the keys this holds, who
# consumes them, and how to rotate each one.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.

resource "aws_secretsmanager_secret" "this" {
  name                    = "home-infra/authelia"
  description             = "Authelia's own session/storage/OIDC secrets (infra/k3s-apps' modules/authelia)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/authelia secret container"
  value       = aws_secretsmanager_secret.this.arn
}

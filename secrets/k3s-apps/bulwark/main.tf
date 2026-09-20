# k3s-apps/bulwark -- a genuinely new secret, not a migration. Holds
# Bulwark webmail's own Authelia OIDC client secret (plaintext half);
# Authelia holds the matching hash in home-infra/authelia's
# authelia_oidc_bulwark_client_secret_hash. See ./README.md for details.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.

#trivy:ignore:AVD-AWS-0098
resource "aws_secretsmanager_secret" "this" {
  name                    = "k3s-apps/bulwark"
  description             = "Bulwark webmail's own Authelia OIDC client secret (plaintext half of the pair)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the k3s-apps/bulwark secret container"
  value       = aws_secretsmanager_secret.this.arn
}

# k3s-apps/stalwart -- a genuinely new secret, not a migration. Holds the
# Stalwart management-API token (an API key on Stalwart's `admin`
# account, minted for Terraform specifically) that infra/k3s-apps'
# Stalwart provider authenticates with. See ./README.md.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.

#trivy:ignore:AVD-AWS-0098
resource "aws_secretsmanager_secret" "this" {
  name                    = "k3s-apps/stalwart"
  description             = "Stalwart management-API token (admin API key) used by infra/k3s-apps' Terraform provider"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the k3s-apps/stalwart secret container"
  value       = aws_secretsmanager_secret.this.arn
}

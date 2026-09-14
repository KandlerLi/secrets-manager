# dyndns/fritzbox -- migrated out of aws/dyndns itself 2026-09-12 (a
# real CI/PR-gated repo, not bootstrap/terraform-state -- the only
# secret in this repo whose source root isn't a bootstrap-category
# root). See ./README.md for the key this holds, who consumes it, and
# how to rotate it.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy added here -- the source
# resource in aws/dyndns never had it, an inconsistency with every
# other foundational secret in this workspace, corrected on the move
# rather than carried over.

# AWS-0098 (should use a customer managed key) suppressed, not fixed --
# see this repo's own README.md, "Trivy AWS-0098 (customer-managed key)
# suppressed, not fixed" for why.
#trivy:ignore:AVD-AWS-0098
resource "aws_secretsmanager_secret" "this" {
  name                    = "dyndns/fritzbox"
  description             = "HTTP Basic credentials used by the FRITZ!Box DynDNS client"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the dyndns/fritzbox secret container"
  value       = aws_secretsmanager_secret.this.arn
}

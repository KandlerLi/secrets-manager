# home-infra/ingress -- migrated out of bootstrap/terraform-state
# 2026-09-11. See ./README.md for the keys this holds, who consumes
# them, and how to rotate each.
#
# Container only: name, description, recovery window. Never a value --
# real secret material is set out-of-band via `aws secretsmanager
# put-secret-value`, never an aws_secretsmanager_secret_version
# resource. lifecycle.prevent_destroy, matching every foundational
# resource in this workspace.
#
# Description trimmed 2026-09-11 to match: shared_ingress_auth_password/
# _hash were removed from this group's JSON in the same pass (the
# shared-auth Traefik Basic Auth rollback they fed was retired --
# unreferenced by any chain since 2026-09-08, and now several more days
# stable on authelia-forward-auth with no recurrence of the Authelia
# SQLite storage issue it existed to hedge against). Only the ACME
# DNS-01 keypair remains.

resource "aws_secretsmanager_secret" "this" {
  name                    = "home-infra/ingress"
  description             = "The ACME DNS-01 Route53 IAM keypair (dyndns's own traefik-acme-dns01 user)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/ingress secret container"
  value       = aws_secretsmanager_secret.this.arn
}

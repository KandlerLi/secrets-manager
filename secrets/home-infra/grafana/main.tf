# home-infra/grafana -- migrated out of bootstrap/terraform-state
# 2026-09-10. See ./README.md for the keys this holds, who consumes
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
  name = "home-infra/grafana"
  # monitoring_grafana_admin_password was dropped from this group's JSON
  # 2026-09-10 -- Grafana's native login and Basic Auth are both disabled
  # at the protocol level (infra/k3s-apps modules/grafana), so it could
  # not be used to log in; the k3s copy now generates its own throwaway
  # GF_SECURITY_ADMIN_PASSWORD via random_password. Only the OIDC client
  # secret remains real.
  description             = "Grafana's own Authelia OIDC client secret (plaintext half of the pair)"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

output "arn" {
  description = "ARN of the home-infra/grafana secret container"
  value       = aws_secretsmanager_secret.this.arn
}

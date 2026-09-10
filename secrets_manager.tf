# The AWS Secrets Manager secret *containers* for this workspace, migrated
# one at a time out of bootstrap/terraform-state/secrets_manager.tf (the
# SOPS-to-AWS-Secrets-Manager cutover left them there; this root exists so
# the secrets concern is separable from the state-bucket bootstrap concern
# and can grow its own per-secret docs and rotation tooling).
#
# Same discipline as the original: container only -- name, description,
# recovery window -- never a value. Real secret material is set out-of-band
# via `aws secretsmanager put-secret-value`, never an
# aws_secretsmanager_secret_version resource. lifecycle.prevent_destroy on
# every one. Each `resource` block's name/description/recovery_window is
# copied verbatim from bootstrap/terraform-state so the migration import is
# a zero-diff no-op.
#
# Migration mechanism: the ADR 0006 / ADR 0010 "no-destroy handoff" --
# transient `import` block here, `removed { ... destroy = false }` block
# left behind in bootstrap/terraform-state. See README.md.
#
# Per-secret documentation (what each group's keys are, who consumes them,
# how to rotate each one) lives in secrets/ ; the cross-cutting rotation
# categories and automated-rotation feasibility live in
# docs/home-infra-docs/docs/runbooks/rotate-secrets.md.

locals {
  secrets_manager_recovery_window_days = 7
}

# --- k3s-apps/sankey-export -----------------------------------------------
# Migrated from bootstrap/terraform-state 2026-09-10 (pilot). Key:
# sankey_export_app_password. Consumer: infra/k3s-apps' modules/sankey_export.
# The transient `import` block used for the handoff was stripped after the
# first apply (ADR 0006 / ADR 0010 precedent); bootstrap/terraform-state
# keeps the matching `removed { ... destroy = false }` block.
resource "aws_secretsmanager_secret" "k3s_apps_sankey_export" {
  name                    = "k3s-apps/sankey-export"
  description             = "sankey_export CronJob's own Nextcloud app password"
  recovery_window_in_days = local.secrets_manager_recovery_window_days

  lifecycle {
    prevent_destroy = true
  }
}

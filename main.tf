terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# One aws_secretsmanager_secret per group, in one for_each -- collapsed
# 2026-09-22 (ponytail-audit) from 14 near-identical one-resource module
# directories (each just this same resource + an `arn` output, differing
# only in name/description). Every group's own README.md stays exactly
# where it was, under secrets/<owning-repo>/<service>/ -- only the
# mechanical Terraform wrapper around it is gone. The `moved` blocks
# below remap existing state with no destroy/create API call; see
# README.md's own "Collapsing the per-secret modules" note for the
# procedure this followed.
#
# julian's IAM grant on these does NOT live here -- it stays in
# bootstrap/terraform-state/operator.tf (as a wildcard ARN string per
# secret), next to the rest of julian's operator policy.
locals {
  secrets = {
    "dyndns/fritzbox" = "HTTP Basic credentials used by the FRITZ!Box DynDNS client"

    "home-infra/authelia"      = "Authelia's own session/storage/OIDC secrets (infra/k3s-apps' modules/authelia)"
    "home-infra/blocky"        = "Blocky's own Postgres query-log password (also read by Grafana's datasource config)"
    "home-infra/github-runner" = "GitHub App credentials for every repo's self-hosted GitHub Actions runner (bootstrap/k3s-bootstrap's own modules/github_runner)"
    # monitoring_grafana_admin_password was dropped from this group's JSON
    # 2026-09-10 -- Grafana's native login and Basic Auth are both disabled
    # at the protocol level (infra/k3s-apps modules/grafana), so it could
    # not be used to log in; the k3s copy now generates its own throwaway
    # GF_SECURITY_ADMIN_PASSWORD via random_password. Only the OIDC client
    # secret remains real.
    "home-infra/grafana"    = "Grafana's own Authelia OIDC client secret (plaintext half of the pair)"
    "home-infra/home-agent" = "home_agent's Anthropic API key (chat), OpenAI API key (Whisper STT only, since 2026-09-18), and its nextcloud_tools sidecar's app password (GHCR credentials split out to k3s-apps/ghcr-pull-token 2026-09-12)"
    "home-infra/ingress"    = "The ACME DNS-01 Route53 IAM keypair (dyndns's own traefik-acme-dns01 user)"
    "home-infra/monitoring" = "Alertmanager/Authelia's shared SES SMTP identity and the ntfy relay topic"
    "home-infra/nextcloud"  = "Nextcloud's own Authelia OIDC client secret (consumed by infra/home-infra's Ansible only -- Nextcloud AIO stays on the homeserver, not k3s)"
    "home-infra/open-webui" = "Open WebUI's own Authelia OIDC client secret"

    "k3s-apps/bulwark"         = "Bulwark webmail's own Authelia OIDC client secret (plaintext half of the pair)"
    "k3s-apps/ghcr-pull-token" = "Account-scoped GHCR pull token, shared by modules/home_agent and modules/sankey_export"
    "k3s-apps/sankey-export"   = "sankey_export CronJob's own Nextcloud app password"
    "k3s-apps/stalwart"        = "Stalwart management-API token (admin API key) used by infra/k3s-apps' Terraform provider"
  }
}

# AWS-0098 (should use a customer managed key) suppressed, not fixed --
# see README.md, "Trivy AWS-0098 (customer-managed key) suppressed, not
# fixed" for why. Container only for every instance: name, description,
# recovery window. Never a value -- real secret material is set
# out-of-band via `aws secretsmanager put-secret-value`, never an
# aws_secretsmanager_secret_version resource.
#trivy:ignore:AVD-AWS-0098
resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name                    = each.key
  description             = each.value
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

# Refactored 2026-09-10 from a bare `resource` in the old
# secrets_manager.tf into a per-secret module -- a within-state address
# change, no API call, prevent_destroy untouched. Safe to remove once no
# state predates it.
moved {
  from = aws_secretsmanager_secret.k3s_apps_sankey_export
  to   = module.k3s_apps_sankey_export.aws_secretsmanager_secret.this
}

# Collapsed 2026-09-22 (ponytail-audit) from 14 per-secret modules into
# the single for_each resource above -- again a within-state address
# change only, no API call, prevent_destroy untouched throughout. Safe
# to remove once no state predates it.
moved {
  from = module.k3s_apps_sankey_export.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["k3s-apps/sankey-export"]
}
moved {
  from = module.k3s_apps_bulwark.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["k3s-apps/bulwark"]
}
moved {
  from = module.k3s_apps_stalwart.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["k3s-apps/stalwart"]
}
moved {
  from = module.home_infra_grafana.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/grafana"]
}
moved {
  from = module.home_infra_open_webui.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/open-webui"]
}
moved {
  from = module.home_infra_home_agent.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/home-agent"]
}
moved {
  from = module.home_infra_ingress.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/ingress"]
}
moved {
  from = module.home_infra_monitoring.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/monitoring"]
}
moved {
  from = module.home_infra_nextcloud.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/nextcloud"]
}
moved {
  from = module.home_infra_github_runner.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/github-runner"]
}
moved {
  from = module.dyndns_fritzbox.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["dyndns/fritzbox"]
}
moved {
  from = module.home_infra_blocky.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/blocky"]
}
moved {
  from = module.k3s_apps_ghcr_pull_token.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["k3s-apps/ghcr-pull-token"]
}
moved {
  from = module.home_infra_authelia.aws_secretsmanager_secret.this
  to   = aws_secretsmanager_secret.this["home-infra/authelia"]
}

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

# julian's read/write grant on these lives in terraform-state's operator.tf, not here.
locals {
  secrets = {
    "dyndns/fritzbox" = "HTTP Basic credentials used by the FRITZ!Box DynDNS client"

    "fritzbox/terraform" = "The dedicated FRITZ!Box user KandlerLi/fritzbox's Terraform authenticates to TR-064 as"

    "home-infra/authelia"      = "Authelia's own session/storage/OIDC secrets (KandlerLi/k3s-apps' modules/authelia)"
    "home-infra/blocky"        = "Blocky's own Postgres query-log password (also read by Grafana's datasource config)"
    "home-infra/github-runner" = "GitHub App credentials for every repo's self-hosted GitHub Actions runner (KandlerLi/k3s-bootstrap's own modules/github_runner)"
    "home-infra/grafana"       = "Grafana's own Authelia OIDC client secret (plaintext half of the pair)"
    "home-infra/home-agent"    = "home_agent's Anthropic API key (chat), OpenAI API key (Whisper STT only, since 2026-09-18), and its nextcloud_tools sidecar's app password (GHCR credentials split out to k3s-apps/ghcr-pull-token 2026-09-12)"
    "home-infra/ingress"       = "The ACME DNS-01 Route53 IAM keypair (dyndns's own traefik-acme-dns01 user)"
    "home-infra/monitoring"    = "Alertmanager/Authelia's shared SES SMTP identity and the ntfy relay topic"
    "home-infra/nextcloud"     = "Nextcloud's own Authelia OIDC client secret (consumed by KandlerLi/home-infra's Ansible only -- Nextcloud AIO stays on the homeserver, not k3s)"
    "home-infra/open-webui"    = "Open WebUI's own Authelia OIDC client secret"
    "home-infra/prometheus"    = "Tokens the homeserver's Prometheus and GitHub runner exporter read with (consumed by KandlerLi/home-infra's Ansible only)"

    "k3s-apps/bulwark"         = "Bulwark webmail's own Authelia OIDC client secret (plaintext half of the pair)"
    "k3s-apps/ghcr-pull-token" = "Account-scoped GHCR pull token, shared by modules/home_agent and modules/sankey_export"
    "k3s-apps/paperless"       = "Paperless-ngx's own Authelia OIDC client secret (plaintext half of the pair)"
    "k3s-apps/sankey-export"   = "sankey_export CronJob's own Nextcloud app password"
    "k3s-apps/stalwart"        = "Stalwart management-API token (admin API key) used by KandlerLi/k3s-apps' Terraform provider"
  }
}

# Containers only, values are set out-of-band. AWS-0098 suppressed: see README.
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

# State-address remaps from past refactors: see README, "Collapsing the per-secret modules".
moved {
  from = aws_secretsmanager_secret.k3s_apps_sankey_export
  to   = module.k3s_apps_sankey_export.aws_secretsmanager_secret.this
}

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

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

# One self-contained module directory per secret container, under
# secrets/<owning-repo>/<service>/ -- each holds its own
# aws_secretsmanager_secret resource (container only, never a value;
# lifecycle.prevent_destroy) and its own README.md (keys, consumers,
# rotation). Migrated one at a time out of
# bootstrap/terraform-state/secrets_manager.tf via the ADR 0006 / ADR
# 0010 no-destroy handoff -- see README.md for the procedure and the
# live status table.
#
# julian's IAM grant on these does NOT live here -- it stays in
# bootstrap/terraform-state/operator.tf (as a wildcard ARN string per
# migrated secret), next to the rest of julian's operator policy.

module "k3s_apps_sankey_export" {
  source = "./secrets/k3s-apps/sankey-export"
}

module "home_infra_grafana" {
  source = "./secrets/home-infra/grafana"
}

module "home_infra_open_webui" {
  source = "./secrets/home-infra/open-webui"
}

module "home_infra_home_agent" {
  source = "./secrets/home-infra/home-agent"
}

module "home_infra_ingress" {
  source = "./secrets/home-infra/ingress"
}

module "home_infra_monitoring" {
  source = "./secrets/home-infra/monitoring"
}

module "home_infra_nextcloud" {
  source = "./secrets/home-infra/nextcloud"
}

# Refactored 2026-09-10 from a bare `resource` in the old
# secrets_manager.tf into the per-secret module above -- a
# within-state address change, no API call, prevent_destroy untouched.
# Safe to remove once no state predates it.
moved {
  from = aws_secretsmanager_secret.k3s_apps_sankey_export
  to   = module.k3s_apps_sankey_export.aws_secretsmanager_secret.this
}


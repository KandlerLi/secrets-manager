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

# Refactored 2026-09-10 from a bare `resource` in the old
# secrets_manager.tf into the per-secret module above -- a
# within-state address change, no API call, prevent_destroy untouched.
# Safe to remove once no state predates it.
moved {
  from = aws_secretsmanager_secret.k3s_apps_sankey_export
  to   = module.k3s_apps_sankey_export.aws_secretsmanager_secret.this
}

# TRANSIENT -- strip after the first apply imports the secret, then
# re-plan and confirm "No changes" (ADR 0006 / ADR 0010 precedent).
# Import ID is the full ARN (AWS provider v6 rejects a bare name); get
# the current one with:
#   aws secretsmanager describe-secret --secret-id home-infra/grafana \
#     --query ARN --output text --region eu-central-1
import {
  to = module.home_infra_grafana.aws_secretsmanager_secret.this
  id = "arn:aws:secretsmanager:eu-central-1:853955636908:secret:home-infra/grafana-RSvc5G"
}

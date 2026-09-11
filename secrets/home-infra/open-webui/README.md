# Secret: `home-infra/open-webui`

**Terraform resource**:
`module.home_infra_open_webui.aws_secretsmanager_secret.this`, defined
in `./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/open_webui`, read via
`secrets.tf`.

## Keys

### `authelia_oidc_openwebui_client_secret`
Plaintext half of Open WebUI's OIDC client secret pair — Authelia
holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_openwebui_client_secret_hash`; see that file's own
"Rotating this pair" note for the full two-secret procedure). Never
rotate this alone — Open WebUI's SSO breaks until both sides match
again, and native login stays disabled regardless (same protocol-level
lock as Grafana's, see `home-infra/grafana/README.md`), so a mismatch
here is a real, if temporary, outage for the whole service.

## Automated rotation

Structurally resistant, same as every OIDC pair — needs a coordinated
update with `home-infra/authelia` plus a Terraform apply that rolls
both Deployments together, not something a scheduled job should do
unattended.

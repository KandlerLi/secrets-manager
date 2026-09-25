# Secret documentation

One file per `aws_secretsmanager_secret` container, path mirroring the
secret's own name (`home-infra/authelia` -> `home-infra/authelia.md`),
covering what its keys are, who consumes them, and exactly how to
rotate each one. See
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md` for the
cross-cutting rotation categories and automated-rotation feasibility
these draw from. The actual Terraform (a single `for_each
aws_secretsmanager_secret.this` resource, one entry per secret in
`local.secrets`) lives in the root `main.tf` -- see this repo's own
`README.md`'s "Layout" for why these docs aren't split into per-secret
module directories the way they once were.

Most of these were migrated in one group at a time out of
`bootstrap/terraform-state/secrets_manager.tf` (see this repo's own
`README.md` for the historical migration-status table and
`removed`/`import` handoff procedure); a few are genuinely new secrets,
not migrations.

- [k3s-apps/sankey-export](k3s-apps/sankey-export.md) — the
  sankey-export CronJob's Nextcloud app password
- [k3s-apps/ghcr-pull-token](k3s-apps/ghcr-pull-token.md) — the
  account-scoped GHCR pull token shared by `modules/home_agent` and
  `modules/sankey_export`, split out of `home-infra/home-agent`
  (created, not migrated)
- [k3s-apps/bulwark](k3s-apps/bulwark.md) — Bulwark webmail's own
  Authelia OIDC client secret (created, not migrated)
- [k3s-apps/paperless](k3s-apps/paperless.md) — Paperless-ngx's own
  Authelia OIDC client secret (created, not migrated)
- [k3s-apps/stalwart](k3s-apps/stalwart.md) — the Stalwart
  management-API token `infra/k3s-apps`' Terraform provider
  authenticates with (created, not migrated)
- [home-infra/grafana](home-infra/grafana.md) — Grafana's Authelia
  OIDC client secret (its dead admin password was removed in the same
  pass)
- [home-infra/open-webui](home-infra/open-webui.md) — Open WebUI's
  OIDC client secret
- [home-infra/authelia](home-infra/authelia.md) — Authelia's own
  session/storage/OIDC crypto material, plus one personal login
- [home-infra/nextcloud](home-infra/nextcloud.md) — Nextcloud's OIDC
  client secret (Ansible-consumed, not Terraform)
- [home-infra/home-agent](home-infra/home-agent.md) — home_agent's
  Anthropic API key (chat), OpenAI API key (Whisper speech-to-text
  only, since 2026-09-18), and its nextcloud_tools app password
- [home-infra/ingress](home-infra/ingress.md) — the ACME DNS-01 IAM
  keypair (the dormant shared Basic Auth rollback credential was
  retired, not migrated)
- [home-infra/monitoring](home-infra/monitoring.md) — the SES SMTP
  identity (a derived, not chosen, password) and the ntfy topic
- [home-infra/github-runner](home-infra/github-runner.md) — the
  shared GitHub Actions runner's GitHub App credentials (switched from
  a PAT 2026-09-16), read by the `k3s-bootstrap-local` scripted
  identity
- [home-infra/blocky](home-infra/blocky.md) — Blocky's own Postgres
  password
- [dyndns/fritzbox](dyndns/fritzbox.md) — the FRITZ!Box router's own
  HTTP Basic Auth credentials, the only secret here whose source root
  is `aws/dyndns` rather than `bootstrap/terraform-state`

Every container has `lifecycle { prevent_destroy = true }` — these are
foundational, load-bearing resources for every service migrated off
SOPS, not something a stray `terraform apply` should ever remove.

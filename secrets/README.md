# Secret documentation

One directory per `aws_secretsmanager_secret` container, path mirroring
the secret's own name (`home-infra/authelia` →
`home-infra/authelia/`). Each directory holds the secret's own `main.tf`
(the `resource`, `lifecycle { prevent_destroy = true }`, an `arn`
output) and a `README.md` covering what its keys are, who consumes
them, and exactly how to rotate each one. See
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md` for the
cross-cutting rotation categories and automated-rotation feasibility
these draw from.

The containers are being migrated in here one group at a time — mostly
out of `bootstrap/terraform-state/secrets_manager.tf`, but not always:
`dyndns/fritzbox` came from `aws/dyndns` itself, a real CI/PR-gated
repo, the same no-destroy handoff just applied to a different kind of
source root; `k3s-apps/ghcr-pull-token` isn't a migration at all, a
genuinely new secret split out of `home-infra/home-agent`'s own group.
See this repo's own `README.md` for the migration-status table and the
`removed`/`import` handoff procedure. Until a group has migrated it
has only a `.md` file here (no directory); its `.md` names where its
`resource` block currently lives.

- [k3s-apps/sankey-export](k3s-apps/sankey-export/README.md) — the
  sankey-export CronJob's Nextcloud app password (**migrated**)
- [home-infra/grafana](home-infra/grafana/README.md) — Grafana's
  Authelia OIDC client secret (its dead admin password was removed in
  the same pass) (**migrated**)
- [home-infra/open-webui](home-infra/open-webui/README.md) — Open
  WebUI's OIDC client secret (**migrated**)
- [home-infra/authelia](home-infra/authelia/README.md) — Authelia's own
  session/storage/OIDC crypto material, plus one personal login
  (**migrated**)
- [home-infra/nextcloud](home-infra/nextcloud/README.md) — Nextcloud's
  OIDC client secret (Ansible-consumed, not Terraform) (**migrated**)
- [home-infra/home-agent](home-infra/home-agent/README.md) —
  home_agent's Anthropic API key (chat), OpenAI API key (Whisper
  speech-to-text only, since 2026-09-18), and its nextcloud_tools app
  password (**migrated**)
- [home-infra/ingress](home-infra/ingress/README.md) — the ACME
  DNS-01 IAM keypair (the dormant shared Basic Auth rollback
  credential was retired, not migrated) (**migrated**)
- [home-infra/monitoring](home-infra/monitoring/README.md) — the SES
  SMTP identity (a derived, not chosen, password) and the ntfy topic
  (**migrated**)
- [home-infra/github-runner](home-infra/github-runner/README.md) —
  the shared GitHub Actions runner's GitHub App credentials (switched
  from a PAT 2026-09-16), read by the `k3s-bootstrap-local` scripted
  identity (**migrated**)
- [home-infra/blocky](home-infra/blocky/README.md) — Blocky's own
  Postgres password (**migrated**)
- [dyndns/fritzbox](dyndns/fritzbox/README.md) — the FRITZ!Box
  router's own HTTP Basic Auth credentials, the only secret here whose
  source root is `aws/dyndns` rather than `bootstrap/terraform-state`
  (**migrated**)
- [k3s-apps/ghcr-pull-token](k3s-apps/ghcr-pull-token/README.md) — the
  account-scoped GHCR pull token shared by `modules/home_agent` and
  `modules/sankey_export`, split out of `home-infra/home-agent`
  (**created, not migrated**)

Every container has `lifecycle { prevent_destroy = true }` — these are
foundational, load-bearing resources for every service migrated off
SOPS, not something a stray `terraform apply` should ever remove.

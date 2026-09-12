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

The containers are being migrated out of
`bootstrap/terraform-state/secrets_manager.tf` into a directory here
one group at a time — see this repo's own `README.md` for the
migration-status table and the `removed`/`import` handoff procedure.
Until a group has migrated it has only a `.md` file here (no
directory); its `.md` names where its `resource` block currently lives.

- [k3s-apps/sankey-export](k3s-apps/sankey-export/README.md) — the
  sankey-export CronJob's Nextcloud app password (**migrated**)
- [home-infra/grafana](home-infra/grafana/README.md) — Grafana's
  Authelia OIDC client secret (its dead admin password was removed in
  the same pass) (**migrated**)
- [home-infra/open-webui](home-infra/open-webui/README.md) — Open
  WebUI's OIDC client secret (**migrated**)
- [home-infra/authelia](home-infra/authelia.md) — Authelia's own
  session/storage/OIDC crypto material, plus one personal login
- [home-infra/nextcloud](home-infra/nextcloud/README.md) — Nextcloud's
  OIDC client secret (Ansible-consumed, not Terraform) (**migrated**)
- [home-infra/home-agent](home-infra/home-agent/README.md) —
  home_agent's OpenAI/GHCR credentials and its nextcloud_tools app
  password (**migrated**)
- [home-infra/ingress](home-infra/ingress/README.md) — the ACME
  DNS-01 IAM keypair (the dormant shared Basic Auth rollback
  credential was retired, not migrated) (**migrated**)
- [home-infra/monitoring](home-infra/monitoring/README.md) — the SES
  SMTP identity (a derived, not chosen, password) and the ntfy topic
  (**migrated**)
- [home-infra/github-runner](home-infra/github-runner/README.md) —
  the shared GitHub Actions runner PAT, read by the
  `k3s-bootstrap-local` scripted identity (**migrated**)
- [home-infra/blocky](home-infra/blocky.md) — Blocky's own Postgres
  password

Every container has `lifecycle { prevent_destroy = true }` — these are
foundational, load-bearing resources for every service migrated off
SOPS, not something a stray `terraform apply` should ever remove.

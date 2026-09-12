# Secret: `home-infra/home-agent`

**Terraform resource**:
`module.home_infra_home_agent.aws_secretsmanager_secret.this`, defined in
`./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/home_agent`, read via
`secrets.tf`. `home_agent_ghcr_token` used to live here too, reused
directly by `modules/sankey_export` — split out into its own dedicated
`k3s-apps/ghcr-pull-token` secret 2026-09-12, since it was never really
"home-agent's own" credential (a single, account-scoped GHCR pull
token, not tied to this one service). See that secret's own README.

## Keys

### `home_agent_openai_api_key`
OpenAI API key for `home_agent`'s own chat/completions calls. Generate
a new key in the OpenAI dashboard, `put-secret-value`, `terraform
apply`, then revoke the old key once the new Deployment is confirmed
healthy.

### `nextcloud_tools_app_password`
Nextcloud app password for `home_agent`'s own read-only Nextcloud
integration — a dedicated bot account, **`home-agent`** in Nextcloud
itself (confirmed live 2026-09-12 by reading `modules/home_agent`'s
own `NEXTCLOUD_USERNAME` env var; this doc previously said
`nextcloud_tools`, which was never the real account name — that was
the retired Ansible role's own name, not the Nextcloud username it
managed). No dedicated rotation playbook exists any more —
`infra/home-infra`'s own `nextcloud_tools` role and its rotation
playbook were retired entirely when `home_agent`/`open_webui` moved to
k3s-native (commit `018c5ff`). Manual flow:
```bash
docker exec nextcloud-aio-nextcloud php occ user:auth-tokens:add \
  --name "<new token name>" -- home-agent
```
capture the printed token, `put-secret-value`, `terraform apply`.
Revoke the superseded token only after confirming the new one works
(`occ user:auth-tokens:list -- home-agent`, then
`occ user:auth-tokens:delete` on the old one by ID) — both tokens stay
valid until you revoke one, so there's no blackout window if you check
first.

## Automated rotation

`home_agent_openai_api_key`: worth automating — mechanically simple,
low blast radius. `nextcloud_tools_app_password`: possible but needs a
Lambda that can reach the homeserver's own `occ` CLI (via Docker exec
or an equivalent API), a real build, not a native AWS rotation
template.

# Secret: `home-infra/open-webui`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/open-webui"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/open_webui`, read via
`secrets.tf`.

## Keys

### `authelia_oidc_openwebui_client_secret`
Plaintext half of Open WebUI's OIDC client secret pair — Authelia
holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_openwebui_client_secret_hash`). Never rotate this alone
— Open WebUI's SSO breaks until both sides match again, and native
login stays disabled regardless (same protocol-level lock as
Grafana's, see `home-infra/grafana/README.md`), so a mismatch here is
a real, if temporary, outage for the whole service.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then:

```bash
infra/k3s-apps/scripts/rotate-oidc-client-secret.sh openwebui
```

It prompts silently for each value, rejects an obviously-swapped pair,
writes both secrets, and runs `terraform apply` (rolls Authelia and
Open WebUI together, in sync). Verify for real afterward -- it can't be
checked automatically, it's a browser OIDC login flow: sign out, then
"Sign in with Authelia" must reach a real login/consent screen and land
back in Open WebUI authenticated.

## Automated rotation

Structurally resistant, same as every OIDC pair — needs a coordinated
update with `home-infra/authelia` plus a Terraform apply that rolls
both Deployments together, not something a scheduled job should do
unattended. The helper script above is a manual-trigger convenience,
not automation.

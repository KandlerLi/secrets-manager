# Secret: `home-infra/grafana`

**Terraform resource**:
`module.home_infra_grafana.aws_secretsmanager_secret.this`, defined in
`./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-10 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/grafana`, read via
`secrets.tf`.

## Keys

### `authelia_oidc_grafana_client_secret`
The only key in this group. Plaintext half of Grafana's OIDC client
secret pair — Authelia holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_grafana_client_secret_hash`). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
`infra/k3s-apps/scripts/rotate-oidc-client-secret.sh grafana` — prompts
silently for each value, rejects an obviously-swapped pair, writes both
secrets, and runs `terraform apply` (rolls Authelia and Grafana
together, in sync). Verify for real afterward (browser OIDC flow, can't
be checked automatically): sign out, "Sign in with Authelia" must reach
a real login/consent screen and land back in Grafana authenticated.

## Removed: `monitoring_grafana_admin_password` (2026-09-10)

Grafana's native login form *and* HTTP Basic Auth are both disabled at
the protocol level (`GF_AUTH_DISABLE_LOGIN_FORM` +
`GF_AUTH_BASIC_ENABLED=false` in `infra/k3s-apps/modules/grafana`) —
Authelia OIDC is the only way in — so this password could not be used
to log into anything. It was removed from this group's JSON entirely;
`modules/grafana` now fills `GF_SECURITY_ADMIN_PASSWORD__FILE` from a
module-local `random_password` (random rather than a fixed placeholder
so an accidental rollback of those two `GF_AUTH_*` switches doesn't
hand out a known-value admin login). The `grafana/user` +
`grafana/password` `pass` entries and the `monitoring_grafana_admin_user`
Ansible default went away with it.

## Automated rotation

`authelia_oidc_grafana_client_secret`: structurally resistant, same as
every OIDC pair — needs a coordinated update with `home-infra/authelia`
plus a Terraform apply, not something a scheduled job should do
unattended. The helper script above is a manual-trigger convenience,
not automation.

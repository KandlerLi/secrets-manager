# Secret: `home-infra/grafana`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/grafana"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from [`terraform-state`](https://github.com/KandlerLi/terraform-state)
2026-09-10 — container only, no value.

**Consumed by**: the External Secrets Operator in `monitoring` (role
`k3s-eso-monitoring`, ADR 0032) through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/grafana/externalsecret.yaml`, hourly or at once with
`kubectl -n monitoring annotate externalsecret grafana-oidc-client-secret force-sync=$(date +%s) --overwrite`
(likewise `grafana-admin-password`); Reloader then restarts Grafana.

## Keys

### `authelia_oidc_grafana_client_secret`
Plaintext half of Grafana's OIDC client
secret pair — Authelia holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_grafana_client_secret_hash`). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
`[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) grafana` — prompts
silently for each value, rejects an obviously-swapped pair, writes both
secrets, and runs `terraform apply`, which now rolls only Authelia's
side; then force-sync `grafana-oidc-client-secret` (above). Verify for real afterward (browser OIDC flow, can't
be checked automatically): sign out, "Sign in with Authelia" must reach
a real login/consent screen and land back in Grafana authenticated.

### `grafana_admin_password`
`GF_SECURITY_ADMIN_PASSWORD__FILE`, unusable for login by design (see
below). Until 2026-11-15 a `random_password` in `modules/grafana`'s
Terraform state; copied here unchanged so the move didn't restart
Grafana. **Rotation**: any new random value, merged into the JSON, then
force-sync `grafana-admin-password`; nothing else depends on it.

## Removed: `monitoring_grafana_admin_password` (2026-09-10)

Grafana's native login form *and* HTTP Basic Auth are both disabled at
the protocol level (`GF_AUTH_DISABLE_LOGIN_FORM` +
`GF_AUTH_BASIC_ENABLED=false` in [`k3s-apps/argocd/grafana`](https://github.com/KandlerLi/k3s-apps/blob/main/argocd/grafana)) —
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

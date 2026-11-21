# Secret: `home-infra/nextcloud`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/nextcloud"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from [`terraform-state`](https://github.com/KandlerLi/terraform-state)
2026-09-11 — container only, no value.

**Consumed by**: the External Secrets Operator in `apps` (role
`k3s-eso-apps`, ADR 0032) through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/nextcloud/externalsecret.yaml`, which builds `nextcloud-env`.
Nextcloud runs in k3s since the ADR 0033 cutover; its start hook
registers the `Authelia` provider with this value
(`occ user_oidc:provider`). [`home-infra`](https://github.com/KandlerLi/home-infra)'s Ansible still fetches
it while `nextcloud_aio_oidc_enabled` is set, but skips the OIDC tasks
for the parked AIO.

## Keys

### `authelia_oidc_nextcloud_client_secret`
Plaintext half of Nextcloud's OIDC client secret pair — Authelia holds
the matching hash (`home-infra/authelia`'s
`authelia_oidc_nextcloud_client_secret_hash`; see that file's own
"Rotating this pair" note). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) `nextcloud`. It writes
both halves and force-syncs Authelia's config and `nextcloud-env`;
Reloader restarts both, and Nextcloud's start hook re-registers the
provider with the new plaintext. Verify: sign out, "Sign in with
Authelia" must land back in Nextcloud authenticated.

## Automated rotation

Structurally resistant, same as every OIDC pair: both halves must change
together and the result can only be checked with a browser login.

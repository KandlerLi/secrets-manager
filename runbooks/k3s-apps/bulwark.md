# Secret: `k3s-apps/bulwark`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/bulwark"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. A genuinely new secret, not a migration.

**Consumed by**: the External Secrets Operator in the `apps` namespace
(role `k3s-eso-apps`, ADR 0032), through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/bulwark/externalsecret.yaml`. A changed value reaches the
Kubernetes Secrets within an hour, or at once with
`kubectl -n apps annotate externalsecret bulwark-oidc force-sync=$(date +%s) --overwrite`
(likewise `bulwark-session`); Reloader then restarts Bulwark.

## Keys

### `authelia_oidc_bulwark_client_secret`
Plaintext half of Bulwark's OIDC client
secret pair -- Authelia holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_bulwark_client_secret_hash`). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
`[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) bulwark` -- prompts
silently for each value, rejects an obviously-swapped pair, writes both
secrets, and runs `terraform apply`, which now rolls only Authelia's
side; then force-sync `bulwark-oidc` (above) so Bulwark follows at once. Verify for real afterward (browser OIDC flow, can't
be checked automatically): sign out, "Sign in with Authelia" must reach
a real login/consent screen and land back in Bulwark authenticated.

### `bulwark_session_secret`
Signs Bulwark's session cookies (`SESSION_SECRET`). Until 2026-11-14 a
`random_id` in `k3s-apps`' Terraform state; copied here unchanged so no
session was lost.

**Rotation**: write a new value (`openssl rand -base64 32`) merged into the
group's JSON, then force-sync `bulwark-session` (above). Every Bulwark
session ends; nothing else depends on it.

## Bootstrapping the first value

This container starts empty. Generate the first plaintext/hash pair the
same way as a rotation (see above), then seed it directly:

```bash
aws secretsmanager put-secret-value --secret-id k3s-apps/bulwark \
  --secret-string '{"authelia_oidc_bulwark_client_secret":"<plaintext>"}'
```

`home-infra/authelia`'s own `authelia_oidc_bulwark_client_secret_hash`
key needs seeding the same way, merged into that group's existing JSON
(never overwrite the whole blob -- see `home-infra/authelia.md`).

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
structurally resistant, needs a coordinated update with
`home-infra/authelia` plus a Terraform apply. The helper script above is
a manual-trigger convenience, not automation.

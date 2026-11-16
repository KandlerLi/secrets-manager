# Secret: `home-infra/authelia`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/authelia"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from [`terraform-state`](https://github.com/KandlerLi/terraform-state)
2026-09-12 — the last group in the campaign — container only, no
value; the value is set out-of-band via `aws secretsmanager
put-secret-value` (never `aws_secretsmanager_secret_version` in
Terraform).

**Consumed by**: the External Secrets Operator in `auth` (role
`k3s-eso-auth`, ADR 0032), since 2026-11-15, through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/authelia/externalsecret.yaml`, which renders `configuration.yml`
and `users_database.yml` from this group (and the SES login from
`home-infra/monitoring`), hourly or at once with
`kubectl -n auth annotate externalsecret authelia-config force-sync=$(date +%s) --overwrite`
(likewise `authelia-users` for the two password hashes); Reloader then
restarts Authelia.

Authelia's own internal crypto material plus the hash half of each
OIDC client secret pair — mostly not things a human types or
remembers, with one exception.

## Keys

### `authelia_session_secret`
Encryption key for Authelia's session cookies (config's
`session.secret`) — pure random noise. Generate with `authelia crypto
rand --length 64 --charset alphanumeric` (the CLI ships in Authelia's
own image, `ghcr.io/authelia/authelia:4.39.22` per
[`k3s-apps/modules/authelia/main.tf`](https://github.com/KandlerLi/k3s-apps/blob/main/modules/authelia/main.tf)'s pinned digest).
**Rotation impact**: logs out every active session immediately
(everyone re-authenticates, MFA included). Otherwise safe to rotate
any time.

### `authelia_storage_encryption_key`
Encrypts Authelia's own SQLite storage at rest (session/TOTP
registration state). **Do not just swap the value** — run Authelia's
own `authelia storage encryption change-key` against the live database
first, or the database stays encrypted with the old key while Authelia
expects the new one, breaking every existing TOTP registration.

### Rotating the session secret, storage key and issuer key together
[`k3s-apps/scripts/rotate-authelia-internal-secrets.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-authelia-internal-secrets.sh)
rotates `authelia_session_secret`, `authelia_storage_encryption_key` and
`authelia_oidc_issuer_private_key` in one go: fresh backup job, new
values generated in memory, written to this secret **before**
`change-key` re-encrypts the live database, a check against the new
key, then a forced ESO sync, after which Reloader rolls the Pod. Values never appear in
argv, files or output. Blast radius: everyone logged out, every OIDC
client session ends.

Before running it: `aws login` as an identity that can write this
secret. If the script stops after `change-key` (the database and this
secret already hold the new key, the Pod still the old one), finish
with the forced sync above alone; never roll this secret back and never
re-run the script then, since it would generate a key the database
doesn't have. (On 2026-10-25 the first run died exactly there, at what
was then a `terraform apply`.)

### `authelia_reset_password_jwt_secret`
Signs the password-reset email's JWT link (config's
`identity_validation.reset_password.jwt_secret`). Generate the same
way as the session secret. **Rotation impact**: low — only invalidates
any reset link currently in flight (rare).

### `authelia_admin_password_hash`
**Personal credential** — Argon2id hash of Julian's own Authelia login
password (the file `authentication_backend`'s `users_database.yml`).
Only the hash lives here; the plaintext stays in a password manager,
never in this secret or in git. Generate with:
```bash
docker run --rm authelia/authelia:4.39.22 \
  authelia crypto hash generate argon2 --password '<password>'
```
Update the password manager entry *before* rotating this value, not
after — there's no way to recover the plaintext once only the hash
exists.

### `authelia_oidc_hmac_secret`
Signing secret for Authelia's own OIDC provider (config's
`identity_providers.oidc.hmac_secret`) — pure random noise. Generate
with `authelia crypto rand --length 64 --charset alphanumeric`.
**Rotation impact**: invalidates every live OIDC session across
Grafana and Nextcloud at once (both services' users
get logged out and must re-authenticate through Authelia).

### `authelia_oidc_issuer_private_key`
RSA private key (PEM, 4096-bit) Authelia's OIDC provider signs tokens
with (config's `identity_providers.oidc.jwks`). Generate with
`authelia crypto pair rsa generate -b 4096`. **Rotation impact**: same
as the HMAC secret above — invalidates every live OIDC session
simultaneously.

### `authelia_oidc_grafana_client_secret_hash`, `authelia_oidc_nextcloud_client_secret_hash`
pbkdf2-sha512 hash of each client's own OIDC client secret — only the
hash lives here, the matching plaintext lives in that client's own
Secrets Manager group (`home-infra/grafana`,
`home-infra/nextcloud` respectively — see each of those files' own
"Rotating this pair" note). **Rotating one half without the other
breaks that client's SSO outright.** Generate hash + plaintext
together, in one command:
```bash
docker run --rm authelia/authelia:4.39.22 \
  authelia crypto hash generate pbkdf2 --variant sha512 \
  --random --random.length 64 --random.charset alphanumeric
```
This prints both the random plaintext and its pbkdf2 hash — keep both,
they go to two different secrets.

Feed both values to `[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh)
grafana` (or `nextcloud`) — it writes both secrets and
rejects an obviously-swapped pair (a pbkdf2 hash always starts with
`$`, the random plaintext never does).

**Grafana** (and Bulwark, Paperless, Vaultwarden): the script
then forces ESO to sync Authelia's config and the client's Secret, so
Reloader restarts both together, and stops there.

**Nextcloud** (script support added 2026-09-11 — it used to be
manual): the script forces the same sync for Authelia's own side, then also re-runs [`home-infra`](https://github.com/KandlerLi/home-infra)'s `site.yml`
(`--ask-become-pass`, so you run this one yourself) so the new
plaintext reaches Nextcloud's own `occ user_oidc:provider` config —
confirmed live that step is a real upsert, not a formality (unlike
`home-infra/monitoring`'s SES creds, which turned out to be
assert-only in Ansible). Nextcloud AIO runs on the homeserver, not
k3s, so there's no Terraform-side Deployment to roll for it the way
Grafana gets.

## Automated rotation

Not a good candidate. Every key here is either Authelia's own internal
crypto material (unattended rotation is actively harmful given the
logout/re-auth blast radius on session or OIDC-signing material, not
merely unnecessary) or the coordinated OIDC pairs (need a redeploy of
the *other* secret's consumer too, in lockstep). See
[`home-infra-docs/docs/runbooks/rotate-secrets.md`](https://github.com/KandlerLi/home-infra-docs/blob/main/docs/runbooks/rotate-secrets.md)'s own "reality
check" section for the fuller reasoning.

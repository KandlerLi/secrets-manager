# Secret: `k3s-apps/paperless`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/paperless"]`, defined in the
root `main.tf` (`aws/secrets-manager`). A genuinely new secret, not a
migration (ADR 0023).

**Consumed by**: `infra/k3s-apps`' `modules/paperless`, read via
`secrets.tf`.

Paperless's `PAPERLESS_SECRET_KEY` and its PostgreSQL password are
deliberately **not** here: nobody ever types either, so they are
`random_password` resources inside `modules/paperless` instead.

## Keys

### `authelia_oidc_paperless_client_secret`
The only key in this group. Plaintext half of Paperless-ngx's OIDC
client secret pair -- Authelia holds the matching hash
(`home-infra/authelia`'s `authelia_oidc_paperless_client_secret_hash`).
Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md` for the exact command), then
`infra/k3s-apps/scripts/rotate-oidc-client-secret.sh paperless`, which
writes both secrets and runs `terraform apply`. Verify for real
afterward: sign out, "Sign in with Authelia" must land back in Paperless
authenticated.

## Bootstrapping the first value

This container starts empty. Generate the first plaintext/hash pair the
same way as a rotation, then seed it (the value is read from a silent
prompt, never put on the command line):

```bash
read -rs PLAIN && aws secretsmanager put-secret-value \
  --secret-id k3s-apps/paperless \
  --secret-string "$(jq -n --arg v "$PLAIN" '{authelia_oidc_paperless_client_secret: $v}')"
unset PLAIN
```

`home-infra/authelia`'s `authelia_oidc_paperless_client_secret_hash`
key needs seeding the same way, merged into that group's existing JSON
(never overwrite the whole blob -- see `home-infra/authelia.md`).
Then add an `authelia-oidc:paperless` entry to `rotation-schedule.json`
with the real seeding date.

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
needs a coordinated update with `home-infra/authelia` plus a Terraform
apply. Not automated.

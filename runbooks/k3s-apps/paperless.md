# Secret: `k3s-apps/paperless`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/paperless"]`, defined in the
root `main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A genuinely new secret, not a
migration (ADR 0023).

**Consumed by**: the External Secrets Operator in `apps` (role
`k3s-eso-apps`, ADR 0032) through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/paperless/externalsecret.yaml`, which builds `paperless-env` and
`paperless-postgres`, hourly or at once with
`kubectl -n apps annotate externalsecret paperless-env paperless-postgres force-sync=$(date +%s) --overwrite`;
Reloader then restarts Paperless.

## Keys

### `authelia_oidc_paperless_client_secret`
Plaintext half of Paperless-ngx's OIDC
client secret pair -- Authelia holds the matching hash
(`home-infra/authelia`'s `authelia_oidc_paperless_client_secret_hash`).
Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md` for the exact command), then
`[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) paperless`, which
writes both secrets and runs `terraform apply`, which now rolls only
Authelia's side; then force-sync `paperless-env` (above). Verify for real
afterward: sign out, "Sign in with Authelia" must land back in Paperless
authenticated.

### `paperless_secret_key`
Django's `PAPERLESS_SECRET_KEY` (sessions, signed tokens). Until
2026-11-15 a `random_password` in `k3s-apps`' Terraform state; copied
here unchanged. **Rotation**: a new 64-character value, merged into the
JSON, then force-sync; every Paperless session ends.

### `paperless_postgres_password`
PostgreSQL password of the `paperless` role, used by both the database
sidecar (`POSTGRES_PASSWORD`, only read on first initialisation) and
Paperless (`PAPERLESS_DBPASS`). Until 2026-11-15 a `random_password` in
`k3s-apps`' Terraform state; copied here unchanged. **Rotation is not a
Secrets Manager write alone**: the live database keeps the old password
until `ALTER ROLE paperless PASSWORD '…'` runs inside the database
sidecar; change it there first, then write the same value here and
force-sync, so Paperless reconnects with it.

## Bootstrapping the first value

This container starts empty, and `home-infra/authelia` has no
`authelia_oidc_paperless_client_secret_hash` key yet, so
`rotate-oidc-client-secret.sh` (which refuses to add a missing key)
can't do the first write. Generate the pair, then seed both halves by
hand. Values are read from silent prompts and passed as `file://` from
a private temp file, never as a command-line argument:

```bash
kubectl -n auth exec deploy/authelia -c authelia -- \
  authelia crypto hash generate pbkdf2 --variant sha512 \
  --random --random.length 64 --random.charset alphanumeric

read -rsp "plaintext: " PLAIN; echo; read -rsp "hash: " HASH; echo
umask 077; T=$(mktemp)

jq -n --arg v "$PLAIN" '{authelia_oidc_paperless_client_secret: $v}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id k3s-apps/paperless --secret-string "file://$T"

aws secretsmanager get-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --query SecretString --output text \
  | jq --arg v "$HASH" '.authelia_oidc_paperless_client_secret_hash = $v' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --secret-string "file://$T"

rm -f "$T"; unset PLAIN HASH
```

The second write merges one key into Authelia's existing JSON; it never
replaces the whole blob. Then add an `authelia-oidc:paperless` entry to
`rotation-schedule.json` with the real seeding date.

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
needs a coordinated update with `home-infra/authelia` plus a Terraform
apply. Not automated.

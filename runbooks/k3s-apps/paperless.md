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

This container starts empty, and `home-infra/authelia` has no
`authelia_oidc_paperless_client_secret_hash` key yet, so
`rotate-oidc-client-secret.sh` (which refuses to add a missing key)
can't do the first write. Generate the pair, then seed both halves by
hand. Values are read from silent prompts and passed as `file://` from
a private temp file, never as a command-line argument. Works in bash
and zsh (zsh's `read -p` means something else), and writes nothing
unless the plaintext is non-empty and the hash looks like a pbkdf2
hash:

```bash
docker run --rm authelia/authelia:4.39.22 \
  authelia crypto hash generate pbkdf2 --variant sha512 \
  --random --random.length 64 --random.charset alphanumeric

printf 'plaintext: '; read -rs PLAIN; echo
printf 'hash: '; read -rs HASH; echo

if [ -n "$PLAIN" ] && [ "${PLAIN#\$}" = "$PLAIN" ] && [ "${HASH#\$pbkdf2}" != "$HASH" ]; then
  umask 077; T=$(mktemp)
  jq -n --arg v "$PLAIN" '{authelia_oidc_paperless_client_secret: $v}' > "$T" &&
  aws secretsmanager put-secret-value --region eu-central-1 \
    --secret-id k3s-apps/paperless --secret-string "file://$T" &&
  aws secretsmanager get-secret-value --region eu-central-1 \
    --secret-id home-infra/authelia --query SecretString --output text \
    | jq --arg v "$HASH" '.authelia_oidc_paperless_client_secret_hash = $v' > "$T" &&
  [ -s "$T" ] &&
  aws secretsmanager put-secret-value --region eu-central-1 \
    --secret-id home-infra/authelia --secret-string "file://$T"
  rm -f "$T"
else
  echo "empty or swapped input -- nothing written"
fi
unset PLAIN HASH
```

The second write merges one key into Authelia's existing JSON; it never
replaces the whole blob. Then add an `authelia-oidc:paperless` entry to
`rotation-schedule.json` with the real seeding date.

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
needs a coordinated update with `home-infra/authelia` plus a Terraform
apply. Not automated.

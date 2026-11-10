# Secret: `k3s-apps/vaultwarden`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/vaultwarden"]`, defined in the
root `main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A genuinely new secret, not a
migration (ADR 0028 and its SSO amendment in [`home-infra-docs`](https://github.com/KandlerLi/home-infra-docs)).

**Consumed by**: [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)' `modules/vaultwarden`, read via
`secrets.tf`.

Vaultwarden's own key files (`rsa_key*`) are deliberately **not** here:
Vaultwarden generates them on its volume, and nobody ever types them.

## Keys

### `authelia_oidc_vaultwarden_client_secret`
The only key in this group. Plaintext half of Vaultwarden's OIDC
client secret pair -- Authelia holds the matching hash
(`home-infra/authelia`'s `authelia_oidc_vaultwarden_client_secret_hash`).
Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md` for the exact command), then
`[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) vaultwarden`, which
writes both secrets and runs `terraform apply`. Verify for real
afterward: log out of the web vault, then "Use single sign-on" must
pass through Authelia and end at the master-password prompt.

## Bootstrapping the first value

This container starts empty, and `home-infra/authelia` has no
`authelia_oidc_vaultwarden_client_secret_hash` key yet, so
`rotate-oidc-client-secret.sh` (which refuses to add a missing key)
can't do the first write. Generate the pair, then seed both halves by
hand. Values are read from silent prompts and passed as `file://` from
a private temp file, never as a command-line argument:

```bash
docker run --rm authelia/authelia:4.39.28 \
  authelia crypto hash generate pbkdf2 --variant sha512 \
  --random --random.length 64 --random.charset alphanumeric

read -rsp "plaintext: " PLAIN; echo; read -rsp "hash: " HASH; echo
umask 077; T=$(mktemp)

jq -n --arg v "$PLAIN" '{authelia_oidc_vaultwarden_client_secret: $v}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id k3s-apps/vaultwarden --secret-string "file://$T"

aws secretsmanager get-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --query SecretString --output text \
  | jq --arg v "$HASH" '.authelia_oidc_vaultwarden_client_secret_hash = $v' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --secret-string "file://$T"

rm -f "$T"; unset PLAIN HASH
```

The second write merges one key into Authelia's existing JSON; it never
replaces the whole blob. Then add an `authelia-oidc:vaultwarden` entry to
`rotation-schedule.json` with the real seeding date.

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
needs a coordinated update with `home-infra/authelia` plus a Terraform
apply. Not automated.

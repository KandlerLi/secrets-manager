# Secret: `home-infra/argocd`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/argocd"]`, defined in the
root `main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A new secret, not a
migration.

**Consumed by**: [`k3s-bootstrap`](https://github.com/KandlerLi/k3s-bootstrap)' `argocd.tf` and `argocd_platform.tf`, read via
`secrets.tf` by the `k3s-bootstrap-local` identity (read-only grant in
[`terraform-state`](https://github.com/KandlerLi/terraform-state)'s `k3s_bootstrap_local.tf`). Argo CD's server
signing key is not here: Argo CD generates it in-cluster.

## Keys

### `authelia_oidc_argocd_client_secret`
Plaintext half of the apps Argo CD's OIDC client
secret pair -- Authelia holds the matching hash
(`home-infra/authelia`'s `authelia_oidc_argocd_client_secret_hash`).
Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md` for the exact command), then
`[`k3s-apps/scripts/rotate-oidc-client-secret.sh`](https://github.com/KandlerLi/k3s-apps/blob/main/scripts/rotate-oidc-client-secret.sh) argocd`, which
writes both secrets, applies k3s-apps (Authelia's side), then
k3s-bootstrap (Argo CD's side). Verify for real afterward: sign out of
`argo.jkandler.de`, "Log in via Authelia" must land back in Argo CD
authenticated.

### `authelia_oidc_argocd_platform_client_secret`
Plaintext half of the platform Argo CD's OIDC client secret pair (ADR
0037, client `argocd-platform`, UI on `argo-platform.jkandler.de`, LAN
only). Authelia holds the hash (`home-infra/authelia`'s
`authelia_oidc_argocd_platform_client_secret_hash`). Rotation: same as
above with `rotate-oidc-client-secret.sh argocd-platform`.

## Bootstrapping a new client's first pair

Since 2026-11-28, `rotate-oidc-client-secret.sh <client> --new` writes
both halves when neither key exists yet (and refuses if one does). It
skips the k3s-bootstrap apply: k3s-bootstrap starts reading the key in
its own PR. Then add an `authelia-oidc:<client>` entry to
`rotation-schedule.json` with the seeding date.

The first pair of `argocd` (2026-11) was seeded by hand like this,
before `--new` existed:

```bash
docker run --rm authelia/authelia:4.39.22 \
  authelia crypto hash generate pbkdf2 --variant sha512 \
  --random --random.length 64 --random.charset alphanumeric

read -rsp "plaintext: " PLAIN; echo; read -rsp "hash: " HASH; echo
umask 077; T=$(mktemp)

jq -n --arg v "$PLAIN" '{authelia_oidc_argocd_client_secret: $v}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id home-infra/argocd --secret-string "file://$T"

aws secretsmanager get-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --query SecretString --output text \
  | jq --arg v "$HASH" '.authelia_oidc_argocd_client_secret_hash = $v' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id home-infra/authelia --secret-string "file://$T"

rm -f "$T"; unset PLAIN HASH
```

The second write merges one key into Authelia's existing JSON; it never
replaces the whole blob. Then add an `authelia-oidc:argocd` entry to
`rotation-schedule.json` with the real seeding date.

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
needs a coordinated update with `home-infra/authelia` plus two Terraform
applies. Not automated.

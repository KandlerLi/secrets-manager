# Secret: `k3s-apps/eurooffice`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/eurooffice"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A new secret, not a migration
(ADR 0034, Euro-Office on k3s).

**Consumed by**: the External Secrets Operator in `apps` (role
`k3s-eso-apps`, ADR 0032) through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)':
- `argocd/eurooffice/externalsecret.yaml` → `eurooffice-env`
  (`JWT_SECRET` for docservice and converter),
- `argocd/nextcloud/externalsecret.yaml` → `nextcloud-env`
  (`EUROOFFICE_JWT_SECRET`, which Nextcloud's start hook writes into the
  `eurooffice` connector app).

## Keys

### `jwt_secret`
Shared secret both sides sign and verify every request with. At least 32
characters: the connector refuses shorter ones.

**Rotation**: write the new value here, then force-sync both Secrets at
once so neither side keeps the old value for long:
`kubectl -n apps annotate externalsecret eurooffice-env nextcloud-env force-sync=$(date +%s) --overwrite`.
Reloader restarts both Pods; Nextcloud's hook writes the new value into
the connector. Open editing sessions end. Check: open a document in
Nextcloud.

## Bootstrapping the first value

Random, written without the value passing through a command-line argument
or the terminal:

```bash
umask 077; T=$(mktemp)
openssl rand -hex 32 | jq -Rn '{jwt_secret: input}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id k3s-apps/eurooffice --secret-string "file://$T"
rm -f "$T"
```

## Automated rotation

Not automated: both Pods restart and open sessions end, so it is a
deliberate step.

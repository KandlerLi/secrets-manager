# Secret: `k3s-apps/nextcloud`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/nextcloud"]`, defined in the
root `main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A new secret, not a
migration (ADR 0033, Nextcloud from AIO to k3s).

**Consumed by**: the External Secrets Operator in `apps` (role
`k3s-eso-apps`, ADR 0032) through [`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/nextcloud/externalsecret.yaml`, which builds `nextcloud-env` and
`nextcloud-postgres`, hourly or at once with
`kubectl -n apps annotate externalsecret nextcloud-env nextcloud-postgres force-sync=$(date +%s) --overwrite`;
Reloader then restarts Nextcloud. The OIDC client secret is not here:
the k3s instance reads it from `home-infra/nextcloud`, shared with AIO
until the cutover.

## Keys

### `nextcloud_postgres_password`
PostgreSQL password of the `nextcloud` role. Used by the database
sidecar (`POSTGRES_PASSWORD`, only read on first initialisation) and by
Nextcloud as `NC_dbpassword`, which overrides `dbpassword` in
`config.php`. **Rotation is not a Secrets Manager write alone**: the
live database keeps the old password until
`ALTER ROLE nextcloud PASSWORD '…'` runs inside the database sidecar;
change it there first, then write the same value here and force-sync.

### `nextcloud_admin_password`
Password of the `admin` account the image creates on first
installation (`NEXTCLOUD_ADMIN_PASSWORD`), read only while
`config.php` doesn't exist yet. Used by the empty test instance of
migration step 2; after the cutover the instance runs on AIO's
database and its accounts, and this key can go. Rotating it changes
nothing in a running instance: use `occ user:resetpassword admin`.

## Bootstrapping the first value

Both keys are random. Generated and written without either value
passing through a command-line argument or the terminal:

```bash
umask 077; T=$(mktemp)
{ openssl rand -hex 24; openssl rand -hex 24; } \
  | jq -Rn '[inputs] | {nextcloud_postgres_password: .[0], nextcloud_admin_password: .[1]}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id k3s-apps/nextcloud --secret-string "file://$T"
rm -f "$T"
```

## Automated rotation

Not automated: the Postgres password needs the `ALTER ROLE` step above
first, and the admin password is only a bootstrap value.

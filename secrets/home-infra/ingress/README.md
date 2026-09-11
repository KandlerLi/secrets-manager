# Secret: `home-infra/ingress`

**Terraform resource**:
`module.home_infra_ingress.aws_secretsmanager_secret.this`, defined in
`./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/ingress`, read via
`secrets.tf`.

## Keys

### `k3s_ingress_acme_dns01_access_key_id` / `k3s_ingress_acme_dns01_secret_access_key`
`dyndns`'s own `traefik-acme-dns01` IAM user credentials, scoped to
exactly `route53:ChangeResourceRecordSets`/`GetChange` on the
`jkandler.de` zone — used continuously for Let's Encrypt's DNS-01
challenge, real certificate issuance/renewal. Rotate via
`aws iam create-access-key` on that user, `put-secret-value`,
`terraform apply`. Delete the old access key from IAM only after
confirming the new one issued a real certificate — renewal runs
continuously, so there's no safe credential-less window.

## Removed: `shared_ingress_auth_password` / `shared_ingress_auth_password_hash` (2026-09-11)

Traefik HTTP Basic Auth for user `julian` — had been **dormant** since
the 2026-09-08 Authelia forward-auth cutover (defined as a
`basicAuth` middleware in `modules/ingress/configmap.tf`, but not
referenced by any `*-chain`), kept deliberately as a one-chain-edit
rollback path in case Authelia's own SQLite storage issue
(`BACKLOG.md`'s "Ingress auth: Authelia SQLite storage lost data
twice") recurred. Retired once forward-auth had held stable across
several more days of real, varied production traffic with no
recurrence: the `basicAuth` middleware, the
`kubernetes_secret_v1.ingress_users` Secret it fed, and the
`shared_ingress_auth_password_hash` Terraform variable were all
removed from `infra/k3s-apps`' `modules/ingress`
(PR [#41](https://github.com/KandlerLi/k3s-apps/pull/41)); the keys
were dropped from this group's JSON in the same pass.
`infra/home-infra`'s `scripts/sync_secrets_to_pass.py` — whose only
remaining mapping was `shared_ingress_auth_password` → `ingress/password`
— was retired outright rather than left as a permanent no-op.

There is no instant rollback any more if `authelia-forward-auth`
breaks again: recovery is the known ~5-minute `db.sqlite3` recreate
drill, or rebuilding the old middleware from git history
(`infra/k3s-apps` PR #41's own diff).

## Automated rotation

`k3s_ingress_acme_dns01_*`: worth automating — mechanically simple IAM
key rotation, low blast radius. Not yet built.

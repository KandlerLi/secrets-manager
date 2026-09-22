# Secret: `home-infra/ingress`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/ingress"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/ingress`, read via
`secrets.tf`.

## Keys

### `k3s_ingress_acme_dns01_access_key_id` / `k3s_ingress_acme_dns01_secret_access_key`
`dyndns`'s own `traefik-acme-dns01` IAM user credentials, scoped to
exactly `route53:ChangeResourceRecordSets`/`GetChange`/
`ListResourceRecordSets` on the `jkandler.de` zone — used for Let's
Encrypt's DNS-01 challenge, real certificate issuance/renewal.

**Rotation, real procedure (rotated live 2026-09-11)**: the access key
is itself a Terraform resource in `aws/dyndns`
(`aws_iam_access_key.acme_dns01`) — it has no in-place rotation, only
destroy+recreate, and `lifecycle { create_before_destroy = true }` was
added to it specifically so this can be done with zero
credential-less window (IAM permits 2 access keys per user):

```bash
# in aws/dyndns, against its own state
terraform apply -replace=aws_iam_access_key.acme_dns01
```

Then `terraform output -raw acme_dns01_access_key_id`/
`acme_dns01_secret_access_key`, `put-secret-value` the pair into this
group, `terraform apply` in `infra/k3s-apps`. The old key is already
gone from IAM by this point (destroyed as part of the `-replace`, not
a separate manual step afterward) — `checksum/acme-dns01-credentials`
on `modules/ingress`'s Deployment (added 2026-09-11, after this exact
rotation caught the gap live: the Secret updated but the already-running
Pod kept the just-deleted key in memory until a manual restart) rolls
a fresh Pod automatically once the Secret changes, so there's nothing
left to do by hand. Verify for real, not just a clean `terraform
apply`: the new key's actual Route53 permissions, e.g. a throwaway
`UPSERT`/`DELETE` TXT record round-trip with the new credentials
directly (`aws route53 change-resource-record-sets` +
`wait resource-record-sets-changed`) — a clean apply only proves the
Secret updated, not that the key can actually do what `lego` needs.

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

`k3s_ingress_acme_dns01_*`: still worth automating, and now genuinely
easy — proven live 2026-09-11 as a clean three-command sequence
(`terraform apply -replace` in `aws/dyndns`, `put-secret-value`,
`terraform apply` in `infra/k3s-apps`), with `create_before_destroy`
and the new checksum annotation together removing the two things that
would otherwise make this unsafe to run unattended (a credential-less
window, a stale Pod not picking up the new key). Not yet built — the
one piece a scheduled job can't do unattended is the real functional
verification (the throwaway Route53 record round-trip), so it would
need to trust the mechanics rather than re-prove them each run, or
build a scripted version of that same round-trip check.

# Secret: `home-infra/blocky`

**Terraform resource**:
`module.home_infra_blocky.aws_secretsmanager_secret.this`, defined in
`./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-12 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/blocky` (the Postgres
sidecar and Blocky's own `config.yml`) and `modules/grafana` (its own
Postgres datasource config), both via `secrets.tf`.

## Keys

### `blocky_postgres_password`
Self-hosted, in-cluster Postgres password for Blocky's query-log
database — **not** an AWS-managed database, so Secrets Manager's
native RDS-style rotation templates don't apply. The database itself
needs the change made directly; Secrets Manager having the new value
isn't enough on its own:

```bash
kubectl exec -it deploy/blocky -c postgres -- psql -U blocky -c \
  "ALTER USER blocky WITH PASSWORD '<new-password>';"
```

then `put-secret-value` and `terraform apply` (rolls both Blocky's and
Grafana's Deployments — `checksum/config`/`checksum/postgres-credentials`
on `modules/blocky` and `checksum/datasources` on `modules/grafana`,
added 2026-09-12 specifically so this works; before that, neither Pod
would have picked up the new value without a manual restart) — in
that order, so the old value still works during the brief gap between
the `ALTER USER` and the apply picking it up, rather than locking
Blocky out.

**Automated as of 2026-09-12**: `infra/k3s-apps/scripts/
rotate-blocky-postgres-password.sh` (or the scheduled GitHub Actions
workflow calling it) does exactly this sequence — see that script's
own header comment for the full detail.

## Automated rotation

Built 2026-09-12 as a scheduled GitHub Actions workflow in
`infra/k3s-apps` (the in-cluster self-hosted runner already has
`kubectl` and runs `terraform apply` there) — the one secret in this
entire workspace where unattended rotation was judged genuinely safe:
mechanically simple, low blast radius, no external system whose own
UI needs separate reconfiguring (unlike every OIDC pair or
`dyndns/fritzbox`'s router-side credential).

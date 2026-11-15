# Secret: `home-infra/blocky`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/blocky"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from [`terraform-state`](https://github.com/KandlerLi/terraform-state)
2026-09-12 — container only, no value.

**Consumed by**: the External Secrets Operator, since 2026-11-15
(ADR 0032): in `apps` for Blocky ([`k3s-apps`](https://github.com/KandlerLi/k3s-apps)'
`argocd/blocky/externalsecret.yaml`: `config.yml`'s query-log URL, the
Postgres sidecar's credentials and the exporter's DSN) and in
`monitoring` for Grafana's Postgres datasource
(`argocd/grafana/externalsecret.yaml`).

## Keys

### `blocky_postgres_password`
Self-hosted, in-cluster Postgres password for Blocky's query-log
database — **not** an AWS-managed database, so Secrets Manager's
native RDS-style rotation templates don't apply, and writing a new
value here alone breaks the logins: the database needs the change too.
Inside the Pod, Blocky and the exporter connect over 127.0.0.1, which
the sidecar trusts; the password guards only network access, i.e.
Grafana's.

**Rotation**: yearly or on suspicion, by hand from the laptop with
`aws login` done:

```bash
cd ~/projects/infra/k3s-apps && git checkout main && git pull && scripts/rotate-blocky-postgres-password.sh
```

It ALTERs the role through `kubectl exec` into the Postgres sidecar
(SQL on stdin, never in argv), writes the new value here (merged, never
overwriting the group), forces ESO to sync the three Blocky Secrets and
Grafana's datasource, and waits for Reloader's restarts. If the
Secrets Manager write fails after the ALTER, rerun the script. Then
check Grafana's Blocky query-log dashboard for fresh queries, and record
the rotation with `scripts/manage-rotation-schedule.sh`.

## History

From 2026-09-12 to 2026-11-15 a monthly GitHub Actions workflow in
[`k3s-apps`](https://github.com/KandlerLi/k3s-apps) rotated this unattended on the in-cluster runner, the one
unattended rotation in the workspace. It went with the move to ESO,
since `k3s-apps`' CI loses its cluster and AWS access; it had also
failed since the move to ARC runners (no AWS CLI in their image), so
the last real rotation was 2026-10-27.

# Secret: `k3s-apps/sankey-export`

**Terraform resource**:
`module.k3s_apps_sankey_export.aws_secretsmanager_secret.this`, defined
in `./main.tf` alongside this file (`bootstrap/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-10, the pilot for the campaign in that repo's own README —
container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/sankey_export`, read via
`secrets.tf`. This module's own image pull also depends on a second,
separate secret — `k3s-apps/ghcr-pull-token`, shared with
`modules/home_agent` — not documented here since this file only covers
what's actually in this group's own JSON.

## Keys

### `sankey_export_app_password`
Nextcloud app password for the dedicated `sankey-export` bot account
(never `admin`) — used to download the budget spreadsheet and upload
the rendered PNG back over WebDAV.

**Rotation:** mint the new token on the homeserver, then let the helper
script do the rest.

```bash
# on the homeserver -- the one step nothing else can do (see below)
docker exec nextcloud-aio-nextcloud php occ user:auth-tokens:add \
  --name "rotate-$(date +%F)" -- sankey-export

# then, from an infra/k3s-apps checkout, with `aws login` done (the
# script opens the SSH tunnel itself, like roll-out.sh elsewhere):
scripts/rotate-sankey-export-app-password.sh 'the-printed-token'
```

The script merges the token into this secret (`put-secret-value`), runs
`terraform apply` to roll `kubernetes_secret_v1.sankey_export_app_password`,
waits for the next CronJob run to prove the new token works, and prints
the `occ user:auth-tokens:delete` command for the old token. It never
touches the old token — both stay valid until you delete the old one,
so there's no blackout window.

## Automated rotation

**The mint step is a hard wall.** A Nextcloud app password cannot mint
another one (a deliberate Nextcloud boundary — `GET /ocs/v2.php/core/getapppassword`
rejects app-password auth). The only things that can are `occ` on the
homeserver, or the account's login password:

- The in-cluster self-hosted runner *can* reach Nextcloud's WebDAV/OCS
  endpoint (`192.168.101.1:11000`, the same one the CronJob uses), but
  `occ` runs *inside* the `nextcloud-aio-nextcloud` container — the
  runner has no `docker exec` / SSH to the homeserver, and giving it a
  key (shared across all 7 repos' workflows) is far too much privilege
  for a bot password.
- The `sankey-export` account's login password was generated and
  discarded at bootstrap (ADR 0008) — storing it just to enable
  `getapppassword` automation trades an occasionally-rotated app
  password for a never-rotated login password plus a scheduled
  workflow, marginal value for a once-a-year-at-most rotation.

An AWS-native rotation Lambda is doubly blocked: no route to the
private k3s network at all, *and* nothing propagates a `put-secret-value`
into the live Kubernetes Secret without a `terraform apply` a Lambda
can't run. See
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md`'s own reality-check
section.

**So**: everything after the mint is automated
(`scripts/rotate-sankey-export-app-password.sh`); the mint stays one
manual `occ` line. Same practical ceiling as
`home-infra/home-agent`'s own `nextcloud_tools_app_password`.

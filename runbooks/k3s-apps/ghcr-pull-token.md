# Secret: `k3s-apps/ghcr-pull-token`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/ghcr-pull-token"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Created 2026-09-12 — container only, no
value. **Not a migration**: this key was split out of
`home-infra/home-agent`'s own group the same day, the first time this
campaign has restructured an already-migrated secret's contents rather
than just moving an existing container between Terraform roots.

**Consumed by**: sankey-export, through ESO in `apps`
([`k3s-apps`](https://github.com/KandlerLi/k3s-apps)' `argocd/sankey-export/externalsecret.yaml`). Until
2026-11-16 home_agent's image pull used it too; that app is retired.

Since 2026-10-30 also read by [`renovate`](https://github.com/KandlerLi/renovate)'s
scheduled workflow (only the `token` key, masked), to look up new
digests of the image (tracker #46). It reads the value at each run,
so a rotation needs nothing there.

## Keys

### `token`
A single, account-scoped fine-grained GitHub PAT (`read:packages` on
the `KandlerLi` GitHub account) — not tied to one specific package.
Authorizes pulling `ghcr.io/kandlerli/sankey-export` (private).

**Rotation**: generate a new fine-grained PAT in GitHub's own PAT
settings with the same `read:packages` scope, `put-secret-value`, then
force-sync the pull Secret (or wait up to an hour):
`kubectl -n apps annotate externalsecret sankey-export-ghcr-pull-secret force-sync=$(date +%s) --overwrite`. Verify for real before considering it done: a
clean apply only proves the Kubernetes Secret objects updated, not
that the new token can actually authenticate against GHCR. A direct
check against the registry's own API (no `docker`/`skopeo` needed):

```bash
curl -su "KandlerLi:<new-token>" https://ghcr.io/v2/kandlerli/sankey-export/tags/list
```

It should return a real tag list (`{"name":"...","tags":[...]}`), not
a `401`/`403`. Revoke the old PAT in GitHub only after confirming both.

## Automated rotation

Possible in principle (minting a new fine-grained PAT has no
programmatic API as of this writing — same limitation
`home-infra/github-runner`'s own doc already notes) but not built.

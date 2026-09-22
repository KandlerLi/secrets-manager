# Secret: `k3s-apps/ghcr-pull-token`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/ghcr-pull-token"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Created 2026-09-12 — container only, no
value. **Not a migration**: this key was split out of
`home-infra/home-agent`'s own group the same day, the first time this
campaign has restructured an already-migrated secret's contents rather
than just moving an existing container between Terraform roots.

**Consumed by**: `infra/k3s-apps`' `modules/home_agent` and
`modules/sankey_export`, both via `secrets.tf` — genuinely two
independent consumers of the exact same credential, not a shared
container for convenience. Splitting it out made that explicit in the
name; `home-infra/home-agent`'s own group used to hold this too, which
made rotating "home-agent's own secrets" silently also roll a
completely unrelated CronJob.

## Keys

### `token`
A single, account-scoped fine-grained GitHub PAT (`read:packages` on
the `KandlerLi` GitHub account) — not tied to one specific package.
Authorizes pulling both `ghcr.io/kandlerli/home-agent` (private,
`modules/home_agent`'s own image) and `ghcr.io/kandlerli/sankey-export`
(private, `modules/sankey_export`'s own image), two otherwise-unrelated
workloads that happen to both need GHCR pull access under the same
GitHub account.

**Rotation**: generate a new fine-grained PAT in GitHub's own PAT
settings with the same `read:packages` scope, `put-secret-value`, then
`terraform apply` in `infra/k3s-apps` — one apply rolls both
`home_agent`'s and `sankey_export`'s Deployments together, since both
read this exact value. Verify for real before considering it done: a
clean apply only proves the Kubernetes Secret objects updated, not
that the new token can actually authenticate against GHCR. A direct
check against the registry's own API (no `docker`/`skopeo` needed):

```bash
curl -su "KandlerLi:<new-token>" https://ghcr.io/v2/kandlerli/home-agent/tags/list
curl -su "KandlerLi:<new-token>" https://ghcr.io/v2/kandlerli/sankey-export/tags/list
```

Both should return a real tag list (`{"name":"...","tags":[...]}`), not
a `401`/`403`. Revoke the old PAT in GitHub only after confirming both.

## Automated rotation

Possible in principle (minting a new fine-grained PAT has no
programmatic API as of this writing — same limitation
`home-infra/github-runner`'s own doc already notes) but not built.

# Secret: `home-infra/github-runner`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/github-runner"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from
`bootstrap/terraform-state` 2026-09-12 — container only, no value.

**Consumed by**: `bootstrap/k3s-bootstrap`'s `modules/github_runner`,
read via that repo's own `secrets.tf`. The `k3s-bootstrap-local` IAM
identity that applies that repo has a dedicated, **read-only** grant
on this one secret (`bootstrap/terraform-state/k3s_bootstrap_local.tf`,
a wildcard ARN string as of this migration — same pattern as `julian`'s
own grant on every migrated secret) — unlike `julian`'s own read/write
grant, since `k3s-bootstrap-local` is a scripted, non-interactive
identity; only `julian`'s own credentials edit/rotate this value.

## Keys

**Replaced 2026-09-16**: this secret used to hold one key,
`github_runner_github_token` — a durable, fine-grained PAT with
`Administration: write` on every self-hosted-runner repository,
manually rotated on GitHub's own expiry schedule. Switched to GitHub
App credentials instead — `myoung34/github-runner` (the runner image
`modules/github_runner` uses) natively mints its own short-lived
registration token from these at container start, removing the manual
rotation chore entirely rather than just making it easier.

### `app_id`

The GitHub App's own numeric App ID (`kandlerli-home-infra-runner`,
App ID `4964876`). Not itself secret — GitHub shows it on the App's
own public settings page — but kept in this same JSON blob as
`app_private_key` for convenience, matching every other Secrets
Manager group's own shape in this workspace (one blob, not one secret
per field).

### `app_private_key`

The App's own private key, PEM, exactly as GitHub's "Generate a
private key" button downloads it (real newlines, not escaped `\n` —
`put-secret-value` JSON-encodes the file's actual content correctly
either way). Genuinely secret: this is what lets the runner mint a
real installation access token. Installed on every repository in
`github/repo-infra/config.yml`'s `runner: true` list, with
`Administration: write` — the exact same permission scope the old PAT
needed.

`put-secret-value`, then an actual `bootstrap/k3s-bootstrap` apply —
every repo's runner Deployment shares one Kubernetes Secret
(`modules/github_runner`), so one apply rolls every runner at once
(the pod-template checksum annotation hashes `app_private_key`
specifically, so Kubernetes only actually restarts anything when the
key itself changes). Confirm at least one runner re-registered
successfully post-apply before doing anything to the old key.

## Rotating the App's own key

Unlike the old PAT, this isn't rotation on a schedule — GitHub App
private keys don't expire on their own. Rotate only if the key is
suspected compromised, or as a periodic hygiene practice if you want
one: generate a new private key on the App's own settings page
(GitHub allows multiple active keys simultaneously, so the old one
keeps working during the swap), `put-secret-value` the new one here,
apply, confirm a runner re-registers, then delete the old key from the
App's settings page. `app_id` never needs to change on its own — a new
key is not a new App.

## Automated rotation

Not built, and a much smaller gap than the old PAT's own version of
this section described — GitHub App private keys don't have the same
"expires and must be manually renewed" pressure a PAT does. If ever
wanted: a Lambda that calls the App's own key-management API and
triggers a `bootstrap/k3s-bootstrap` apply afterward, same "not a
natural fit for Secrets Manager's own native rotation Lambda shape"
reasoning as before — the credential itself still lives in GitHub, not
AWS.

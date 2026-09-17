# Secrets Manager

Owns the `aws_secretsmanager_secret` **containers** for this workspace —
name, description, recovery window, and `lifecycle { prevent_destroy = true }`
only, never a value. Real secret material is set out-of-band via
`aws secretsmanager put-secret-value` (the same way SOPS kept it out of
plaintext git); there is no `aws_secretsmanager_secret_version` resource
anywhere here.

Bootstrap-category by origin (created by the same SOPS-to-Secrets-Manager
cutover as `bootstrap/terraform-state`/`bootstrap/k3s-bootstrap`), but
**CI-applied since 2026-09-13**, unlike those two — it doesn't share
their self-escalation risk. It never touches IAM at all; `julian`'s own
read/write grant on every secret lives entirely in
`bootstrap/terraform-state/operator.tf`, deliberately kept out of this
repo (see "IAM grants live in terraform-state, not here" below). It only
ever creates empty `aws_secretsmanager_secret` containers — no
`GetSecretValue`/`PutSecretValue`/`DeleteSecret` anywhere in its
Terraform. Its own CI role (`github/repo-infra/aws_policies.tf`) is
scoped to exactly `CreateSecret`/`DescribeSecret` on the name prefixes
it already manages — a compromised run can create a bogus empty
container at worst, never read or write an actual secret value.

Moved from `bootstrap/` to `aws/` locally the same day, once the
CI-apply change made it fit `aws/`'s own grouping criterion (real AWS
resources, Terraform-managed, CI-applied) better than `bootstrap/`'s —
no GitHub-side rename, this is purely local directory grouping.

## Why a separate root

These containers were created by the SOPS-to-AWS-Secrets-Manager cutover in
`bootstrap/terraform-state/secrets_manager.tf`. They're being migrated here
one secret at a time so the secrets concern is cleanly separable from the
state-bucket bootstrap concern and can grow its own per-secret documentation
and rotation tooling without bloating `terraform-state`.

## Layout

One self-contained module directory per secret, under
`secrets/<owning-repo>/<service>/`: its `main.tf` (the
`aws_secretsmanager_secret` resource + an `arn` output) and its
`README.md` (keys, consumers, rotation). Root `main.tf` calls each with
a `module` block. Until a secret has migrated it has only a `.md` file
under `secrets/` (no directory).

## Backend

```text
bucket: jkandler-terraform-state
key:    secrets-manager/terraform.tfstate
region: eu-central-1
```

## Apply model

**CI-applied on merge, same as `infra/k3s-apps`** — PR review is the
gate, `.github/workflows/apply.yml` runs `terraform apply` via this
repo's own dedicated OIDC role (`secrets-manager-github-actions`,
`github/repo-infra/aws_policies.tf`). No `scripts/roll-out.sh` any
more — retired 2026-09-13 once CI took over the routine path, the same
way no such script ever existed for `k3s-apps` once its own CI landed
(this workspace's convention is not to keep a maintained local-apply
script around once CI covers the same ground, matching how
`aws/dyndns`'s own `protect-repository.sh` was deleted outright rather
than kept as a documented exception). A genuine emergency can still
fall back to plain local `terraform init/plan/apply` as root — just not
a routine, scripted path.

`julian`'s own operator policy is still deliberately scoped to
`repo-infra/*` state only and cannot touch this root's state (ADR
0018's self-escalation guarantee) — that constraint is about `julian`
specifically, not about CI existing. This root's own CI role is a
separate, narrowly-scoped identity with no relationship to `julian`'s
own permissions at all.

## IAM grants live in `terraform-state`, not here

`julian`'s `GetSecretValue`/`DescribeSecret`/`PutSecretValue` grant on
every container is a statement in
`bootstrap/terraform-state/operator.tf`'s `terraform-operator` policy,
next to the rest of `julian`'s operator permissions — it does **not**
move here as containers migrate. Containers still defined in
`terraform-state`'s own `secrets_manager.tf` are covered there by real
resource references; ones migrated here are covered by a wildcard ARN
string (`...:secret:<name>-*`). When `home-infra/github-runner` migrates,
`k3s_bootstrap_local.tf`'s own `ReadGithubRunnerSecret` statement
similarly switches from a resource reference to a wildcard string,
staying in `terraform-state`.

Consumers (`infra/k3s-apps/secrets.tf`, `bootstrap/k3s-bootstrap/secrets.tf`,
`infra/home-infra`'s Ansible + `sync_secrets_to_pass.py`) and the
`github/repo-infra/aws_policies.tf` CI grants all reference secrets **by
name / ARN-pattern string**, never by Terraform resource reference — they
need **zero changes** as secrets migrate here.

A third location, distinct from both of the above: **this repo's own**
CI role's grant (`CreateSecret`/`DescribeSecret`, not `GetSecretValue`/
`PutSecretValue`) also lives in `github/repo-infra/aws_policies.tf`, not
here — same convention every other repo's CI permissions already
follow.

## Per-secret migration procedure (the no-destroy handoff)

Follows the ADR 0006 / ADR 0010 pattern (the `aws-account-bootstrap` →
`repo-infra` handoff; real `removed`-side example in `aws/dyndns` commit
`d8d6541`). Per secret:

**Phase A — this root gains ownership (nothing removed yet):**
1. Create `secrets/<repo>/<service>/main.tf`: the
   `resource "aws_secretsmanager_secret" "this"` (name/description/
   recovery-window copied **verbatim** from `terraform-state` so the
   import is zero-diff; keep `lifecycle { prevent_destroy = true }`) plus
   an `output "arn"`. Also add `secrets/<repo>/<service>/README.md` (move
   it from `secrets/<repo>/<service>.md`).
2. Root `main.tf`: add `module "<name>" { source = "./secrets/<repo>/<service>" }`
   plus a **transient** `import { to = module.<name>.aws_secretsmanager_secret.this, id = "<full ARN>" }`
   block. The import ID must be the **ARN**, not the secret name (AWS
   provider v6 rejects the name); get it with
   `aws secretsmanager describe-secret --secret-id <name> --query ARN --output text`.
3. Open a PR — `checks.yml`'s plan job must show exactly
   `1 to import, 0 to add/change/destroy`. Merge (CI applies). Delete
   the `import` block in a follow-up PR; its own plan job → "No
   changes."

**Phase B — `terraform-state` relinquishes (only after A is verified):**
4. In `bootstrap/terraform-state`: replace the `resource` block with
   `removed { from = aws_secretsmanager_secret.X; lifecycle { destroy = false } }`
   (this side stays committed for the whole campaign). Same commit: in
   `operator.tf`'s `ManageSecretsManagerSecrets`, move that secret's line
   from the resource-reference group to the wildcard-ARN-string group
   (`...:secret:<name>-*`) — the ARN coverage is continuous, so `julian`
   never loses access; a leftover `.arn` reference would also fail
   `terraform validate`. For `github-runner` do the same in
   `k3s_bootstrap_local.tf`'s `ReadGithubRunnerSecret` statement.
5. `terraform plan` in `terraform-state` → the secret leaves state with
   an explicit **"will not be destroyed"** line, **`0 to destroy`**, and
   an in-place policy update (one ref → one string). Any proposed secret
   destroy is a STOP condition. `terraform apply`.

**Phase C — verify no gap:**
6. "No changes" plans in both bootstrap roots; a clean plan in the
   consuming root (`infra/k3s-apps`, or `ansible-playbook ... --check`
   for `home-infra/nextcloud`, or a `bootstrap/k3s-bootstrap` plan for
   `home-infra/github-runner`); a real `aws secretsmanager get-secret-value`
   as `julian`'s own credentials.

`prevent_destroy` ↔ `removed { destroy = false }`: benign. The `removed`
block's `lifecycle` accepts only `destroy`; `prevent_destroy` vanishes with
the `resource` block, which is safe **because** `destroy = false` means
Terraform drops the resource from state with no delete API call. Never write
`removed {}` without `lifecycle { destroy = false }`.

## Migration status

| Secret | Migrated | Notes |
|---|---|---|
| `k3s-apps/sankey-export` | **yes (2026-09-10, pilot)** | value also rotated end-to-end via `infra/k3s-apps/scripts/rotate-sankey-export-app-password.sh` |
| `home-infra/grafana` | **yes (2026-09-10)** | `monitoring_grafana_admin_password` retired in the same pass (dead — Grafana native login disabled); only the OIDC client secret remains |
| `home-infra/open-webui` | **yes (2026-09-11)** | |
| `home-infra/home-agent` | **yes (2026-09-11)** | |
| `home-infra/ingress` | **yes (2026-09-11)** | `shared_ingress_auth_password(_hash)` retired in the same pass, not migrated — see that group's README |
| `home-infra/monitoring` | **yes (2026-09-11)** | dual consumer — Terraform (`k3s-apps`) and Ansible plan/lookup both verified clean |
| `home-infra/nextcloud` | **yes (2026-09-11)** | Ansible-only consumer, verified via a direct lookup test |
| `home-infra/github-runner` | **yes (2026-09-12)** | also switched the `k3s-bootstrap-local` grant to a wildcard string |
| `dyndns/fritzbox` | **yes (2026-09-12)** | the one group whose source root isn't `bootstrap/terraform-state` — see below |
| `home-infra/blocky` | **yes (2026-09-12)** | + rotation automation (increment 2, lives in `infra/k3s-apps`) |
| `home-infra/authelia` | **yes (2026-09-12)** | last group — 9 keys, highest blast radius |

`k3s-apps/ghcr-pull-token` isn't in this table — it's a genuinely new
secret, not a migration (split out of `home-infra/home-agent`
2026-09-12; see `secrets/k3s-apps/ghcr-pull-token/README.md`).

`dyndns/fritzbox` didn't come from `bootstrap/terraform-state/
secrets_manager.tf` at all — it was created directly in `aws/dyndns`
(a real CI/PR-gated repo), the first and so far only secret in this
campaign with that shape. Same no-destroy handoff, just with the
"source relinquishes" half going through a normal `aws/dyndns` PR
([#26](https://github.com/KandlerLi/dyndns/pull/26)) instead of a
direct local apply — and its `removed` block lives there permanently,
not in `bootstrap/terraform-state`, so it was outside the final-sweep
count below.

**Final sweep done, 2026-09-12**: all 10 original groups (everything
except `dyndns/fritzbox`, which relinquishes in `aws/dyndns` itself)
migrated and stable — `bootstrap/terraform-state/secrets_manager.tf`
and all 10 `removed` blocks it held are deleted outright.
`operator.tf`'s `ManageSecretsManagerSecrets` statement stays
permanently, exactly as anticipated: `julian`'s read/write grant on
these secrets doesn't move with the container between repos, so it
remains 10 wildcard ARN strings there regardless of which repo owns
each container (collapsing `...:secret:home-infra/*` /
`...:secret:k3s-apps/*` into two was considered and declined — the
per-secret entries are more legible and cost nothing extra).

## Trivy AWS-0098 (customer-managed key) suppressed, not fixed

Every secret container here trips AWS-0098 ("Secrets Manager should
use customer managed keys") -- deliberately left unfixed, decided
2026-09-14. LOW severity, and these are containers only (no
`aws_secretsmanager_secret_version` anywhere in this repo -- real
values are set out-of-band, Terraform never even handles plaintext).

What actually makes this different from every other trivy fix in this
workspace's security-audit rollout: Secrets Manager's KMS key has to be
usable directly by every principal that reads or writes a secret
*value*, not routed through a single AWS service principal the way
CloudWatch Logs/CloudTrail/SNS are. Tracing the real consumers turned
up 5 separate IAM identities across 4 repos that would all need new KMS
grants to keep working: `julian` (`bootstrap/terraform-state/
operator.tf`, read/write on all 12), `dyndns`'s own Lambda role
(`dyndns/fritzbox`), `k3s-apps`'s CI role (8 of the `home-infra/*`
groups plus both `k3s-apps/*` ones), and `home_infra_local`/
`k3s_bootstrap_local` (`bootstrap/terraform-state`, `home-infra/
monitoring`+`nextcloud` and `home-infra/github-runner` respectively).
Missing even one of those grants means that principal silently loses
the ability to decrypt a secret it depends on. Not proportionate to
fix for a LOW-severity, metadata-only finding -- revisit only if the
real risk profile changes (e.g. these containers start holding
anything more sensitive than they do today).

## Rotation

Per-secret rotation procedures: `secrets/`. Cross-cutting rotation categories
and automated-rotation feasibility:
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md`. Only
`blocky_postgres_password` gets automated rotation (a scheduled GitHub
Actions workflow that lives in `infra/k3s-apps`, since bootstrap repos have
no runner); everything else is manual-by-design.

`rotation-schedule.json` (this repo's own root) plus
`.github/workflows/check-secret-rotation.yml` close BACKLOG.md's own
"Manually-rotated Secrets Manager secrets have no rotation reminder" --
a **reminder**, not automated rotation: a daily scheduled job emails
`julian.kandler@outlook.com` once a listed secret is within 7 days of
its recorded `last_rotated + rotate_every_days` deadline, via the
already-verified `alerts@jkandler.de` SES identity (`aws/ses-relay`).
Covers every real credential in this repo (tracked per-key, not
per-container, since a multi-key group like `home-infra/authelia`
holds several keys with unrelated rotation history) except
`blocky_postgres_password`, which already has real automated rotation
(`infra/k3s-apps`' `rotate-blocky-postgres.yml`) that this
manually-maintained file would never stay in sync with. Only
`k3s-apps/ghcr-pull-token` has a real platform-enforced deadline
(GitHub's own 90-day classic-PAT expiry -- see
`docs/home-infra-ai-context`'s own `decisions.md` entry on why that
has to stay a classic PAT); every other entry's interval is a
self-imposed hygiene choice, not a hard deadline -- rotate the real
credential first, then update `last_rotated` in the same change; the
file only ever reflects
what's already true, it never drives rotation itself.

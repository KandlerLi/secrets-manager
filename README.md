# Secrets Manager

Owns the `aws_secretsmanager_secret` **containers** for this workspace —
name, description, recovery window, and `lifecycle { prevent_destroy = true }`
only, never a value. Real secret material is set out-of-band via
`aws secretsmanager put-secret-value` (the same way SOPS kept it out of
plaintext git); there is no `aws_secretsmanager_secret_version` resource
anywhere here.

Third foundational bootstrap-category root beside `bootstrap/terraform-state`
and `bootstrap/k3s-bootstrap`: rare changes, applied only locally by a human,
never CI.

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

Applied only as **root / an admin-equivalent identity**, never as `julian`
(same self-escalation reasoning as `bootstrap/terraform-state`'s own
`operator.tf` header and ADR 0018 — `julian`'s operator policy is scoped
to `repo-infra/*` state and cannot touch this root's state; **do not add
a grant for this key**). No scripted/CI identity exists for this root.

```bash
aws login            # as root, first
scripts/roll-out.sh plan
scripts/roll-out.sh apply
```

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
3. `scripts/roll-out.sh plan` → must show exactly
   `1 to import, 0 to add/change/destroy`. `apply`. Delete the `import`
   block; commit; `plan` → "No changes."

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
| `home-infra/blocky` | no | + rotation automation (increment 2, lives in `infra/k3s-apps`) |
| `home-infra/ingress` | no | |
| `home-infra/monitoring` | no | dual consumer — verify Terraform + Ansible |
| `home-infra/nextcloud` | no | Ansible-only consumer |
| `home-infra/github-runner` | no | also switches the `k3s-bootstrap-local` grant to a wildcard string |
| `home-infra/authelia` | no | last — 9 keys, highest blast radius |

Final sweep once all 10 are migrated and stable: delete
`bootstrap/terraform-state/secrets_manager.tf` and all 10 `removed` blocks.
`operator.tf`'s `ManageSecretsManagerSecrets` statement stays — by then
it's 10 wildcard ARN strings (`...:secret:home-infra/*` /
`...:secret:k3s-apps/*` could collapse it to two, a judgement call at
that point).

## Rotation

Per-secret rotation procedures: `secrets/`. Cross-cutting rotation categories
and automated-rotation feasibility:
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md`. Only
`blocky_postgres_password` gets automated rotation (a scheduled GitHub
Actions workflow that lives in `infra/k3s-apps`, since bootstrap repos have
no runner); everything else is manual-by-design.

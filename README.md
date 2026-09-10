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
(`secrets/`) and rotation tooling without bloating `terraform-state`.

## Backend

```text
bucket: jkandler-terraform-state
key:    secrets-manager/terraform.tfstate
region: eu-central-1
```

## Apply model

Applied only as **root / an admin-equivalent identity**, never as `julian`.
This root grants `julian` its own Secrets Manager access, so `julian`
applying it could widen its own permissions — the same self-escalation
guarantee `bootstrap/terraform-state/operator.tf`'s header and ADR 0018
establish. `julian`'s operator policy is scoped to `repo-infra/*` state and
cannot touch `secrets-manager/terraform.tfstate`; **do not add a grant for
this key.** No scripted/CI identity exists for this root.

```bash
aws login            # as root, first
scripts/roll-out.sh plan
scripts/roll-out.sh apply
```

## IAM grants

The IAM **users** (`julian`, `k3s-bootstrap-local`) stay owned by
`bootstrap/terraform-state`. Only the policies/attachments granting them
access to the migrated secrets live here (`operator_grants.tf`):

- `aws_iam_policy.julian_secrets_manager_operator` (`secrets-manager-operator`)
  — `GetSecretValue`/`DescribeSecret`/`PutSecretValue` on every migrated
  secret's ARN, attached to the `julian` user. `Resource` grows one entry per
  migrated secret; the matching ARN is removed from
  `bootstrap/terraform-state/operator.tf` in the same change.
- `aws_iam_user_policy.k3s_bootstrap_local_read_github_runner_secret`
  (`secrets-manager-read`, read-only) — added only when `home-infra/github-runner`
  migrates; replaces the `ReadGithubRunnerSecret` statement in
  `bootstrap/terraform-state/k3s_bootstrap_local.tf`.

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
1. Add the permanent `resource "aws_secretsmanager_secret" "X"` block
   (name/description/recovery-window copied **verbatim** from
   `terraform-state` so the import is zero-diff; keep
   `lifecycle { prevent_destroy = true }`) plus a **transient**
   `import { to = ..., id = "<full ARN>" }` block. The import ID must be
   the **ARN**, not the secret name — AWS provider v6 rejects the name.
   Get the current ARN (including AWS's random suffix) with
   `aws secretsmanager describe-secret --secret-id <name> --query ARN --output text`.
2. `scripts/roll-out.sh plan` → must show exactly
   `1 to import, 0 to add/change/destroy`.
3. `scripts/roll-out.sh apply`. Delete the `import` block; commit;
   `plan` → "No changes."
4. Add the secret's ARN to `julian_secrets_manager_operator` (first secret:
   also create the policy + attachment). `apply`. `julian` now reads the
   secret via **both** the old and new grants (IAM is additive — no gap).

**Phase B — `terraform-state` relinquishes (only after A is verified):**
5. In `bootstrap/terraform-state`: replace the `resource` block with
   `removed { from = aws_secretsmanager_secret.X; lifecycle { destroy = false } }`
   (this side stays committed for the whole campaign). Same commit: drop the
   ARN from `operator.tf`'s `ManageSecretsManagerSecrets` (dangling `.arn`
   reference otherwise fails `terraform validate`); for `github-runner` also
   delete `k3s_bootstrap_local.tf`'s `ReadGithubRunnerSecret` statement.
6. `terraform plan` → the secret leaves state with an explicit **"will not be
   destroyed"** line and **`0 to destroy`**. Any proposed secret destroy is a
   STOP condition. `terraform apply`.

**Phase C — verify no gap:**
7. "No changes" plans in both bootstrap roots; a clean plan in the consuming
   root (`infra/k3s-apps`, or `ansible-playbook ... --check` for
   `home-infra/nextcloud`, or a `bootstrap/k3s-bootstrap` plan for
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
| `k3s-apps/sankey-export` | in progress (pilot) | |
| `home-infra/blocky` | no | + rotation automation (increment 2, lives in `infra/k3s-apps`) |
| `home-infra/open-webui` | no | |
| `home-infra/grafana` | no | |
| `home-infra/home-agent` | no | |
| `home-infra/ingress` | no | |
| `home-infra/monitoring` | no | dual consumer — verify Terraform + Ansible |
| `home-infra/nextcloud` | no | Ansible-only consumer |
| `home-infra/github-runner` | no | also moves the `k3s-bootstrap-local` grant |
| `home-infra/authelia` | no | last — 9 keys, highest blast radius |

Final sweep once all 10 are migrated and stable: delete
`bootstrap/terraform-state/secrets_manager.tf`, all 10 `removed` blocks, and
the whole `ManageSecretsManagerSecrets` statement from its `operator.tf`.

## Rotation

Per-secret rotation procedures: `secrets/`. Cross-cutting rotation categories
and automated-rotation feasibility:
`docs/home-infra-docs/docs/runbooks/rotate-secrets.md`. Only
`blocky_postgres_password` gets automated rotation (a scheduled GitHub
Actions workflow that lives in `infra/k3s-apps`, since bootstrap repos have
no runner); everything else is manual-by-design.

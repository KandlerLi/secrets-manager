# Secret: `home-infra/monitoring`

**Terraform resource**:
`module.home_infra_monitoring.aws_secretsmanager_secret.this`, defined
in `./main.tf` alongside this file (`aws/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/k3s-apps`' `modules/alertmanager` (SES creds,
templated into `alertmanager.yml`, `checksum/config` on the Deployment)
and `modules/authelia` (same SES identity, reused for Authelia's own
password-reset emails rather than provisioning a second one — also
`checksum/config`), both via `secrets.tf`. `infra/home-infra`'s own
Ansible (`ansible/playbooks/site.yml`'s `pre_tasks`) also reads all
three keys directly, but — confirmed live 2026-09-11 while rotating
this group for real — only to `ansible.builtin.assert` they're
non-empty/non-placeholder; nothing templates them into a file any
more (Alertmanager itself moved to k3s outright, Phase 2 of the
`modules/monitoring` migration). Migrating the container needed a
clean `infra/k3s-apps` plan and the Ansible lookup itself working
(confirmed both); a rotation doesn't need a `site.yml` re-run at all.

## Keys

### `monitoring_ses_smtp_username`
SES SMTP identity's username — tied to the underlying IAM access key,
not usually rotated independent of the password below.

### `monitoring_ses_smtp_password`
**Derived, not chosen.** This isn't a password you invent — it's
derived from a real SES secret access key via
`aws/ses-relay/scripts/derive_smtp_password.py`, AWS's own published
SigV4-based algorithm.

**Rotation, real procedure (rotated live 2026-09-11)**: the underlying
IAM access key is itself Terraform-managed
(`aws_iam_access_key.smtp` in `aws/ses-relay`, `lifecycle {
create_before_destroy = true }`, same pattern as `home-infra/ingress`'s
ACME key):

```bash
# in aws/ses-relay, against its own state
terraform apply -replace=aws_iam_access_key.smtp
python3 scripts/derive_smtp_password.py "$(terraform output -raw smtp_secret_access_key)" eu-central-1
```

`put-secret-value` the new username (`terraform output -raw
smtp_username`) and derived password into this group, `terraform
apply` in `infra/k3s-apps` — this rolls *both* Alertmanager and
Authelia (their `checksum/config` annotations restart each Deployment
automatically once its rendered config's hash changes; no manual
restart needed). The old key is already gone from IAM by this point,
same zero-credential-less-window guarantee as the ACME key. Verify for
real: a genuine SMTP AUTH + send against
`email-smtp.eu-central-1.amazonaws.com:587` with the new credentials
(`smtplib.SMTP.login()` + `send_message()`), not just a clean
`terraform apply` — proves the derived password actually authenticates
and SES actually accepts a send, exactly what Alertmanager needs to
work for real.

### `monitoring_ntfy_topic`
**Not a credential in the usual sense** — an identifier, not material
to regenerate. ntfy's own security model treats an unguessable topic
*name* as the actual secret (anyone who knows it can publish to it),
so it still belongs in Secrets Manager, but "rotating" it just means
picking a new unguessable string and updating both the publisher
(wherever alerts get sent from) and subscriber (the ntfy app/client)
to match — no cryptographic material involved.

## Automated rotation

`monitoring_ses_smtp_username`/`_password`: not a native Secrets
Manager rotation template (the derive-script step needs custom code
either way), but genuinely easy now — proven live 2026-09-11 as the
same shape as the ACME key's rotation (`terraform apply -replace`,
derive/rotate, `put-secret-value`, `terraform apply`), just with an
extra local derivation step and two consumers instead of one. Not yet
built — same reasoning as the ACME key: a scheduled job would need to
either trust the mechanics or script the real SMTP AUTH+send check
itself, not just a clean apply. `monitoring_ntfy_topic`: no real
automation need, just pick a new string when rotating.

# Secret: `home-infra/nextcloud`

**Terraform resource**:
`module.home_infra_nextcloud.aws_secretsmanager_secret.this`, defined
in `./main.tf` alongside this file (`aws/secrets-manager`, the
per-secret module dir). Migrated here from `bootstrap/terraform-state`
2026-09-11 — container only, no value.

**Consumed by**: `infra/home-infra`'s own Ansible
(`ansible/playbooks/site.yml`'s `pre_tasks`, gated on
`nextcloud_aio_oidc_enabled`), **not** Terraform — Nextcloud AIO runs
on the homeserver itself, not in k3s, unlike every other OIDC client.

## Keys

### `authelia_oidc_nextcloud_client_secret`
Plaintext half of Nextcloud's OIDC client secret pair — Authelia holds
the matching hash (`home-infra/authelia`'s
`authelia_oidc_nextcloud_client_secret_hash`; see that file's own
"Rotating this pair" note). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
`infra/k3s-apps/scripts/rotate-oidc-client-secret.sh nextcloud` (script
support added 2026-09-11 — this used to be a manual procedure). Unlike
Grafana/Open WebUI, the script's own `terraform apply` only rolls
Authelia's side here — Nextcloud AIO runs on the homeserver, not k3s,
so there's no Deployment for it there. The script additionally re-runs
`infra/home-infra`'s `site.yml` itself (`--ask-become-pass`, so it
prompts for your sudo password when you run the script) so the new
plaintext reaches Nextcloud's own `occ user_oidc:provider` config —
confirmed live this is a real upsert, not a formality (unlike
`home-infra/monitoring`'s SES creds, which turned out to be
assert-only in Ansible and need no re-run at all).

## Automated rotation

Structurally resistant, same as every OIDC pair — and this one spans
two different repos/tools (Terraform for Authelia, Ansible for
Nextcloud) for a single logical rotation, making unattended automation
even less appropriate than the Grafana/Open WebUI pairs.

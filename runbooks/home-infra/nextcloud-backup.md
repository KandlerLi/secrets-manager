# Secret: `home-infra/nextcloud-backup`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/nextcloud-backup"]`, defined in
the root `main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)). A new secret, not a migration
(ADR 0033: Nextcloud's files are backed up by restic on the homeserver).

**Consumed by**: [`home-infra`](https://github.com/KandlerLi/home-infra)'s Ansible only (`site.yml`'s
`pre_tasks`, gated on `nextcloud_storage_restic_enabled`), which writes it
to a `0400` file for the `nextcloud-restic` systemd service. Not readable
by k3s: `k3s-eso-apps` matches `home-infra/nextcloud-??????`, which this
name doesn't.

## Keys

### `restic_password`
Encryption password of the restic repository
`/mnt/red-hdd/nextcloud-restic`. **Without it the backup can't be read**:
there is no recovery. It is also what a later off-site copy of the same
repository would be opened with.

**Rotation**: not a Secrets Manager write alone. restic keeps several
keys per repository: add the new one first
(`restic key add`, as `www-data`, with the repository's environment),
write it here, roll out `home-infra` (it rewrites the password file),
check `restic snapshots` with the new file, then remove the old key
(`restic key list`, `restic key remove <id>`). Never write a new value
here before the repository knows it.

## Bootstrapping the first value

Random, generated and written without the value passing through a
command-line argument or the terminal; then roll out `home-infra`, which
initialises the repository with it:

```bash
umask 077; T=$(mktemp)
openssl rand -hex 32 | jq -Rn '{restic_password: input}' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 \
  --secret-id home-infra/nextcloud-backup --secret-string "file://$T"
rm -f "$T"
```

## Automated rotation

Not automated: the repository must learn the new key first (above).

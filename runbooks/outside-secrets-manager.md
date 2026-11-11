# Credentials outside Secrets Manager

Most credentials here live in AWS Secrets Manager. A few can't: they are
what reaches AWS in the first place, unlock the operator's own machines,
or belong to a human login. This file catalogs them by name and kind
only, never by value or location.

## Storage classes

- **`pass`**: the operator's GPG-encrypted password store, mirrored to
  LUKS-encrypted offline media. Entry names below are `pass` paths.
- **Memory + paper**: needed to reach `pass` itself (or to open the
  offline media), so it can't depend on `pass`. Kept in memory and on
  paper only.

## Rotation triggers

- **Scheduled**: only where a stolen credential stays silently usable
  (API keys, app passwords). These have entries in
  [`rotation-schedule.json`](../rotation-schedule.json), id prefix
  `pass:`.
- **On suspicion**: rotate on suspected exposure, a lost or replaced
  device, or a change of who has access. Memorised passphrases are not
  rotated on a calendar; forced changes make them weaker, not stronger.

## Catalog

| Name | Kind | Storage | Trigger | Procedure |
|---|---|---|---|---|
| `aws/home-infra-local/*` | IAM access key pair, scripted identity | `pass` | Scheduled, 90 days | [Rotating `home-infra-local`](https://github.com/KandlerLi/terraform-state/blob/main/docs/README.md#rotating-home-infra-local) |
| `aws/k3s-bootstrap-local/*` | IAM access key pair, scripted identity | `pass` | Scheduled, 90 days | [Rotating `k3s-bootstrap-local`](https://github.com/KandlerLi/terraform-state/blob/main/docs/README.md#rotating-k3s-bootstrap-local) |
| `aws/repo-infra-local/*` | IAM access key pair, scripted identity | `pass` | Scheduled, 90 days | [Rotating `repo-infra-local`](https://github.com/KandlerLi/terraform-state/blob/main/docs/README.md#rotating-repo-infra-local) |
| `aws/AWS_ACCOUNT_ID` | Identifier, not a credential | `pass` | None | -- |
| `mail/admin/api` | Stalwart API key (`emergency`), full admin | `pass` | Scheduled, 180 days | [Stalwart API keys](#stalwart-emergency-api-key) |
| `mail/admin/*` (other) | Stalwart admin account login | `pass` | On suspicion | Stalwart admin UI or API |
| `mail/julian/app` | Mail client app password | `pass` | Scheduled, 365 days | Mint a new app password in Stalwart, update the client, revoke the old one |
| `nc/backup` | Nextcloud AIO Borg repository passphrase | `pass` | On suspicion | Nextcloud AIO interface; take a fresh backup afterwards |
| `nc/passphrase` | Nextcloud AIO interface login | `pass` | On suspicion | Nextcloud AIO interface |
| `docs/api` | Paperless API token | `pass` | On suspicion | Paperless profile page, regenerate token |
| `github/recovery-codes` | Account recovery codes | `pass` | After use, or on suspicion | Regenerate in GitHub settings |
| `ssh/id_ed25519` | SSH private key passphrase | `pass` | On suspicion | `ssh-keygen -p` |
| `hosts/*/sudo` | Host sudo password | `pass` | On suspicion | `passwd` on the host |
| `network/fritzbox/admin` | Router admin login | `pass` | On suspicion | FRITZ!Box UI |
| Laptop disk encryption | LUKS passphrase | Memory + paper | On suspicion | `cryptsetup luksAddKey`, test a boot, then `luksKillSlot` the old slot |
| Laptop login | Account password | Memory + paper | On suspicion | `passwd` |
| GPG key | Key passphrase | Memory + paper | On suspicion | `gpg --change-passphrase`, then refresh the offline media |
| Offline backup media | LUKS passphrase | Memory + paper | On suspicion | `cryptsetup luksChangeKey` on each medium |
| Password manager | Master password | Memory + paper | On suspicion | In the password manager |

## Offline recovery drill

Once a year (`drill:offline-recovery` in the schedule): restore GPG,
`pass` and `~/.ssh` from one offline medium on a machine other than the
operator laptop, decrypt one `pass` entry, and check the paper copies
are still readable. The restore steps are on the medium itself.

## Stalwart emergency API key

Stalwart holds exactly two API keys: `emergency` (`mail/admin/api`) and
`terraform` ([`k3s-apps/stalwart`](k3s-apps/stalwart.md)). To rotate
`emergency`: mint a new key with `x:ApiKey/set` (`create`), authenticated
with the current one; store it with `pass insert -f mail/admin/api`;
check it with `x:ApiKey/get`; then destroy the old key's id with the new
key. API details:
[`stalwart-mail-server.md`](https://github.com/KandlerLi/home-infra-docs/blob/main/docs/runbooks/stalwart-mail-server.md).

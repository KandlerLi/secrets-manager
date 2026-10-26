# Secret: `fritzbox/terraform`

**Terraform resource**: `aws_secretsmanager_secret.this["fritzbox/terraform"]`
in the root `main.tf`, container only; the value is set out-of-band with
`aws secretsmanager put-secret-value` (never in Terraform).

**Consumed by**: `KandlerLi/fritzbox` (private repo, local apply only),
whose `terraform-provider-fritzbox` reads `FRITZBOX_USERNAME` /
`FRITZBOX_PASSWORD`. Its README fetches the password from here, one key at
a time, into the environment of the shell running `terraform`. `julian`
reads it via `bootstrap/terraform-state`'s `operator.tf`.

## Keys

### `username` / `password`
A dedicated FRITZ!Box user (*System → FRITZ!Box Users*) with only the
**FRITZ!Box Settings** permission and no access from the internet, made
for Terraform so it no longer logs in as the box's auto-generated admin
user. TR-064 needs "Allow access for applications" enabled on the box.

## Rotating

1. In the FRITZ!Box UI, set a new password on that user.
2. Write it here without it ever appearing on a command line:
   ```bash
   read -rs "P?new password: "; echo
   aws secretsmanager get-secret-value --secret-id fritzbox/terraform \
     --query SecretString --output text \
     | P="$P" jq -c '.password = env.P' \
     | aws secretsmanager put-secret-value --secret-id fritzbox/terraform \
       --secret-string file:///dev/stdin --query VersionId --output text; unset P
   ```
3. `terraform plan` in `KandlerLi/fritzbox` must authenticate and show no
   changes.
4. `scripts/manage-rotation-schedule.sh` to record it.

No platform-enforced expiry; the yearly interval is self-imposed hygiene.

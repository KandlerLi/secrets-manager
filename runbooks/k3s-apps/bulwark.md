# Secret: `k3s-apps/bulwark`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/bulwark"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. A genuinely new secret, not a migration.

**Consumed by**: `infra/k3s-apps`' `modules/bulwark`, read via
`secrets.tf`.

## Keys

### `authelia_oidc_bulwark_client_secret`
The only key in this group. Plaintext half of Bulwark's OIDC client
secret pair -- Authelia holds the matching hash (`home-infra/authelia`'s
`authelia_oidc_bulwark_client_secret_hash`). Never rotate this alone.

**Rotation**: generate a fresh plaintext + hash together (see
`home-infra/authelia.md`'s own note for the exact command), then
`infra/k3s-apps/scripts/rotate-oidc-client-secret.sh bulwark` -- prompts
silently for each value, rejects an obviously-swapped pair, writes both
secrets, and runs `terraform apply` (rolls Authelia and Bulwark
together, in sync). Verify for real afterward (browser OIDC flow, can't
be checked automatically): sign out, "Sign in with Authelia" must reach
a real login/consent screen and land back in Bulwark authenticated.

## Bootstrapping the first value

This container starts empty. Generate the first plaintext/hash pair the
same way as a rotation (see above), then seed it directly:

```bash
aws secretsmanager put-secret-value --secret-id k3s-apps/bulwark \
  --secret-string '{"authelia_oidc_bulwark_client_secret":"<plaintext>"}'
```

`home-infra/authelia`'s own `authelia_oidc_bulwark_client_secret_hash`
key needs seeding the same way, merged into that group's existing JSON
(never overwrite the whole blob -- see `home-infra/authelia.md`).

## Automated rotation

Same as every OIDC pair (see `home-infra/grafana`'s own README) --
structurally resistant, needs a coordinated update with
`home-infra/authelia` plus a Terraform apply. The helper script above is
a manual-trigger convenience, not automation.

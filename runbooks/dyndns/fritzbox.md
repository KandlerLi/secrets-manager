# Secret: `dyndns/fritzbox`

**Terraform resource**:
`aws_secretsmanager_secret.this["dyndns/fritzbox"]`, defined in the root
`main.tf` (`aws/secrets-manager`) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. Migrated here from `aws/dyndns` 2026-09-12 —
container only, no value. The only secret in this repo whose source
root is a real CI/PR-gated repo rather than a bootstrap-category one;
the "source relinquishes" half of the migration went through a normal
`aws/dyndns` PR ([#26](https://github.com/KandlerLi/dyndns/pull/26)),
not a direct local apply.

**Consumed by**: `aws/dyndns`'s own Lambda (`lambda/handler.py`), which
reads this secret directly (`secretsmanager:GetSecretValue`, a
wildcard ARN grant on the Lambda's own IAM role since the migration —
previously a direct resource reference) to validate the FRITZ!Box
router's HTTP Basic Auth credentials on every DynDNS update request.
**Warm Lambda instances cache the value for 5 minutes** — a rotation
can take up to 5 minutes to actually take effect, not instant like a
`terraform apply` completing.

## Keys

### `username` / `password`
Not an AWS credential — a plain HTTP Basic Auth pair the FRITZ!Box
router itself sends on every DynDNS update call. The router has to be
reconfigured with the new values at the same time the secret is
rotated (Internet → Permit Access → DynDNS in the router's own admin
UI) — until both match, the router's real update calls fail with
`401`/`badauth`, silently breaking DynDNS updates until the WAN IP
next needs to change (low urgency, but a real outage-in-waiting).

**Rotation**: generate a new random username/password pair (avoid `:`,
`@`, `/` — the credentials are inserted into the URL authority by the
FRITZ!Box), `put-secret-value`, reconfigure the router with the exact
same values, then verify for real: a direct HTTP request to the
Lambda's own update endpoint with the new credentials and the DNS
record's *current* real IP (an UPSERT to the same value is a safe
no-op, not a real change) should return `good <ip>`, not `badauth` —
allow up to 5 minutes for a still-warm Lambda instance's own
credential cache to expire first if an immediate attempt returns
`badauth` with values you're sure are correct.

## Automated rotation

Not a good fit — the router itself needs manual reconfiguration on
every rotation regardless of how the AWS side is automated, so there's
no unattended path end to end.

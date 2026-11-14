# Secret: `k3s-apps/stalwart`

**Terraform resource**:
`aws_secretsmanager_secret.this["k3s-apps/stalwart"]`, defined in the root
`main.tf` ([`secrets-manager`](https://github.com/KandlerLi/secrets-manager)) alongside every other secret's own
container -- a single `for_each` resource, not a per-secret module. A genuinely new secret, not a
migration.

**Consumed by**: [`stalwart-config`](https://github.com/KandlerLi/stalwart-config)'s Stalwart Terraform provider
(`secrets.tf` -> `local.stalwart`), which manages Stalwart's settings as
code; its CI roles may read this group and nothing else in Secrets
Manager. (Until k3s-apps' CI cleanup, k3s-apps still reads the token too.)

## Keys

### `stalwart_api_token`
An **API key on Stalwart's `admin` account**, created just for
Terraform (one of the account's max 5 keys). It authenticates as a
Bearer token against the management API (`POST /jmap/`, see
[`home-infra-docs/docs/runbooks/stalwart-mail-server.md`](https://github.com/KandlerLi/home-infra-docs/blob/main/docs/runbooks/stalwart-mail-server.md)). It works
regardless of the server's Authentication Directory setting, which is
the whole reason it's the right credential here.

It carries the admin account's full permissions -- treat it like a root
credential for the mail server.

**Bootstrapping / rotating** -- mint the key through the API, then merge
it into this secret without printing it:

```zsh
# with a port-forward to Stalwart (svc/stalwart-internal 18083:8080)
apikey=$(pass show mail/admin/api)
resp=$(curl -s -X POST http://127.0.0.1:18083/jmap/ \
  -H "Authorization: Bearer $apikey" -H 'Content-Type: application/json' \
  -d '{"using":["urn:ietf:params:jmap:core","urn:stalwart:jmap"],"methodCalls":[["x:ApiKey/set",{"create":{"new1":{"allowedIps":{},"description":"terraform","permissions":{"@type":"Inherit"}}}},"c1"]]}')
token=$(printf '%s' "$resp" | python3 -c 'import sys,json
d=json.load(sys.stdin); r=d["methodResponses"][0][1]; c=r.get("created",{}).get("new1")
if not c: sys.stderr.write("FAILED: %s\n" % (r.get("notCreated") or d)); sys.exit(1)
sys.stderr.write("created id: %s\n" % c.get("id"))
print(c["secret"])')
umask 077; T=$(mktemp)
aws secretsmanager get-secret-value --region eu-central-1 --secret-id k3s-apps/stalwart \
  --query SecretString --output text | jq --arg v "$token" '.stalwart_api_token = $v' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 --secret-id k3s-apps/stalwart \
  --secret-string "file://$T"
rm -f "$T"; unset apikey resp token
```

The merge keeps `ses_smtp_username` (below); never write this group
from scratch.

To **rotate**: repeat (a new key), confirm stalwart-config's CI still
plans cleanly, then destroy the old key with `x:ApiKey/set` and
`{"destroy":["<old id>"]}`. Stalwart shows a key's secret exactly once,
at creation.

### `ses_smtp_username`
The SES SMTP username of Stalwart's relay route (`stalwart_mta_route_relay`),
a copy of `home-infra/monitoring`'s `monitoring_ses_smtp_username`, so
stalwart-config's roles don't need that group, which also holds the SES
password. Not secret on its own, but kept here with the credential it
belongs to. **Rotate it together with the SES credential**: after
`home-infra/monitoring` changes, copy it over again. Copy, without
printing it:

```zsh
umask 077; T=$(mktemp)
U=$(aws secretsmanager get-secret-value --region eu-central-1 --secret-id home-infra/monitoring \
  --query SecretString --output text | jq -r .monitoring_ses_smtp_username)
aws secretsmanager get-secret-value --region eu-central-1 --secret-id k3s-apps/stalwart \
  --query SecretString --output text | jq --arg v "$U" '.ses_smtp_username = $v' > "$T"
aws secretsmanager put-secret-value --region eu-central-1 --secret-id k3s-apps/stalwart \
  --secret-string "file://$T"
rm -f "$T"; unset U
```

## Automated rotation

Not automatable unattended: minting needs the existing admin credential,
and Terraform consumes the result. Manual, on the schedule in
`rotation-schedule.json`.

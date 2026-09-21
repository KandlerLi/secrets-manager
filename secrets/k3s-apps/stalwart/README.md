# Secret: `k3s-apps/stalwart`

**Terraform resource**:
`module.k3s_apps_stalwart.aws_secretsmanager_secret.this`, defined in
`./main.tf` alongside this file. A genuinely new secret, not a
migration.

**Consumed by**: `infra/k3s-apps`' Stalwart Terraform provider
(`secrets.tf` -> `local.k3s_apps_stalwart`), which manages Stalwart's
settings as code.

## Keys

### `stalwart_api_token`
An **API key on Stalwart's `admin` account**, created just for
Terraform (one of the account's max 5 keys). It authenticates as a
Bearer token against the management API (`POST /jmap/`, see
`docs/home-infra-docs/docs/runbooks/stalwart-mail-server.md`). It works
regardless of the server's Authentication Directory setting, which is
the whole reason it's the right credential here.

It carries the admin account's full permissions -- treat it like a root
credential for the mail server.

**Bootstrapping / rotating** -- mint the key through the API, then merge
it into this secret without printing it:

```bash
# with a port-forward to Stalwart (svc/stalwart-internal 18083:8080)
apikey=$(pass show mail/admin/api)
resp=$(curl -s -X POST http://127.0.0.1:18083/jmap/ \
  -H "Authorization: Bearer $apikey" -H 'Content-Type: application/json' \
  -d '{"using":["urn:ietf:params:jmap:core","urn:stalwart:jmap"],"methodCalls":[["x:ApiKey/set",{"create":{"new1":{"allowedIps":{},"description":"terraform","permissions":{"@type":"Inherit"}}}},"c1"]]}')
printf '%s' "$resp" | python3 -c 'import sys,json
d=json.load(sys.stdin); r=d["methodResponses"][0][1]; c=r.get("created",{}).get("new1")
if not c: sys.stderr.write("FAILED: %s\n" % (r.get("notCreated") or d)); sys.exit(1)
sys.stderr.write("created id: %s\n" % c.get("id"))
print(json.dumps({"stalwart_api_token": c["secret"]}))' > /tmp/stalwart-token.json
aws secretsmanager put-secret-value --secret-id k3s-apps/stalwart \
  --region eu-central-1 --secret-string file:///tmp/stalwart-token.json
rm /tmp/stalwart-token.json; unset apikey resp
```

To **rotate**: repeat (a new key), apply, confirm Terraform still
plans cleanly, then destroy the old key with `x:ApiKey/set` and
`{"destroy":["<old id>"]}`. Stalwart shows a key's secret exactly once,
at creation.

## Automated rotation

Not automatable unattended: minting needs the existing admin credential,
and Terraform consumes the result. Manual, on the schedule in
`rotation-schedule.json`.

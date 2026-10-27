# Secret: `home-infra/prometheus`

**Terraform resource**:
`aws_secretsmanager_secret.this["home-infra/prometheus"]` in the root
`main.tf`, container only; values are set out of band with
`aws secretsmanager put-secret-value` (never in Terraform). Created
2026-10-27.

**Consumed by**: [`home-infra`](https://github.com/KandlerLi/home-infra)'s Ansible only (`ansible/playbooks/site.yml`'s
`pre_tasks`), which writes each key into a `0400` file for the
homeserver's Prometheus or the GitHub runner exporter. Kept apart from
`home-infra/monitoring` on purpose: [`k3s-apps`](https://github.com/KandlerLi/k3s-apps) reads that whole group,
and neither token here is any of its business.

The container starts empty. Once, before the first copy below:
```bash
aws secretsmanager put-secret-value --region eu-central-1 --secret-id home-infra/prometheus \
  --secret-string '{}' --query VersionId --output text
```

Every write below merges one key into the current value, so the other
key stays. After any of them, run `site.yml`; both services reread
their token file on every request, so nothing needs restarting.

## Keys

### `monitoring_k3s_kubelet_token`
ServiceAccount token (`prometheus-kubelet`, `get` on `nodes/metrics`
only) for scraping each kubelet's `/metrics/cadvisor`. Made by
[`k3s-bootstrap`](https://github.com/KandlerLi/k3s-bootstrap)'s `kubelet_metrics_rbac.tf`.

Copy it in, with the kubectl tunnel open and `aws login` done. The
token never reaches the screen or argv:
```bash
T="$(kubectl get secret prometheus-kubelet-token -o jsonpath='{.data.token}' | base64 -d)"
aws secretsmanager get-secret-value --region eu-central-1 --secret-id home-infra/prometheus \
  --query SecretString --output text \
  | T="$T" jq -c '.monitoring_k3s_kubelet_token = env.T' \
  | aws secretsmanager put-secret-value --region eu-central-1 --secret-id home-infra/prometheus \
    --secret-string file:///dev/stdin --query VersionId --output text; unset T
```
Check: the `k3s_kubelet_cadvisor` targets in Prometheus are `up`.

**Rotating**: in `k3s-bootstrap`, `scripts/roll-out.sh apply
-replace=kubernetes_secret_v1.prometheus_kubelet_token` (the old token
dies with the Secret), then the copy above and `site.yml`. The scrape
fails with 401 in between.

### `monitoring_github_runner_exporter_token`
Fine-grained personal access token the GitHub runner exporter reads
runner status and queued runs with. Create it under *Settings →
Developer settings → Fine-grained tokens*:

- Resource owner `KandlerLi`, expiration 1 year.
- *Only select repositories*: exactly the repos with `runner: true` in
  [`repo-infra`](https://github.com/KandlerLi/repo-infra)'s `config.yml`.
- Repository permissions: **Administration: Read-only** (the runner
  list) and **Actions: Read-only** (queued runs). Nothing else.

Write it without it ever appearing on a command line:
```bash
read -rs 'P?token: '; echo
aws secretsmanager get-secret-value --region eu-central-1 --secret-id home-infra/prometheus \
  --query SecretString --output text \
  | P="$P" jq -c '.monitoring_github_runner_exporter_token = env.P' \
  | aws secretsmanager put-secret-value --region eu-central-1 --secret-id home-infra/prometheus \
    --secret-string file:///dev/stdin --query VersionId --output text; unset P
```
Check: `github_runner_exporter_up` is 1 for every repo.

**Rotating**: GitHub mails before the expiry. *Regenerate token* on the
same token (keeps its scope), the write above, `site.yml`,
`scripts/manage-rotation-schedule.sh`. A new runner repo also has to be
added to the token's repository list, or its `github_runner_exporter_up`
stays 0.

## Automated rotation

Neither. The kubelet token has no expiry and a Terraform `-replace`
rotates it; a fine-grained PAT can't be created or regenerated through
the API.

# Secret: `renovate/github-app`

**Terraform resource**:
`aws_secretsmanager_secret.this["renovate/github-app"]` in the root
`main.tf`, container only; values are set out of band with
`aws secretsmanager put-secret-value` (never in Terraform). Created
2026-10-28.

**Consumed by**: [`renovate`](https://github.com/KandlerLi/renovate)'s scheduled
workflow, which reads it at run time through its apply role (AWS OIDC,
`environment: production`) and mints a short-lived installation token
with `actions/create-github-app-token`. No GitHub Actions secret holds
it. An App token, not `GITHUB_TOKEN`: PRs opened with `GITHUB_TOKEN`
don't trigger the target repo's CI.

## Keys

### `app_id`
The App's numeric ID, from its settings page. Not secret, kept here so
the workflow needs one lookup.

### `app_private_key`
The App's private key, PEM, as downloaded from GitHub.

## Creating the App (once)

*Settings → Developer settings → GitHub Apps → New GitHub App*:

- Name `kandlerli-renovate`, homepage
  `https://github.com/KandlerLi/renovate`, webhook **off**.
- Repository permissions: **Contents**, **Pull requests**,
  **Workflows**, **Issues** and **Commit statuses**: Read and write;
  **Checks**: Read-only (Metadata is implied). Nothing at organisation
  or account level.
- "Only on this account".

Then *Credentials → Key pairs → New key*; the `.pem` downloads (GitHub
allows installing only after that). Then *Install App* → *Only select
repositories*: the repos listed in `renovate`'s `config.js` (`slots`).
The App ID is under *General*.

Write both keys, with `aws login` done. The key goes from the file,
never through argv or the screen:
```bash
printf 'App ID: '; read -r APP_ID   # read -p means something else in zsh
jq -n --arg id "$APP_ID" --rawfile key ~/Downloads/kandlerli-renovate.*.private-key.pem \
  '{app_id: $id, app_private_key: $key}' \
  | aws secretsmanager put-secret-value --region eu-central-1 --secret-id renovate/github-app \
    --secret-string file:///dev/stdin --query VersionId --output text
rm ~/Downloads/kandlerli-renovate.*.private-key.pem
```
Check: start `renovate`'s workflow by hand (*Actions → Renovate → Run
workflow*); the "Mint App token" step succeeds.

## Rotating

Create a new key under *Credentials → Key pairs*, write it in as above
(same `app_id`), run the workflow once to check, then delete the old key
there. Nothing else changes.

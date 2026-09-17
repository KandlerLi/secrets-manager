#!/usr/bin/env bash
# Reads rotation-schedule.json (this repo's own root -- see its own
# "_comment" and README.md's Rotation section) and emails a reminder
# for any secret within warn_days of its recorded last_rotated +
# rotate_every_days deadline. Built to run from this repo's own
# scheduled GitHub Actions workflow (check-secret-rotation.yml) --
# needs an AWS session with ses:SendEmail on the jkandler.de identity
# (that workflow's own OIDC role assumption covers this) and jq on
# PATH (installed by the calling workflow -- not baked into the runner
# image itself, same "install exactly what this one workflow needs"
# precedent infra/k3s-apps' own rotate-blocky-postgres-password.sh
# already uses for psql).
#
# Never rotates anything itself -- this is a reminder, not automated
# rotation (see docs/home-infra-docs/docs/runbooks/rotate-secrets.md's
# own "Automated rotation" section for why: every credential here
# needs either a human-known plaintext, an external system's own UI,
# or a blast radius that makes unattended rotation actively harmful).

set -euo pipefail

region="eu-central-1"
schedule_file="rotation-schedule.json"
warn_days=7
from_address="alerts@jkandler.de"
to_address="julian.kandler@outlook.com"

fail() {
  echo "check-secret-rotation: $1" >&2
  exit 1
}

command -v aws >/dev/null || fail "aws not found"
command -v jq >/dev/null || fail "jq not found"
[ -f "${schedule_file}" ] || fail "${schedule_file} not found"

runbook_url="$(jq -r '.runbook_url' "${schedule_file}")"
[ -n "${runbook_url}" ] && [ "${runbook_url}" != "null" ] || fail "${schedule_file} has no runbook_url"

today_epoch="$(date -u +%s)"
due_lines=()

count="$(jq '.secrets | length' "${schedule_file}")"
for i in $(seq 0 $((count - 1))); do
  entry="$(jq -c ".secrets[${i}]" "${schedule_file}")"
  id="$(echo "${entry}" | jq -r '.id')"
  description="$(echo "${entry}" | jq -r '.description')"
  last_rotated="$(echo "${entry}" | jq -r '.last_rotated')"
  interval="$(echo "${entry}" | jq -r '.rotate_every_days')"

  expiry_epoch="$(date -u -d "${last_rotated} +${interval} days" +%s)" \
    || fail "${id}: invalid last_rotated/rotate_every_days"
  days_left=$(( (expiry_epoch - today_epoch) / 86400 ))

  echo "==> ${id}: ${days_left} day(s) until its recorded rotation deadline"
  if [ "${days_left}" -le "${warn_days}" ]; then
    due_lines+=("- ${id} (${days_left}d left): ${description}")
  fi
done

if [ ${#due_lines[@]} -eq 0 ]; then
  echo "==> nothing due within ${warn_days} days, no email sent"
  exit 0
fi

echo "==> due for rotation:"
printf '%s\n' "${due_lines[@]}"

tmp_message=""
cleanup() {
  [ -n "${tmp_message}" ] && rm -f "${tmp_message}"
}
trap cleanup EXIT INT TERM

tmp_message="$(mktemp)"
body="$(printf 'The following aws/secrets-manager entries are within %s days of their recorded rotation deadline (rotation-schedule.json):\n\n%s\n\nRotation procedure for each (find the category letter named in its own line above): %s\n\nAfter rotating, update last_rotated in rotation-schedule.json in the same change.\n' \
  "${warn_days}" "$(printf '%s\n' "${due_lines[@]}")" "${runbook_url}")"

jq -n --arg subject "Secret rotation reminder (${#due_lines[@]} due)" --arg body "${body}" \
  '{Subject: {Data: $subject}, Body: {Text: {Data: $body}}}' > "${tmp_message}"

aws ses send-email --region "${region}" \
  --from "${from_address}" \
  --destination "ToAddresses=${to_address}" \
  --message "file://${tmp_message}" \
  || fail "ses send-email failed"

echo "==> reminder email sent to ${to_address}"

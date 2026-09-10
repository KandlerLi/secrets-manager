#!/usr/bin/env bash
# Mimics what a real CI pipeline would do for this repo's own apply, run
# locally -- minus AWS credentials. Like bootstrap/terraform-state's own
# scripts/roll-out.sh (and unlike github/repo-infra's and
# bootstrap/k3s-bootstrap's), this one deliberately does NOT set up AWS
# credentials: this root grants julian its Secrets Manager access, so it
# stays applied only as root / an admin-equivalent identity via an
# interactive `aws login` (ADR 0018's principle). Run that yourself first.
#
#   scripts/roll-out.sh plan
#   scripts/roll-out.sh apply
#
# No required variables without defaults here, so nothing to export -- the
# script is just the plain terraform sequence.

set -euo pipefail

usage() {
  echo "usage: $(basename "$0") plan|apply" >&2
  exit 1
}

[ $# -eq 1 ] || usage
mode="$1"
case "$mode" in
  plan | apply) ;;
  *) usage ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "${script_dir}")"
cd "${repo_root}"

terraform init -input=false
terraform fmt -check -recursive
terraform validate
# -input=false on plan/apply too, not just init -- a missing/unexported
# required variable otherwise drops into a confusing interactive prompt
# instead of failing outright (see github/repo-infra's own roll-out.sh).
terraform plan -input=false

if [ "${mode}" = "apply" ]; then
  # Interactive on purpose -- terraform's own plan-and-confirm prompt is
  # the review step, not -auto-approve.
  terraform apply -input=false
fi

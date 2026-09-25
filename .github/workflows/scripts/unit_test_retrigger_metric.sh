#!/usr/bin/env bash
#
# Monthly re-trigger rate of the "Unit Tests" workflow on main. A run is flaky when its
# final run_attempt >= 2 and conclusion == success (re-run to green); still-failing
# re-runs are excluded. Push events only, completed only. Emits CSV to stdout:
# month,total_runs,retriggered,retrigger_pct
#
# Usage: GH_TOKEN=$(gh auth token) unit_test_retrigger_metric.sh
#
set -euo pipefail

REPO="${REPO:-cloudfoundry/cloud_controller_ng}"
WORKFLOW_NAME="${WORKFLOW_NAME:-Unit Tests}"

# jq picks the first match, avoiding a head(1) that would SIGPIPE under pipefail.
workflow_id="$(gh api --paginate "repos/${REPO}/actions/workflows" \
  --jq "[.workflows[] | select(.name == \"${WORKFLOW_NAME}\") | .id] | first")"

if [ -z "${workflow_id}" ] || [ "${workflow_id}" = "null" ]; then
  echo "error: workflow '${WORKFLOW_NAME}' not found in ${REPO}" >&2
  exit 1
fi

{
  echo "month,total_runs,retriggered,retrigger_pct"
  gh api --paginate \
    "repos/${REPO}/actions/workflows/${workflow_id}/runs?event=push&per_page=100" \
    --jq '.workflow_runs[]
          | select(.status == "completed")
          | {month: .created_at[0:7],
             retrig: (if .run_attempt >= 2 and .conclusion == "success" then 1 else 0 end)}' \
  | jq -rs '
      group_by(.month)
      | map({month: .[0].month, total: length, retrig: (map(.retrig) | add)})
      | sort_by(.month)
      | .[]
      | [ .month,
          .total,
          .retrig,
          ((.retrig * 1000 / .total | round) / 10) ]
      | @csv'
} | sed 's/"//g'

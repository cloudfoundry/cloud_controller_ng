#!/usr/bin/env bash
#
# Monthly re-trigger rate of the "Unit Tests" workflow on main: share of runs that reached
# green only on a re-run (final run_attempt >= 2 and conclusion == success). Still-failing
# re-runs are excluded. Push events only, current month excluded. Emits CSV to stdout:
# month,total_runs,retriggered,retrigger_pct
#
# Months are fetched one bounded range at a time (see gh_runs_lib.sh). START defaults to the
# oldest month still retained; override for a shorter window.
#
# Usage: GH_TOKEN=$(gh auth token) unit_test_retrigger_metric.sh
#
set -euo pipefail

REPO="${REPO:-cloudfoundry/cloud_controller_ng}"
WORKFLOW_NAME="${WORKFLOW_NAME:-Unit Tests}"
START="${START:-2025-08}"

. "$(dirname "$0")/gh_runs_lib.sh"

# jq picks the first match, avoiding a head(1) that would SIGPIPE under pipefail.
workflow_id="$(gh api --paginate "repos/${REPO}/actions/workflows" \
  --jq "[.workflows[] | select(.name == \"${WORKFLOW_NAME}\") | .id] | first")"

if [ -z "${workflow_id}" ] || [ "${workflow_id}" = "null" ]; then
  echo "error: workflow '${WORKFLOW_NAME}' not found in ${REPO}" >&2
  exit 1
fi

# Last completed month = the month before the current one.
end_month="$(date -u -v-1m +%Y-%m 2>/dev/null || date -u -d 'last month' +%Y-%m)"

{
  echo "month,total_runs,retriggered,retrigger_pct"
  for month in $(enum_months "${START}" "${end_month}"); do
    gh api --paginate \
      "repos/${REPO}/actions/workflows/${workflow_id}/runs?event=push&created=${month}-01..${month}-$(last_day "$month")&per_page=100" \
      --jq '.workflow_runs[]
            | select(.status == "completed")
            | [ .id,
                (if .run_attempt >= 2 and .conclusion == "success" then 1 else 0 end) ]
            | @tsv' \
    | sort -u \
    | awk -F'\t' -v m="${month}" '
        { total++; retrig += $2 }
        END {
          if (total > 0)
            printf "%s,%d,%d,%s\n", m, total, retrig,
                   (int(retrig * 1000 / total + 0.5) / 10);
        }'
  done
}

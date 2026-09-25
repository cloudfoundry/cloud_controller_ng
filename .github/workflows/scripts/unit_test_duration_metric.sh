#!/usr/bin/env bash
#
# Median (p50) duration of each "Unit Tests" job on main, per month. Green jobs only (a
# failed job's duration is meaningless), push events only, current month excluded. Series are
# discovered from the job name, so new DB versions self-register. Emits CSV to stdout:
# month,job,runs,p50_min
#
# Runs are fetched one bounded month at a time (see gh_runs_lib.sh) and each run's /jobs is
# fetched in turn. START defaults to 3 months back (self-heal margin); set START=YYYY-MM for
# a backfill.
#
# Usage: GH_TOKEN=$(gh auth token) unit_test_duration_metric.sh
#
set -euo pipefail

REPO="${REPO:-cloudfoundry/cloud_controller_ng}"
WORKFLOW_NAME="${WORKFLOW_NAME:-Unit Tests}"
START="${START:-$(date -u -v-3m +%Y-%m 2>/dev/null || date -u -d '3 months ago' +%Y-%m)}"

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

# Run ids per month, tagged with the month so jobs bucket by their run's month (not by job
# started_at, which can drift across a boundary).
run_pairs() {
  local month
  for month in $(enum_months "${START}" "${end_month}"); do
    run_ids_for_month "${workflow_id}" "${month}" \
      | awk -v m="${month}" 'NF {print m "\t" $0}'
  done
}

pairs="$(run_pairs)"
run_total="$(printf '%s\n' "${pairs}" | grep -c .)"

# Green jobs only, emitting job<TAB>seconds; awk prepends the month. A transient /jobs failure
# must not silently drop a run, so retry once then abort — a gap would corrupt the median.
JOBS_FILTER='.jobs[]
  | select(.conclusion == "success" and .started_at != null and .completed_at != null)
  | [ .name,
      ((.completed_at | sub("\\.[0-9]+";"") | fromdateiso8601)
       - (.started_at | sub("\\.[0-9]+";"") | fromdateiso8601)) ]
  | @tsv'
failed=0
durations() {
  local month rid
  while IFS=$'\t' read -r month rid; do
    [ -n "${rid}" ] || continue
    { gh api --paginate "repos/${REPO}/actions/runs/${rid}/jobs?per_page=100" --jq "${JOBS_FILTER}" \
        || gh api --paginate "repos/${REPO}/actions/runs/${rid}/jobs?per_page=100" --jq "${JOBS_FILTER}" \
        || { echo "warn: /jobs failed for run ${rid}" >&2; failed=$((failed + 1)); }
    } | awk -v m="${month}" -F'\t' 'NF {print m "\t" $0}'
  done <<< "${pairs}"
  if [ "${failed}" -gt 0 ]; then
    echo "error: ${failed}/${run_total} run(s) failed to fetch; aborting to avoid under-counting" >&2
    return 1
  fi
}

{
  echo "month,job,runs,p50_min"
  # Group by (month, job); p50 = element at index round((n-1)*0.5) of the sorted durations.
  durations \
  | sort -t$'\t' -k1,1 -k2,2 -k3,3n \
  | awk -F'\t' '
      function flush(  i) {
        if (key == "") return;
        i = int((cnt - 1) * 0.5 + 0.5);
        printf "%s,%s,%d,%.1f\n", month, job, cnt, vals[i] / 60;
      }
      {
        if ($1 SUBSEP $2 != key) { flush(); key = $1 SUBSEP $2; month = $1; job = $2; cnt = 0; delete vals; }
        vals[cnt++] = $3;
      }
      END { flush() }'
}

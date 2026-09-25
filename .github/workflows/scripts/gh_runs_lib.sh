#!/usr/bin/env bash
#
# Shared helpers for the unit-test report scripts. The runs list paginates unstably on a busy
# repo (open-ended fetches duplicate and drop runs), so we fetch one bounded month at a time
# and dedupe client-side. Source this; do not execute.

# enum_months START END -> YYYY-MM for each month in [START, END] inclusive. Endpoints are
# encoded as month indices (year*12 + month-1) so one counter spans years. 10# forces base
# 10, else "08"/"09" parse as invalid octal.
enum_months() {
  local s=$(( ${1%-*} * 12 + 10#${1#*-} - 1 ))
  local e=$(( ${2%-*} * 12 + 10#${2#*-} - 1 ))
  local i
  for (( i = s; i <= e; i++ )); do
    printf '%04d-%02d\n' $(( i / 12 )) $(( i % 12 + 1 ))
  done
}

# last_day YYYY-MM -> last calendar day (28..31): first of next month minus one day. BSD
# then GNU date.
last_day() {
  date -j -v+1m -v-1d -f %Y-%m-%d "${1}-01" +%d 2>/dev/null \
    || date -d "${1}-01 +1 month -1 day" +%d
}

# run_ids_for_month WORKFLOW_ID MONTH -> deduped completed push run ids created in MONTH. The
# upper bound must be the real last day; an invalid date (2025-09-31) returns zero runs.
run_ids_for_month() {
  local wf="$1" month="$2"
  gh api --paginate \
    "repos/${REPO}/actions/workflows/${wf}/runs?event=push&created=${month}-01..${month}-$(last_day "$month")&per_page=100" \
    --jq '.workflow_runs[] | select(.status == "completed") | .id' \
  | sort -u
}

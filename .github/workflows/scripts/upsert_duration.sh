#!/usr/bin/env bash
#
# Upsert fresh rows into the stored CSV, keyed by (month, job). Fresh wins only when its run
# count is >= stored's, so a partial refetch never clobbers a complete month; rows absent
# from fresh are preserved. Written back to <stored>, sorted by month then job.
# Usage: upsert_duration.sh <stored-csv> <fresh-csv>
#
set -euo pipefail

HEADER="month,job,runs,p50_min"
STORED="${1:?usage: upsert_duration.sh <stored-csv> <fresh-csv>}"
FRESH="${2:?usage: upsert_duration.sh <stored-csv> <fresh-csv>}"

[ -f "${STORED}" ] || printf '%s\n' "${HEADER}" > "${STORED}"

{
  printf '%s\n' "${HEADER}"
  awk -F, '
    FNR==1 { next }
    { k = $1 SUBSEP $2 }
    NR==FNR { row[k]=$0; runs[k]=$3; next }
    (k in row) && $3 < runs[k] { next }
    { row[k]=$0 }
    END { for (k in row) print row[k] }
  ' "${STORED}" "${FRESH}" | sort -t, -k1,1 -k2,2
} > "${STORED}.new"

mv "${STORED}.new" "${STORED}"

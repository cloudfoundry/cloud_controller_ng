#!/usr/bin/env bash
#
# Upsert fresh rows into the stored CSV, keyed by month. Fresh wins only when its run count
# is >= stored's, so a partial refetch never clobbers a complete month; months absent from
# fresh are preserved. Written back to <stored>, sorted by month.
# Usage: upsert_retrigger.sh <stored-csv> <fresh-csv>
#
set -euo pipefail

HEADER="month,total_runs,retriggered,retrigger_pct"
STORED="${1:?usage: upsert_retrigger.sh <stored-csv> <fresh-csv>}"
FRESH="${2:?usage: upsert_retrigger.sh <stored-csv> <fresh-csv>}"

[ -f "${STORED}" ] || printf '%s\n' "${HEADER}" > "${STORED}"

{
  printf '%s\n' "${HEADER}"
  awk -F, '
    FNR==1 { next }
    NR==FNR { row[$1]=$0; total[$1]=$2; next }
    ($1 in row) && $2 < total[$1] { next }
    { row[$1]=$0 }
    END { for (m in row) print row[m] }
  ' "${STORED}" "${FRESH}" | sort -t, -k1,1
} > "${STORED}.new"

mv "${STORED}.new" "${STORED}"

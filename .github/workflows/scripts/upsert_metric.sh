#!/usr/bin/env bash
#
# Upsert fresh metric rows into the stored CSV, keyed by month. Fresh wins only when its
# run count is >= stored's, so a partially-aged-out month never overwrites a complete one;
# aged-out months (absent from fresh) are preserved. Result written back to <stored>.
# Usage: upsert_metric.sh <stored-csv> <fresh-csv>
#
set -euo pipefail

HEADER="month,total_runs,retriggered,retrigger_pct"
STORED="${1:?usage: upsert_metric.sh <stored-csv> <fresh-csv>}"
FRESH="${2:?usage: upsert_metric.sh <stored-csv> <fresh-csv>}"

[ -f "${STORED}" ] || printf '%s\n' "${HEADER}" > "${STORED}"

awk -F, -v header="${HEADER}" '
  FNR==1 { next }
  NR==FNR { row[$1]=$0; total[$1]=$2; next }
  ($1 in row) && $2 < total[$1] { next }
  { row[$1]=$0 }
  END {
    print header;
    n=0; for (m in row) keys[n++]=m;
    for(i=0;i<n;i++)for(j=i+1;j<n;j++)if(keys[j]<keys[i]){t=keys[i];keys[i]=keys[j];keys[j]=t}
    for(i=0;i<n;i++) print row[keys[i]];
  }' "${STORED}" "${FRESH}" > "${STORED}.new"

mv "${STORED}.new" "${STORED}"

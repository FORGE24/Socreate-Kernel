#!/usr/bin/bash
# Log fastfetch snapshots while sibling workflow jobs are still running.
set -euo pipefail

INTERVAL="${MONITOR_INTERVAL:-30}"
JOB_NAME="${MONITOR_JOB_NAME:-monitor-fastfetch}"
LOG_FILE="${MONITOR_LOG:-/tmp/gha-monitor-fastfetch.log}"
RUN_ID="${GITHUB_RUN_ID:?GITHUB_RUN_ID required}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN required}"

api() {
    curl -fsSL -H "Authorization: bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "$@"
}

other_jobs_running() {
    api "https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100" \
        | python3 -c "
import json, sys
jobs = json.load(sys.stdin).get('jobs', [])
mine = ${JOB_NAME@Q}
active = {'queued', 'in_progress', 'waiting', 'pending'}
for job in jobs:
    if job.get('name') == mine:
        continue
    if job.get('status') in active:
        raise SystemExit(0)
raise SystemExit(1)
"
}

: >"$LOG_FILE"
echo "==> fastfetch monitor for run ${RUN_ID}" | tee -a "$LOG_FILE"

while true; do
    {
        echo ""
        echo "===== $(date -Is) ====="
        fastfetch --pipe false 2>/dev/null || fastfetch
    } | tee -a "$LOG_FILE"

    if ! other_jobs_running; then
        echo "==> All other jobs finished; stopping fastfetch monitor" | tee -a "$LOG_FILE"
        break
    fi
    sleep "$INTERVAL"
done

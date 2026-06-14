#!/usr/bin/bash
# Log CPU/memory/disk snapshots while sibling workflow jobs are still running.
set -euo pipefail

INTERVAL="${MONITOR_INTERVAL:-15}"
JOB_NAME="${MONITOR_JOB_NAME:-monitor-htop}"
LOG_FILE="${MONITOR_LOG:-/tmp/gha-monitor-htop.log}"
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

snapshot() {
    echo "===== $(date -Is) ====="
    echo "--- uptime / load ---"
    uptime
    echo "--- memory ---"
    free -h
    echo "--- disk ---"
    df -h / /tmp 2>/dev/null || df -h /
    echo "--- top CPU ---"
    ps aux --sort=-%cpu | head -20
    echo "--- top MEM ---"
    ps aux --sort=-%mem | head -20
    if command -v htop >/dev/null 2>&1; then
        echo "--- htop (batch) ---"
        htop -b -n 1 2>/dev/null | head -40 || true
    fi
}

: >"$LOG_FILE"
echo "==> htop monitor for run ${RUN_ID}" | tee -a "$LOG_FILE"

while true; do
    snapshot | tee -a "$LOG_FILE"
    if ! other_jobs_running; then
        echo "==> All other jobs finished; stopping htop monitor" | tee -a "$LOG_FILE"
        break
    fi
    sleep "$INTERVAL"
done

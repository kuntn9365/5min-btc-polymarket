#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
REPO="${BTC5M_REPO:-$WORKSPACE_ROOT/pm-hl-conservative-plus-repo}"
PY="$SCRIPT_DIR/run_btc_5m_threshold_test.py"  # compatibility wrapper -> canonical runner
LOG="$REPO/runtime/btc_5m_threshold_watch.log"
STATE="$REPO/runtime/btc_5m_threshold_watch.state"

THRESHOLD="${1:-0.75}"
STAKE="${2:-4}"
SLEEP_SEC="${3:-20}"
MAX_MIN="${4:-180}"

mkdir -p "$REPO/runtime"
start_ts=$(date +%s)
end_ts=$((start_ts + MAX_MIN*60))

echo "[$(date -u +%FT%TZ)] start watch threshold=$THRESHOLD stake=$STAKE sleep=$SLEEP_SEC max_min=$MAX_MIN" | tee -a "$LOG"

while true; do
  now=$(date +%s)
  if [ "$now" -ge "$end_ts" ]; then
    echo "[$(date -u +%FT%TZ)] timeout reached, stop" | tee -a "$LOG"
    exit 0
  fi

  out=$(cd "$REPO" && .venv/bin/python "$PY" --profile conservative --threshold "$THRESHOLD" --stake-usd "$STAKE" --entry-timeout-min 8 --poll-sec 2 --execute 2>&1 || true)
  echo "$out" >> "$LOG"

  # Canonical runner prints a final JSON report. It contains an "opened" block
  # only when a position was actually taken; a run with no trade ends with
  # result "no_entry_timeout" (no "opened" key). Stop the watcher as soon as a
  # trade was opened so we do not re-run the runner and open another position.
  if echo "$out" | grep -q '"opened":'; then
    echo "[$(date -u +%FT%TZ)] entry opened, stopping watcher" | tee -a "$LOG"
    echo "entered_at=$(date -u +%FT%TZ)" > "$STATE"
    exit 0
  fi

  sleep "$SLEEP_SEC"
done

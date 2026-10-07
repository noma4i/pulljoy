#!/bin/sh
# Renders the demo inbox's screens to PNGs in the given directory (default docs/).
# Fails if any screen didn't render.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-docs}"
mkdir -p "$OUT"
swift build

for pair in inbox:screenshot-light dark-compact:screenshot-dark settings:settings repositories:repositories; do
  state="${pair%%:*}"
  name="${pair##*:}"
  rm -f "$OUT/$name.png"
  PULLJOY_DEMO=1 PULLJOY_SNAPSHOT="$OUT/$name.png" PULLJOY_SNAPSHOT_STATE="$state" .build/debug/PullJoy &
  PID=$!
  ( sleep 60; kill $PID 2>/dev/null ) &
  WATCHDOG=$!
  STATUS=0
  wait $PID || STATUS=$?
  kill $WATCHDOG 2>/dev/null || true
  wait $WATCHDOG 2>/dev/null || true
  if [ "$STATUS" -ne 0 ] || [ ! -s "$OUT/$name.png" ]; then
    echo "snapshots: $state failed (exit $STATUS)" >&2
    exit 1
  fi
done
ls "$OUT"

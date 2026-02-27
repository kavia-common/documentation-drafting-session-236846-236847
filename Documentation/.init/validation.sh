#!/usr/bin/env bash
set -euo pipefail
# Validation script: build site, start dev server (setsid), health-check, capture artifacts, stop server
WS="/tmp/kavia/workspace/code-generation/documentation-drafting-session-236846-236847/Documentation"
cd "$WS"
# prerequisites
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 2; }
command -v pip3 >/dev/null 2>&1 || { echo "pip3 not found" >&2; exit 3; }
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 4; }
command -v mkdocs >/dev/null 2>&1 || true
# Build static site and capture build log
BUILD_LOG="$WS/.mkdocs_build.log"
mkdocs build -d site >"$BUILD_LOG" 2>&1 || { echo "mkdocs build failed; last 200 lines:" >&2; tail -n 200 "$BUILD_LOG" >&2; exit 10; }
[ -f "$WS/site/index.html" ] || { echo "build did not produce site/index.html" >&2; exit 11; }
# Record versions/status
PYVER=$(python3 --version 2>&1 | awk '{print $2}')
MKVER=$(python3 - <<'PY'
import importlib.util
spec=importlib.util.find_spec('mkdocs')
if spec is None:
    print('not-installed')
else:
    try:
        import mkdocs
        print(getattr(mkdocs,'__version__','unknown'))
    except Exception:
        print('installed-unknown')
PY
)
THEME=$(python3 - <<'PY'
import importlib.util
print('installed' if importlib.util.find_spec('mkdocs_material') else 'missing')
PY
)
# write evidence file (deterministic values)
echo "python=${PYVER}" > "$WS/.mkdocs_env"
echo "mkdocs=${MKVER}" >> "$WS/.mkdocs_env"
echo "mkdocs_material=${THEME}" >> "$WS/.mkdocs_env"
# Start dev server in new session so PGID is predictable
LOG="$WS/.mkdocs_validation.log"
setsid mkdocs serve --dev-addr=0.0.0.0:8000 >"$LOG" 2>&1 &
MKPID=$!
# allow time to start
sleep 0.5
PGID=$(ps -o pgid= -p "$MKPID" 2>/dev/null | tr -d ' ' || true)
# record PIDs
echo "$MKPID" > "$WS/.mkdocs_validation.pid"
echo "${PGID:-}" > "$WS/.mkdocs_validation.pgid"
# Health-check with retries and increasing backoff (max ~30s)
ATTEMPTS=0
MAX=30
SLEEP=1
URL="http://127.0.0.1:8000/"
while [ "$ATTEMPTS" -lt "$MAX" ]; do
  if curl --fail --silent --max-time 2 "$URL" >/dev/null 2>&1; then
    break
  fi
  sleep "$SLEEP"
  ATTEMPTS=$((ATTEMPTS+1))
  if [ "$SLEEP" -lt 5 ]; then SLEEP=$((SLEEP+1)); fi
done
if ! curl --fail --silent --max-time 2 "$URL" >/dev/null 2>&1; then
  echo "server did not respond; dumping last 200 lines of log:" >&2
  tail -n 200 "$LOG" >&2 || true
  # attempt cleanup
  if [ -n "$PGID" ]; then kill -TERM -"$PGID" >/dev/null 2>&1 || true; fi
  kill "$MKPID" >/dev/null 2>&1 || true
  wait "$MKPID" 2>/dev/null || true
  echo "VALIDATION_FAILED" >> "$WS/.mkdocs_env"
  exit 12
fi
# snapshot homepage and capture last logs for evidence
curl --fail --silent --show-error "$URL" -o "$WS/.mkdocs_home.html" || true
tail -n 200 "$LOG" > "$WS/.mkdocs_validation_last.log" || true
echo "SERVER_OK" >> "$WS/.mkdocs_env"
# clean shutdown: try PGID then PID
if [ -n "$PGID" ]; then
  kill -TERM -"$PGID" >/dev/null 2>&1 || true
fi
kill "$MKPID" >/dev/null 2>&1 || true
sleep 1
wait "$MKPID" 2>/dev/null || true
echo "VALIDATION_COMPLETE"

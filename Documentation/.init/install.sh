#!/usr/bin/env bash
set -euo pipefail
# Project dependencies installation (safe, explicit)
WS="/tmp/kavia/workspace/code-generation/documentation-drafting-session-236846-236847/Documentation"
cd "$WS"
# make sure workspace exists and writable
mkdir -p "$WS" && test -w "$WS"
# ensure user-local bin visible in-session
if [ -d "$HOME/.local/bin" ] && ! echo ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
  export PATH="$HOME/.local/bin:$PATH"
fi
# quick tool presence checks (fail fast if missing)
for cmd in python3 pip3 git curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "required command '$cmd' not found" >&2; exit 2; }
done

# helper to probe importable package
probe_pkg() {
  python3 - <<'PY'
import importlib.util, sys
name=sys.argv[1]
spec=importlib.util.find_spec(name)
if spec is None:
    print('not-installed')
else:
    try:
        mod=importlib.import_module(name)
        print(getattr(mod,'__version__','unknown'))
    except Exception:
        print('installed-unknown')
PY
  "${1}"
}

# install from requirements.txt if present (must succeed)
if [ -f "$WS/requirements.txt" ]; then
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    pip3 install --user --upgrade -r "$WS/requirements.txt"
    export PATH="$HOME/.local/bin:$PATH"
  else
    sudo -H pip3 install --upgrade -r "$WS/requirements.txt"
  fi
else
  # ensure mkdocs importable
  MKVER=$(probe_pkg mkdocs)
  if [ "$MKVER" = "not-installed" ]; then
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
      pip3 install --user --upgrade mkdocs
      export PATH="$HOME/.local/bin:$PATH"
    else
      sudo -H pip3 install --upgrade mkdocs
    fi
    MKVER=$(probe_pkg mkdocs)
  fi
  # optional theme: attempt install but do not fail on error
  THEME_BEFORE=$(python3 - <<'PY'
import importlib.util
print('installed' if importlib.util.find_spec('mkdocs_material') else 'missing')
PY
  )
  if [ "$THEME_BEFORE" = "missing" ]; then
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
      pip3 install --user --upgrade mkdocs-material || true
      export PATH="$HOME/.local/bin:$PATH"
    else
      sudo -H pip3 install --upgrade mkdocs-material || true
    fi
  fi
fi

# Final validation: mkdocs importable
MKVER_FINAL=$(probe_pkg mkdocs)
if [ "$MKVER_FINAL" = "not-installed" ]; then
  echo "mkdocs not importable after install" >&2
  exit 7
fi
# ensure 'mkdocs' console script present in-session
if ! command -v mkdocs >/dev/null 2>&1; then
  echo "mkdocs console script not on PATH after install" >&2
  exit 8
fi
THEME_FINAL=$(python3 - <<'PY'
import importlib.util
print('installed' if importlib.util.find_spec('mkdocs_material') else 'missing')
PY
)
# write canonical evidence
echo "python=$(python3 --version 2>&1 | awk '{print $2}')" > "$WS/.mkdocs_env"
echo "mkdocs=${MKVER_FINAL}" >> "$WS/.mkdocs_env"
echo "mkdocs_material=${THEME_FINAL}" >> "$WS/.mkdocs_env"
echo "DEPS_READY"

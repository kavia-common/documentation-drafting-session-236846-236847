#!/usr/bin/env bash
set -euo pipefail
WS="/tmp/kavia/workspace/code-generation/documentation-drafting-session-236846-236847/Documentation"
cd "$WS"
mkdocs build -d site > /tmp/mkdocs_build.log 2>&1 || { tail -n 200 /tmp/mkdocs_build.log >&2; echo "mkdocs build failed" >&2; exit 8; }
[ -f "$WS/site/index.html" ] || { echo "build did not produce index.html" >&2; exit 9; }
TITLE=$(grep -oP "(?i)(?<=<title>).*?(?=</title>)" "$WS/site/index.html" || true)
[ -n "$TITLE" ] || { echo "index.html missing <title>" >&2; exit 10; }
FILECOUNT=$(find "$WS/site" -type f | wc -l)
[ "$FILECOUNT" -gt 0 ] || { echo "site is empty" >&2; exit 11; }
# fragment anchor check (relaxed regex): find href="#frag" then look for id with single/double quotes and optional spaces
grep -Rho "href=\"#[^\"]*\"\|href=\'#[^\']*\'" "$WS/site" | sed -E "s/href=[\"']#([^\"']*)[\"']/\1/" | while read -r frag; do
  if ! grep -RInE "id\s*=\s*['\"]${frag}['\"]" "$WS/site" >/dev/null 2>&1; then
    echo "missing anchor id='${frag}' referenced" >&2
    exit 12
  fi
done || true
echo "TESTS_PASS"

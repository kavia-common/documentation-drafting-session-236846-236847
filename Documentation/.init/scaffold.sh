#!/usr/bin/env bash
set -euo pipefail
WS="/tmp/kavia/workspace/code-generation/documentation-drafting-session-236846-236847/Documentation"
mkdir -p "$WS/docs"
: > "$WS/docs/index.md"
cat > "$WS/docs/index.md" <<'MD'
# Home

Welcome to the documentation.

* [Usage](usage.md)
* [Configuration](configuration.md)
MD
: > "$WS/docs/usage.md"
cat > "$WS/docs/usage.md" <<'MD'
# Usage

Usage details.
MD
: > "$WS/docs/configuration.md"
cat > "$WS/docs/configuration.md" <<'MD'
# Configuration

Configuration details.
MD
if [ ! -f "$WS/mkdocs.yml" ]; then
cat > "$WS/mkdocs.yml" <<'YML'
site_name: Demo Docs
nav:
  - Home: index.md
  - Usage: usage.md
  - Configuration: configuration.md
YML
fi
chmod +x .init/test.sh

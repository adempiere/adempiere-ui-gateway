#!/usr/bin/env bash

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$HERE/generate_env.py"

TEMPLATE="$HERE/env_template.env"
OVERRIDE="${1:-$HERE/override.env}"
OUT="${2:-$HERE/.env}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found" >&2
  exit 1
fi

if [ ! -f "$PY" ]; then
  echo "generator not found: $PY" >&2
  exit 1
fi

python3 "$PY" "$TEMPLATE" "$OVERRIDE" "$OUT"

#!/usr/bin/env bash
# The skill lives once, at skills/audivo, where `npx skills add` finds it. A
# plugin cannot reach outside its own folder, so each plugin carries a copy;
# this script makes the copies, and with --check fails if any has drifted.
# Usage: scripts/sync-plugins.sh [--check]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/skills/audivo"
status=0
for plugin in "$ROOT"/plugins/*/; do
  target="${plugin}skills/audivo"
  if [ "${1:-}" = "--check" ]; then
    if ! diff -r "$SOURCE" "$target" >/dev/null 2>&1; then
      echo "drifted: ${target#"$ROOT"/} differs from skills/audivo; run scripts/sync-plugins.sh" >&2
      status=1
    fi
  else
    rm -rf "$target"
    mkdir -p "$(dirname "$target")"
    cp -R "$SOURCE" "$target"
    echo "synced ${target#"$ROOT"/}"
  fi
done
exit "$status"

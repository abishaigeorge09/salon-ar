#!/usr/bin/env bash
# Stop hook. The turn cannot end while the Definition of Done is red.
#
# Claude Code releases this after 8 consecutive blocks, so it is a strong gate
# rather than an infinite loop.
#
# Only fires when the working tree has changes: a conversational turn that
# touched nothing should not pay for a build.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || exit 0)" || exit 0

[ -x scripts/dod.sh ] || exit 0
git diff --quiet && git diff --cached --quiet && exit 0   # nothing changed

if ! out=$(./scripts/dod.sh --quick 2>&1); then
  {
    echo "Definition of Done is red, so this turn is not finished."
    echo
    printf '%s\n' "$out" | tail -40
  } >&2
  exit 2
fi
exit 0

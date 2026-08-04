#!/usr/bin/env bash
# ADR-006: keep the salon-mirror version a port rather than a rewrite.
#
# The render path must ask ViewpointProvider for the viewpoint and never read the AR
# camera transform directly. But SOMETHING has to read it once and hand it over, so a
# blanket ban is unimplementable and a blanket exemption is a loophole.
#
# The rule is therefore counted, not just pattern-matched: there is EXACTLY ONE place in
# the codebase that reads the camera transform, it is marked ADR-006-seam, and it feeds
# the provider. Two marked places is a failure, because that is the shape of the seam
# eroding one commit at a time — which is the specific way this decision gets lost.
#
# This check caught its own author: the first spike read frame.camera.transform in the
# ARSession delegate with no marker at all.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

[ -d Sources ] || { printf 'no sources yet\n'; exit 0; }

PAT='\.camera\.transform'
# Filesystem grep, not git grep: git grep searches the index and would ignore exactly the
# untracked file somebody is about to add.
ALL=$(grep -rnE "$PAT" Sources --include='*.swift' | grep -vE '^\s*[^:]*:[0-9]+:[[:space:]]*(//|///|\*)' || true)

[ -z "$ALL" ] && { printf 'no camera transform reads at all\n'; exit 0; }

MARKED=$(printf '%s\n' "$ALL" | grep -c 'ADR-006-seam' || true)
TOTAL=$(printf '%s\n' "$ALL" | grep -c . || true)

if [ "$TOTAL" -ne "$MARKED" ]; then
  printf '\033[31mADR-006: camera transform read outside the marked seam.\033[0m\n\n'
  printf '%s\n' "$ALL" | grep -v 'ADR-006-seam'
  printf '\nThe render path must go through ViewpointProvider. If this genuinely is the\n'
  printf 'one place that feeds the provider, mark it ADR-006-seam.\n'
  exit 1
fi

if [ "$MARKED" -gt 1 ]; then
  printf '\033[31mADR-006: %s places are marked ADR-006-seam. There must be exactly one.\033[0m\n\n' "$MARKED"
  printf '%s\n' "$ALL"
  printf '\nA second seam is how the mirror port turns back into a rewrite.\n'
  exit 1
fi

printf 'exactly one camera transform read, at the marked seam\n'

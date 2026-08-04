#!/usr/bin/env bash
# ADR-004: the hundredth style must cost one config row, not hours of hand work.
#
# The way that property dies is somebody hand-places one mesh under deadline. This runs
# from day one so the first orphan is caught, rather than the tenth.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

CONFIG=assets/styles.json
assets=$(git ls-files -- ':(glob)**/*.usdz' ':(glob)**/*.usda' ':(glob)**/*.obj' ':(glob)**/*.fbx' 2>/dev/null || true)

if [ -z "$assets" ]; then
  printf 'no style assets yet\n'; exit 0
fi

if [ ! -f "$CONFIG" ]; then
  printf '\033[31mStyle assets exist with no %s. Every asset must derive from a config row.\033[0m\n%s\n' "$CONFIG" "$assets"
  exit 1
fi

rc=0
while read -r a; do
  [ -z "$a" ] && continue
  name=$(basename "$a"); name="${name%.*}"
  if ! grep -q "\"$name\"" "$CONFIG"; then
    printf '\033[31morphan asset with no config row: %s\033[0m\n' "$a"; rc=1
  fi
done <<< "$assets"

[ $rc -eq 0 ] && printf 'every style asset derives from a config row\n'
exit $rc

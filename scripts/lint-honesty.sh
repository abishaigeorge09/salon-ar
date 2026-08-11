#!/usr/bin/env bash
# R-HONEST: the UI states plainly what the system cannot show.
#
# ADR-001 makes live mode additive-only. The category's universal habit is to hide that.
# Ours is to print it. This check exists so the disclosure cannot be quietly dropped in a
# redesign by someone who thinks it looks untidy, which is exactly how it would go.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

if ! git ls-files -- ':(glob)**/*.swift' 2>/dev/null | grep -q .; then
  printf 'no Swift sources yet; disclosure string not required until the live view exists\n'
  exit 0
fi

# Once a live camera view exists, the disclosure must exist with it — AS UI COPY, not as
# a comment about UI copy. An earlier version matched the doc comment "Live mode adds hair
# and cannot remove it", so deleting the actual on-screen sentence left the check green.
# The requirement is what the customer reads, so the check must look at string literals.
if gg_code 'ARView|ARSCNView|RealityView' -- ':(glob)Sources/**/*.swift' >/dev/null 2>&1; then
  if ! gg_code -i '"[^"]*(adds length|cannot remove|does not remove|cannot show it shorter)' \
       -- ':(glob)Sources/**/*.swift' ':(glob)**/*.strings' >/dev/null 2>&1; then
    printf '\033[31mR-HONEST violated: a live AR view exists with no additive-only disclosure\n'
    printf 'in any user-facing string.\033[0m\n'
    printf 'Live mode adds hair and cannot remove it. Say so on screen, not in a comment.\n'
    exit 1
  fi
fi
printf 'honesty disclosure present in UI copy, or not yet required\n'

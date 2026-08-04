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

# Once a live camera view exists, the disclosure must exist with it.
if git grep -lqP 'ARView|ARSCNView|RealityView' -- ':(glob)**/*.swift' 2>/dev/null; then
  if ! git grep -qiP 'adds length|cannot remove|does not remove' -- ':(glob)**/*.swift' ':(glob)**/*.strings' 2>/dev/null; then
    printf '\033[31mR-HONEST violated: a live AR view exists with no additive-only disclosure.\033[0m\n'
    printf 'Live mode adds hair and cannot remove it. Say so in the UI.\n'
    exit 1
  fi
fi
printf 'honesty disclosure present or not yet required\n'

#!/usr/bin/env bash
# R-NOJUDGE: the system shows, it never ranks.
#
# From the brief: "Do not build a system that tells someone a haircut does not suit their
# face. Automated judgement about people's appearance is a good way to make a customer
# feel bad in a chair they are paying to sit in."
#
# This check is blunt and will occasionally flag something innocent. That is the correct
# trade against a customer being told by a machine that their face is the wrong shape.
# When it fires on a genuine false positive, rename the thing. Do not weaken the list.
#
# Lenskart's glasses try-on ships exactly the pattern this forbids: it analyses your face
# and highlights "recommended for you" frames in green. The vocabulary below is theirs.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

BANNED='suits you|suits your|flatter|flattering|best for you|best for your|face shape|facial shape|match score|fit score|compatibility|recommended for you|ideal for you|works for your|right for your|not for you|unsuitable|rank(ed|ing)? by fit|score your'

TARGETS=(':(glob)**/*.swift' ':(glob)**/*.strings' ':(glob)**/*.stringsdict' ':(glob)**/*.json' ':(glob)**/*.plist')

hits=$(gg -i "$BANNED" -- "${TARGETS[@]}" 2>/dev/null || true)

if [ -n "$hits" ]; then
  printf '\033[31mR-NOJUDGE violated. The system shows, it never ranks.\033[0m\n\n%s\n\n' "$hits"
  printf 'If this is a false positive, rename it. Do not add an exception.\n'
  exit 1
fi

printf 'no judgement vocabulary found\n'

#!/usr/bin/env bash
# ADR-006: keep the mirror version a port rather than a rewrite.
#
# The render path must ask ViewpointProvider for the viewpoint and never read the AR
# camera transform directly. The seam erodes one commit at a time, so this tests the
# property rather than trusting the abstraction to be respected.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

if ! git ls-files -- ':(glob)**/*.swift' 2>/dev/null | grep -q .; then
  printf 'no Swift sources yet\n'; exit 0
fi

hits=$(gg '\b(session|arView)\.currentFrame\.camera\.transform|\bframe\.camera\.transform\b' \
       -- ':(glob)**/*.swift' ':(exclude)**/ViewpointProvider.swift' 2>/dev/null || true)

if [ -n "$hits" ]; then
  printf '\033[31mDirect AR camera transform read outside ViewpointProvider.\033[0m\n\n%s\n\n' "$hits"
  printf 'ADR-006: the mirror version diverges exactly here. Go through ViewpointProvider.\n'
  exit 1
fi
printf 'no direct camera transform reads\n'

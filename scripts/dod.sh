#!/usr/bin/env bash
# Definition of Done, as one executable. Swift / Xcode / iOS.
#
# The web template this replaces would have passed vacuously here: no package.json,
# no tsconfig, no Supabase. A script that reports green having run nothing is worse
# than no script, so this is stack-specific.
#
#   ./scripts/dod.sh          everything that applies
#   ./scripts/dod.sh --quick  skip build and device tests
#
# Design rule, inherited: a check that silently skips is worse than no check. Anything
# not run prints as SKIP with a reason, and a check that SHOULD have applied but could
# not run is a FAILURE, not a skip.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

FAILED=(); PASSED=(); SKIPPED=()
red() { printf '\033[31m%s\033[0m\n' "$1"; }
grn() { printf '\033[32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[33m%s\033[0m\n' "$1"; }
gry() { printf '\033[90m%s\033[0m\n' "$1"; }

run() {
  local name="$1"; shift
  printf '\n=== %s ===\n' "$name"
  if "$@"; then PASSED+=("$name"); grn "PASS  $name"
  else FAILED+=("$name"); red "FAIL  $name"; fi
}
skip() { SKIPPED+=("$1: $2"); gry "SKIP  $1 ($2)"; }

DEVICE="${SALON_AR_DEVICE:-AG}"

# ------------------------------------------------------------ confirmations registry
#
# The check that makes every other ADR check non-optional. Each Confirmation in
# docs/adr/ must be registered in scripts/confirmations.tsv as ACTIVE or PENDING.
# An unregistered one is a boundary nobody is holding.

check_confirmations() {
  local reg=scripts/confirmations.tsv
  [ -f "$reg" ] || { red "no confirmations registry at $reg"; return 1; }

  local rc=0

  # Every ADR file must have at least one registered row.
  for adr in docs/adr/ADR-*.md; do
    [ -e "$adr" ] || continue
    local id; id=$(basename "$adr" | grep -o 'ADR-[0-9]\{3\}')
    if ! grep -q "^${id}	" "$reg"; then
      red "  $id has no registered Confirmation"; rc=1
    fi
  done

  # Every registered ACTIVE check must actually exist on disk.
  while IFS=$'\t' read -r adr id state check reason; do
    case "$adr" in ''|\#*) continue ;; esac
    [ "$state" = ACTIVE ] || continue
    case "$check" in
      scripts/*) [ -x "${check%% *}" ] || { red "  $adr/$id is ACTIVE but $check is missing or not executable"; rc=1; } ;;
    esac
  done < "$reg"

  # PENDING is never silent. This list is meant to be uncomfortable.
  local pending; pending=$(awk -F'\t' '$3=="PENDING"' "$reg" | wc -l | tr -d ' ')
  local active;  active=$(awk -F'\t' '$3=="ACTIVE"'  "$reg" | wc -l | tr -d ' ')
  printf '  %s active, %s pending\n' "$active" "$pending"
  if [ "$pending" -gt 0 ]; then
    ylw "  pending confirmations (unheld boundaries, each with a trigger):"
    awk -F'\t' '$3=="PENDING" {printf "    %-8s %-28s %s\n", $1, $2, $5}' "$reg"
  fi
  return $rc
}

run "confirmations registry" check_confirmations

# ------------------------------------------------------------ swift build
#
# .xcodeproj is a generated artifact (XcodeGen, from the committed project.yml) and is
# gitignored, so its absence is normal rather than a fault. An earlier version treated
# "Swift sources but no .xcodeproj" as a failure, which turned every Linux CI run red for
# a condition that is correct by design.

XCPROJ=$(ls -d ./*.xcodeproj ./*.xcworkspace 2>/dev/null | head -1)

# Generate it if we can. On a machine with xcodegen this makes the check real; on Linux
# it stays absent and we say so instead of failing.
if [ -z "$XCPROJ" ] && [ -f project.yml ] && command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --quiet 2>/dev/null || true
  XCPROJ=$(ls -d ./*.xcodeproj 2>/dev/null | head -1)
fi

if [ "$QUICK" = 1 ]; then
  skip "build" "--quick"
elif ! command -v xcodebuild >/dev/null 2>&1; then
  # Honest. Recorded in docs/DEBT.md as D-008: nothing Apple-toolchain can be verified on
  # a Linux runner, and pretending otherwise is how a vacuous green happens.
  skip "build" "no xcodebuild on this platform (see docs/DEBT.md D-008)"
elif [ -z "$XCPROJ" ]; then
  if [ -f project.yml ]; then
    FAILED+=("build"); red "FAIL  build (project.yml exists but xcodegen could not generate a project)"
  elif git ls-files -- ':(glob)**/*.swift' | grep -q .; then
    FAILED+=("build"); red "FAIL  build (swift sources exist with no project and no project.yml)"
  else
    skip "build" "no Xcode project and no Swift sources (pre-Gate-2)"
  fi
else
  run "build" xcodebuild build \
    -scheme "$(basename "${XCPROJ%.*}")" \
    -destination "platform=iOS Simulator,name=iPhone 17" \
    -quiet
fi

# ------------------------------------------------------------ tests
#
# Device only. AR face tracking does not exist in the simulator, so a green simulator run
# on this product is worse than no run: it is misleading.

# Device presence, correctly. An earlier version wrote
#     xctrace list devices | grep -qv Simulator | grep -q "$DEVICE"
# which is always false: grep -q exits after the first line and prints nothing, so the
# second grep reads empty input forever. It reported "device not attached" even with the
# device plugged in — a permanent false positive, which is the failure mode that teaches
# everyone to ignore the script.
device_attached() {
  xcrun xctrace list devices 2>/dev/null \
    | sed -n '/^== Devices ==/,/^== /p' \
    | grep -q "^${DEVICE} "
}

# Does a test target actually exist?
have_tests() {
  [ -n "$XCPROJ" ] && xcodebuild -list -project "$XCPROJ" 2>/dev/null \
    | sed -n '/Targets:/,/^$/p' | grep -qi 'test'
}

if [ -z "$XCPROJ" ]; then
  skip "tests" "no Xcode project yet"
elif [ "$QUICK" = 1 ]; then
  skip "tests" "--quick"
elif ! have_tests; then
  # Honest skip, not a failure. Pre-Gate-2 there is deliberately no product code, so
  # there is nothing to test. This becomes a FAILURE the moment a test target exists,
  # or the moment any AR source lands, because from then on tests genuinely should run.
  if git grep -qP '^\s*import\s+(ARKit|RealityKit)' -- ':(glob)**/*.swift' 2>/dev/null; then
    FAILED+=("tests"); red "FAIL  tests (AR sources exist but there is no test target)"
  else
    skip "tests" "no test target and no AR sources yet (pre-Gate-2)"
  fi
elif ! device_attached; then
  # The device is REQUIRED once tests exist. A check that should apply but cannot run is
  # a failure, not a skip: AR face tracking does not exist in the simulator, so there is
  # no fallback that would mean anything.
  FAILED+=("tests"); red "FAIL  tests (device '$DEVICE' not attached; AR tests cannot run in the simulator)"
else
  run "tests" xcodebuild test \
    -scheme "$(basename "${XCPROJ%.*}")" \
    -destination "platform=iOS,name=$DEVICE" \
    -quiet
fi

# ------------------------------------------------------------ format / lint
if command -v swiftlint >/dev/null 2>&1; then
  run "swiftlint" swiftlint --strict --quiet
else
  skip "swiftlint" "not installed (brew install swiftlint)"
fi

# ------------------------------------------------------------ product invariants
run "R-NOJUDGE vocabulary" ./scripts/lint-nojudge.sh
run "R-HONEST disclosure"  ./scripts/lint-honesty.sh
run "no orphan assets"     ./scripts/verify-no-orphan-assets.sh
run "viewpoint indirection" ./scripts/verify-viewpoint-indirection.sh

# ------------------------------------------------------------ secrets
run "no secrets in tree" bash -c '
  ! git grep -nE "(sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16})" -- . ":(exclude)scripts/dod.sh"
'

# ------------------------------------------------------------ security invariants
run "security invariants" ./scripts/security-invariants.sh
run "checks actually bite"  ./scripts/verify-checks-bite.sh

# ------------------------------------------------------------ summary
printf '\n================ DoD ================\n'
printf 'passed  %s\n' "${#PASSED[@]}"
printf 'skipped %s\n' "${#SKIPPED[@]}"
for s in "${SKIPPED[@]:-}"; do [ -n "$s" ] && gry "        $s"; done
printf 'failed  %s\n' "${#FAILED[@]}"
for f in "${FAILED[@]:-}"; do [ -n "$f" ] && red "        $f"; done

[ "${#FAILED[@]}" -eq 0 ] || exit 1
grn "DoD green"

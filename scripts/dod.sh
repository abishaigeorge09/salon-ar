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

# Postconditions on generation. XcodeGen exits 0 while producing a plist missing the one
# key ADR-005 depends on, which is how an app shipped with no camera usage string.
if [ -n "$XCPROJ" ] && [ -f Sources/App/Info.plist ]; then
  . ./scripts/lib.sh
  gen_ok=0
  produced "generated plist declares the camera" grep -q NSCameraUsageDescription Sources/App/Info.plist || gen_ok=1
  produced "generated plist declares a launch screen" grep -q UILaunchScreen Sources/App/Info.plist || gen_ok=1
  if [ "$gen_ok" = 0 ]; then PASSED+=("project generation"); grn "PASS  project generation"
  else FAILED+=("project generation"); red "FAIL  project generation"; fi
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

have_target() {
  [ -n "$XCPROJ" ] && xcodebuild -list -project "$XCPROJ" 2>/dev/null \
    | sed -n '/Targets:/,/^$/p' | grep -qi "$1"
}

# Two suites, two homes, and the split is a statement about what each can prove.
#
#   salon-arTests        pure logic, no ARKit. Runs on the SIMULATOR, because a device
#                        adds nothing to linear algebra and requiring one made the DoD red
#                        whenever the phone was locked.
#   salon-arDeviceTests  anything touching ARKit. Device ONLY. Face tracking does not exist
#                        in the simulator, so a green simulator run there would be worse
#                        than no run, and a missing device is a FAILURE rather than a skip.
#
# The loophole this must not open: an ARKit test smuggled into the unit suite would then
# run on the simulator and pass vacuously. Guarded below.

# The anti-loophole guard runs ALWAYS, including under --quick. It is a static grep that
# costs nothing, and an earlier version buried it inside the tests block where --quick
# skipped it — so the guard I had just written to prevent vacuous passes was itself being
# skipped in the fast path everyone actually runs.
# NOTE the plain grep rather than git grep: git grep searches the INDEX, so it silently
# ignores untracked files — which is precisely the code somebody is about to add and has
# not committed yet. A guard that only sees committed code cannot stop anything.
check_no_ar_in_unit_suite() {
  [ -d Tests ] || return 0
  if grep -rlE '^[[:space:]]*import[[:space:]]+(ARKit|RealityKit)' Tests --include='*.swift' >/dev/null 2>&1; then
    red "  ARKit or RealityKit imported in Tests/, which runs on the SIMULATOR where face"
    red "  tracking does not exist. It would pass vacuously. Move it to DeviceTests/."
    return 1
  fi
  return 0
}
run "no AR tests in the simulator suite" check_no_ar_in_unit_suite

if [ -z "$XCPROJ" ]; then
  skip "tests" "no Xcode project yet"
elif [ "$QUICK" = 1 ]; then
  skip "tests" "--quick"
else
  if have_target 'salon-arTests'; then
    run "unit tests (simulator)" xcodebuild test \
      -project "$XCPROJ" -scheme "$(basename "${XCPROJ%.*}")" \
      -only-testing:salon-arTests \
      -destination "platform=iOS Simulator,name=iPhone 17" -quiet
  else
    skip "unit tests" "no salon-arTests target"
  fi

  if have_target 'DeviceTests'; then
    if device_attached; then
      run "device tests (AG)" xcodebuild test \
        -project "$XCPROJ" -scheme "$(basename "${XCPROJ%.*}")" \
        -only-testing:salon-arDeviceTests \
        -destination "platform=iOS,name=$DEVICE" -quiet
    else
      FAILED+=("device tests"); red "FAIL  device tests (device '$DEVICE' not attached; AR cannot be tested in the simulator)"
    fi
  else
    # Honest: no AR test target exists yet. Becomes a failure the moment AR ships.
    if git grep -qP '^\s*import\s+(ARKit|RealityKit)' -- ':(glob)Sources/**/*.swift' 2>/dev/null; then
      ylw "  NOTE: AR sources exist with no salon-arDeviceTests target. Phase 1 must add one."
    fi
    skip "device tests" "no salon-arDeviceTests target yet (Phase 1)"
  fi
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

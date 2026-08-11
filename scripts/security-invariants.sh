#!/usr/bin/env bash
# Deterministic security invariants. No model involved, so these cannot forget.
#
# This project's entire security surface is one sentence: face geometry from members of
# the public who never agreed to anything must not leave the device, must not reach
# disk, and must not outlive the session. See docs/adr/ADR-005-biometric-data.md.
#
# The strongest check here is binary-level rather than policy-level. Instead of asserting
# that we do not upload, it asserts that the built AR module links no networking symbol
# at all: a binary in which uploading is not expressible. Any future upload is therefore
# a linker change and a new ADR, not a config flag.
#
# Design rule: a check that should apply but cannot run is a FAILURE, not a skip.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
. "$(dirname "$0")/lib.sh"
assert_grep_engine

FAILED=(); PASSED=(); PENDING=()
red() { printf '\033[31m%s\033[0m\n' "$1"; }
grn() { printf '\033[32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[33m%s\033[0m\n' "$1"; }

ok()      { PASSED+=("$1");  grn "PASS     $1"; }
bad()     { FAILED+=("$1");  red "FAIL     $1"; [ -n "${2:-}" ] && printf '%s\n' "$2"; }
pending() { PENDING+=("$1"); ylw "PENDING  $1 — ${2:-}"; }

SRC_GLOB=(':(glob)**/*.swift' ':(glob)**/*.m' ':(glob)**/*.mm' ':(glob)**/*.h')
have_swift() { git ls-files -- "${SRC_GLOB[@]}" 2>/dev/null | grep -q .; }

# ==================================================== 1. networking, source level
# Runs from day one. Catches the import before it ever reaches a binary.

if ! have_swift; then
  # Not a pass. There is no source to check, and saying "PASS" here would be a lie
  # that gets quoted later as evidence.
  pending "no-networking-source" "no Swift sources yet; trigger: first .swift file"
else
  hits=$(gg_code '^\s*(import|@_implementationOnly import)\s+(Foundation\.URL|Network|CFNetwork|Alamofire|Starscream)\b' \
           -- "${SRC_GLOB[@]}" 2>/dev/null || true)
  urlhits=$(gg_code '\b(URLSession|URLRequest|NWConnection|CFSocket|NSURLConnection)\b' \
           -- "${SRC_GLOB[@]}" 2>/dev/null || true)
  if [ -n "$hits$urlhits" ]; then
    bad "no-networking-source" "$hits$urlhits"
  else
    ok "no-networking-source"
  fi
fi

# ==================================================== 2. networking, binary level
# The check that actually bites: a binary in which uploading is not expressible.
#
# It must scan EVERY Mach-O in the .app, not just the executable. Xcode 26 emits a thin
# launcher stub and puts the real code in salon-ar.debug.dylib, so an earlier version of
# this check inspected 31 symbols of stub, found no networking, and reported PASS. It
# would have passed on any app ever built. The actual code carries 611 symbols.
#
# Hence the symbol floor below: a check that inspected almost nothing must say so rather
# than call it a pass. That is the general defence against this whole class.

# Search order matters. An earlier version looked in /tmp first and therefore inspected
# whichever app happened to be lying around rather than the one built from this tree —
# which meant the bite probe's planted bundle was ignored and the check reported PASS.
# The working tree wins; DerivedData is the fallback.
APP=$(find . -name 'salon-ar.app' -type d 2>/dev/null | head -1)
[ -z "$APP" ] && APP=$(find /tmp "$HOME/Library/Developer/Xcode/DerivedData" -name 'salon-ar.app' -type d 2>/dev/null | head -1)

if [ -z "$APP" ]; then
  pending "no-networking-binary" "no built .app found; trigger: first successful build"
else
  MACHO=$(find "$APP" -type f -perm +111 2>/dev/null | while read -r f; do
            file "$f" 2>/dev/null | grep -q Mach-O && printf '%s\n' "$f"; done)
  total=0; syms=""
  for m in $MACHO; do
    n=$(nm -u "$m" 2>/dev/null | wc -l | tr -d ' ')
    total=$((total + n))
    hit=$(nm -u "$m" 2>/dev/null | awk '{print $NF}' \
      | grep -iE '^_?(URLSession|NWConnection|CFSocket|CFReadStream|NSURLConnection|getaddrinfo|connect|socket|send|recv)(@|$)' || true)
    [ -n "$hit" ] && syms="$syms
$(basename "$m"): $hit"
  done

  # Sanity floor. A launcher stub is ~30 symbols; a real app is hundreds. Anything below
  # this means we inspected a stub and learned nothing, which is a FAILURE and not a pass.
  if [ "$total" -lt 200 ]; then
    bad "no-networking-binary" "only $total symbols across $(printf '%s' "$MACHO" | wc -l | tr -d ' ') Mach-O files in $APP.
That is stub-sized. The check inspected almost nothing, so it proves nothing."
  elif [ -n "$syms" ]; then
    bad "no-networking-binary" "networking symbols linked:$syms"
  else
    ok "no-networking-binary ($total symbols across $(printf '%s\n' "$MACHO" | grep -c . ) Mach-O files)"
  fi
fi

# ==================================================== 3. no image or geometry to disk
if ! have_swift; then
  pending "no-image-persistence" "no Swift sources yet"
else
  # Deliberately broad. This app has no legitimate reason to write anything to disk, so
  # every write path is flagged and must carry an explicit ADR-005 exemption comment.
  # An earlier version matched only type names (ARFaceGeometry), which let a variable
  # called faceGeometry through — and a variable is what anyone would actually write.
  hits=$(gg_code '\.write\s*\(\s*to:|\.writeToFile|FileManager\.default\.(createFile|copyItem|moveItem)|CGImageDestination|UIImageWriteToSavedPhotosAlbum' \
           -- "${SRC_GLOB[@]}" 2>/dev/null | grep -v 'ADR-005-exempt' || true)
  if [ -n "$hits" ]; then bad "no-image-persistence" "$hits"; else ok "no-image-persistence"; fi
fi

# ==================================================== 4. no screen-capturing SDKs
# Deliberately runs on an empty dependency graph: an empty graph genuinely contains no
# analytics SDK, so this is a real pass rather than a vacuous one.

DEPS=""
[ -f Package.swift ]     && DEPS="$DEPS$(cat Package.swift)"
[ -f Podfile ]           && DEPS="$DEPS$(cat Podfile)"
[ -f Cartfile ]          && DEPS="$DEPS$(cat Cartfile)"
for f in $(find . -name 'Package.resolved' -not -path './.git/*' 2>/dev/null); do DEPS="$DEPS$(cat "$f")"; done

banned=$(printf '%s' "$DEPS" | grep -ioE '(firebase|crashlytics|sentry|bugsnag|amplitude|mixpanel|segment|appsflyer|adjust|smartlook|fullstory|logrocket|instabug|datadog|newrelic|posthog)' | sort -u || true)
if [ -n "$banned" ]; then
  bad "no-analytics-sdks" "ADR-005 forbids any SDK able to capture a screen or view hierarchy. Found:
$banned"
else
  ok "no-analytics-sdks"
fi

# ==================================================== 5. minimal entitlements
PLIST=$(find . -name 'Info.plist' -not -path './.git/*' -not -path '*/Build/*' 2>/dev/null | head -1)
if [ -z "$PLIST" ]; then
  pending "minimal-entitlements" "no Info.plist yet; trigger: Xcode project lands"
else
  extra=$(grep -oE 'NS(PhotoLibrary(Add)?UsageDescription|LocationWhenInUseUsageDescription|LocationAlwaysUsageDescription|MicrophoneUsageDescription|ContactsUsageDescription)' "$PLIST" | sort -u || true)
  if [ -n "$extra" ]; then
    bad "minimal-entitlements" "ADR-005 permits camera only. Found:
$extra"
  elif ! grep -q 'NSCameraUsageDescription' "$PLIST"; then
    bad "minimal-entitlements" "no NSCameraUsageDescription: the app cannot function and the plist is wrong"
  else
    ok "minimal-entitlements"
  fi
fi

# ==================================================== 6. no retention of session state
if ! have_swift; then
  pending "no-session-retention" "no Swift sources yet"
else
  hits=$(gg_code '\b(UserDefaults|NSKeyedArchiver|CoreData|SwiftData|Keychain)\b' -- "${SRC_GLOB[@]}" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    bad "no-session-retention" "persistence APIs in a project that must retain nothing. Each needs an ADR-005 exemption comment:
$hits"
  else
    ok "no-session-retention"
  fi
fi

# ==================================================== summary
printf '\n=========== security invariants ===========\n'
printf 'passed  %s\n' "${#PASSED[@]}"
if [ "${#PENDING[@]}" -gt 0 ]; then
  printf 'pending %s\n' "${#PENDING[@]}"
  for p in "${PENDING[@]}"; do ylw "        $p"; done
  printf '\n%s\n' "Pending is not passing. These boundaries are not yet held."
fi
printf 'failed  %s\n' "${#FAILED[@]}"
for f in "${FAILED[@]:-}"; do [ -n "$f" ] && red "        $f"; done

[ "${#FAILED[@]}" -eq 0 ] || exit 1
grn "security invariants green"

#!/usr/bin/env bash
# Meta-check: prove every ACTIVE invariant actually fails when violated.
#
# WHY THIS EXISTS
#
# The first version of these checks was green on a repo that contained a URLSession call,
# a UserDefaults write, and a direct AR camera read. Every one of them reported PASS. The
# cause was `git grep -E '\bURLSession\b'`: git's ERE engine ignores \b, so the pattern
# matched nothing, and "matched nothing" is indistinguishable from "no violation" unless
# somebody checks.
#
# A check nobody has watched fail is not a check, it is a decoration. This script plants
# each violation in a scratch worktree, runs the check that forbids it, and requires a
# non-zero exit. It also requires each check to pass on a clean tree, because a check that
# fires on everything gets ignored within a week, which is the more expensive failure.
#
# Runs in a scratch git worktree so it can never dirty the real tree or index.

set -uo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

WT=$(mktemp -d)/bite
git worktree add -q --detach "$WT" 2>/dev/null || { printf 'could not create scratch worktree\n'; exit 1; }
cleanup() { cd "$ROOT"; git worktree remove --force "$WT" 2>/dev/null; rm -rf "$(dirname "$WT")"; }
trap cleanup EXIT

# The worktree is checked out at HEAD, where scripts/ may not be committed yet. Copy
# the WORKING TREE scripts in, because those are the ones under test. Without this the
# scripts are simply absent, every invocation exits non-zero, and the harness reads that
# as "bites" — proving nothing while looking green.
# NOTE the trailing "/." — `cp -R src dst` NESTS as dst/src when dst already exists, and
# scripts/ IS committed, so the naive form silently ran the STALE committed scripts while
# reporting on them as if they were the working tree. Second time this harness has proved
# the wrong thing while looking green.
mkdir -p "$WT/scripts"
cp -R "$ROOT/scripts/." "$WT/scripts/"
[ -d "$WT/scripts/scripts" ] && { printf 'scripts/ nested; copy is wrong\n'; exit 1; }
cd "$WT"
PASS=0; FAIL=0
red() { printf '\033[31m%s\033[0m\n' "$1"; }
ylw() { printf '\033[33m%s\033[0m\n' "$1"; }
grn() { printf '\033[32m%s\033[0m\n' "$1"; }

# Every check script exercised by at least one probe. Compared against the ACTIVE rows
# of the registry below, so a new ACTIVE check cannot be added without a probe that has
# been watched failing.
COVERED=""

# bite <description> <setup> <script> <registry-id>
#
# The registry id is required, and coverage is computed per ID rather than per script.
# Script-level coverage was too coarse: a sixth check added inside security-invariants.sh
# would have read "covered" on the strength of the other five having probes.
bite() {
  local n="$1" setup="$2" s="$3" cid="${4:?bite() needs the confirmations.tsv id}"
  COVERED="$COVERED $cid"
  mkdir -p Sources assets
  eval "$setup"
  git add -A -f >/dev/null 2>&1
  if ./"$s" >/dev/null 2>&1; then
    red "  DID NOT BITE  $n  ($s)"; FAIL=$((FAIL+1))
  else
    grn "  bites         $n"; PASS=$((PASS+1))
  fi
  git reset -q >/dev/null 2>&1
  rm -rf Sources assets Build Info.plist Package.swift 2>/dev/null
}

printf '\n--- each ACTIVE check must FAIL when its violation is present ---\n'

bite "R-NOJUDGE: judgement vocabulary" \
  'echo "let s = \"suits your face shape\"" > Sources/A.swift' scripts/lint-nojudge.sh no-judgement-vocabulary
bite "R-HONEST: live AR view without disclosure" \
  'printf "import RealityKit\nstruct V { var v: ARView? }\n" > Sources/A.swift' scripts/lint-honesty.sh honesty-copy
bite "ADR-006: direct AR camera transform read" \
  'echo "let t = session.currentFrame.camera.transform" > Sources/A.swift' scripts/verify-viewpoint-indirection.sh no-direct-camera-reads
bite "ADR-004: orphan hand-placed style asset" \
  'touch assets/bob_handmade.usdz' scripts/verify-no-orphan-assets.sh no-orphan-assets
bite "ADR-005: URLSession in source" \
  'echo "let t = URLSession.shared" > Sources/A.swift' scripts/security-invariants.sh no-networking-source
bite "ADR-005: import Network" \
  'echo "import Network" > Sources/A.swift' scripts/security-invariants.sh no-networking-source
bite "ADR-005: analytics SDK in dependency graph" \
  'echo "// sentry-cocoa" > Package.swift' scripts/security-invariants.sh no-analytics-sdks
bite "ADR-005: Photos permission in Info.plist" \
  'printf "NSCameraUsageDescription\nNSPhotoLibraryAddUsageDescription\n" > Info.plist' scripts/security-invariants.sh minimal-entitlements
bite "ADR-005: UserDefaults retention" \
  'echo "UserDefaults.standard.set(m, forKey: \"k\")" > Sources/A.swift' scripts/security-invariants.sh no-session-retention
# The ADR-005 headline check, and the hardest probe to write honestly.
#
# It must plant a REAL .app bundle, because the check scans every Mach-O in a bundle after
# discovering that Xcode 26 hides the code in a debug dylib behind a thin launcher stub.
# It must also carry enough symbols to clear the check's stub floor, or the check fails for
# the wrong reason and the probe proves the wrong thing.
#
# So: copy a real built bundle, drop a networking binary inside it, and assert the check
# fails specifically ON NETWORKING rather than on the floor. Asserting the reason, not just
# the exit code, is what stops this probe from going green for an unrelated failure.
probe_binary_check() {
  local why=""
  command -v cc >/dev/null 2>&1 || why="no C compiler"
  command -v nm >/dev/null 2>&1 || why="${why:+$why, }no nm"
  local real
  real=$(find /tmp "$HOME/Library/Developer/Xcode/DerivedData" -name 'salon-ar.app' -type d 2>/dev/null | head -1)
  [ -z "$real" ] && why="${why:+$why, }no built .app to base the probe on"

  if [ -z "$why" ]; then
    rm -rf Probe.app 2>/dev/null
    cp -R "$real" ./Probe.app 2>/dev/null || why="could not copy a bundle"
    if [ -z "$why" ]; then
      mv Probe.app "salon-ar.app" 2>/dev/null
      printf '#include <sys/socket.h>\nint main(void){ return socket(AF_INET, SOCK_STREAM, 0); }\n' > np.c
      cc -o "salon-ar.app/netprobe" np.c 2>/dev/null || why="compile failed"
      rm -f np.c
    fi
  fi

  if [ -n "$why" ]; then
    ylw "  UNPROVEN HERE ADR-005 binary check ($why); proven where the app builds"
    COVERED="$COVERED no-networking-binary"
    rm -rf salon-ar.app np.c 2>/dev/null
    return 1
  fi
  return 0
}

if probe_binary_check; then
  git add -A -f >/dev/null 2>&1
  out=$(./scripts/security-invariants.sh 2>&1)
  if printf '%s' "$out" | grep -q 'networking symbols linked'; then
    grn "  bites         ADR-005: a bundle containing a binary that links networking"
    PASS=$((PASS+1))
  elif printf '%s' "$out" | grep -q 'stub-sized'; then
    red "  WRONG REASON  ADR-005 binary check failed on the stub floor, not on networking"
    FAIL=$((FAIL+1))
  else
    red "  DID NOT BITE  ADR-005: a bundle containing a binary that links networking"
    FAIL=$((FAIL+1))
  fi
  COVERED="$COVERED no-networking-binary"
  git reset -q >/dev/null 2>&1
  rm -rf salon-ar.app 2>/dev/null
fi

bite "ADR-005: face geometry written to disk" \
  'echo "try faceGeometry.write(to: url)" > Sources/A.swift' scripts/security-invariants.sh no-image-persistence

printf '\n--- and a COMMENT mentioning a forbidden thing must NOT fire (false positives\n'
printf '    teach everyone to ignore the script, which is worse than a missing check) ---\n'

# nocomment <description> <setup> <script>
nocomment() {
  local n="$1" setup="$2" s="$3"
  mkdir -p Sources
  eval "$setup"
  git add -A -f >/dev/null 2>&1
  local out
  if out=$(./"$s" 2>&1); then
    grn "  ignores prose  $n"; PASS=$((PASS+1))
  else
    red "  FALSE POSITIVE  $n fires on a comment  ($s)"
    printf '%s\n' "$out" | grep -E '^.?.?.?.?.?FAIL' | sed 's/^/        /'
    FAIL=$((FAIL+1))
  fi
  git reset -q >/dev/null 2>&1; rm -rf Sources 2>/dev/null
}

nocomment "comment saying we never use URLSession" \
  'printf "// We deliberately never use URLSession here.\n" > Sources/A.swift' scripts/security-invariants.sh
nocomment "doc comment mentioning UserDefaults" \
  'printf "/// Nothing is stored in UserDefaults, by ADR-005.\n" > Sources/A.swift' scripts/security-invariants.sh
nocomment "comment describing the forbidden camera read" \
  'printf "// Never read session.currentFrame.camera.transform directly.\n" > Sources/A.swift' scripts/verify-viewpoint-indirection.sh no-direct-camera-reads

printf '\n--- and each must PASS on a clean tree (a check that cries wolf gets ignored) ---\n'
for s in lint-nojudge lint-honesty verify-viewpoint-indirection verify-no-orphan-assets security-invariants; do
  if ./scripts/$s.sh >/dev/null 2>&1; then
    grn "  clean-pass    $s"; PASS=$((PASS+1))
  else
    red "  FALSE POSITIVE  $s fires on a clean tree"; FAIL=$((FAIL+1))
  fi
done

# ---------------------------------------------------------------- coverage
#
# The teeth. A check that has never been watched failing is a decoration, so an ACTIVE
# registry row whose script has no probe is itself a failure. This is what stops the
# next check from being written, believed, and never tested.
printf '\n--- every ACTIVE check script must have a probe ---\n'
while IFS=$'\t' read -r adr id state check reason; do
  case "$adr" in ''|\#*) continue ;; esac
  [ "$state" = ACTIVE ] || continue
  case "$check" in scripts/*) ;; *) continue ;; esac
  # The meta-check cannot probe itself without recursing, and dod.sh is the harness that
  # RUNS the probes, so it cannot be one. Both exemptions are named here rather than left
  # as silent gaps — dod.sh's own postconditions are negative-tested by hand at the commit
  # that introduces them, and that is a weaker guarantee, stated plainly.
  [ "$check" = "scripts/verify-checks-bite.sh" ] && continue
  [ "$check" = "scripts/dod.sh" ] && { ylw "  exempt        $adr/$id (dod.sh runs the probes; cannot be one)"; continue; }
  case " $COVERED " in
    *" $id "*) grn "  covered       $adr/$id"; PASS=$((PASS+1)) ;;
    *) red "  NO PROBE      $adr/$id has never been watched failing"; FAIL=$((FAIL+1)) ;;
  esac
done < scripts/confirmations.tsv

printf '\nproven %s, broken %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
grn "every active check proven to bite in both directions"

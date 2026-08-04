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
grn() { printf '\033[32m%s\033[0m\n' "$1"; }

# bite <description> <setup> <script>
bite() {
  local n="$1" setup="$2" s="$3"
  mkdir -p Sources assets
  eval "$setup"
  git add -A -f >/dev/null 2>&1
  if ./"$s" >/dev/null 2>&1; then
    red "  DID NOT BITE  $n  ($s)"; FAIL=$((FAIL+1))
  else
    grn "  bites         $n"; PASS=$((PASS+1))
  fi
  git reset -q >/dev/null 2>&1
  rm -rf Sources assets Info.plist Package.swift 2>/dev/null
}

printf '\n--- each ACTIVE check must FAIL when its violation is present ---\n'

bite "R-NOJUDGE: judgement vocabulary" \
  'echo "let s = \"suits your face shape\"" > Sources/A.swift' scripts/lint-nojudge.sh
bite "R-HONEST: live AR view without disclosure" \
  'printf "import RealityKit\nstruct V { var v: ARView? }\n" > Sources/A.swift' scripts/lint-honesty.sh
bite "ADR-006: direct AR camera transform read" \
  'echo "let t = session.currentFrame.camera.transform" > Sources/A.swift' scripts/verify-viewpoint-indirection.sh
bite "ADR-004: orphan hand-placed style asset" \
  'touch assets/bob_handmade.usdz' scripts/verify-no-orphan-assets.sh
bite "ADR-005: URLSession in source" \
  'echo "let t = URLSession.shared" > Sources/A.swift' scripts/security-invariants.sh
bite "ADR-005: import Network" \
  'echo "import Network" > Sources/A.swift' scripts/security-invariants.sh
bite "ADR-005: analytics SDK in dependency graph" \
  'echo "// sentry-cocoa" > Package.swift' scripts/security-invariants.sh
bite "ADR-005: Photos permission in Info.plist" \
  'printf "NSCameraUsageDescription\nNSPhotoLibraryAddUsageDescription\n" > Info.plist' scripts/security-invariants.sh
bite "ADR-005: UserDefaults retention" \
  'echo "UserDefaults.standard.set(m, forKey: \"k\")" > Sources/A.swift' scripts/security-invariants.sh
bite "ADR-005: face geometry written to disk" \
  'echo "try faceGeometry.write(to: url)" > Sources/A.swift' scripts/security-invariants.sh

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
  'printf "// Never read session.currentFrame.camera.transform directly.\n" > Sources/A.swift' scripts/verify-viewpoint-indirection.sh

printf '\n--- and each must PASS on a clean tree (a check that cries wolf gets ignored) ---\n'
for s in lint-nojudge lint-honesty verify-viewpoint-indirection verify-no-orphan-assets security-invariants; do
  if ./scripts/$s.sh >/dev/null 2>&1; then
    grn "  clean-pass    $s"; PASS=$((PASS+1))
  else
    red "  FALSE POSITIVE  $s fires on a clean tree"; FAIL=$((FAIL+1))
  fi
done

printf '\nproven %s, broken %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
grn "every active check proven to bite in both directions"

#!/usr/bin/env bash
# Shared helpers for the invariant scripts.
#
# WHY THIS FILE EXISTS
#
# The first version of these checks used `git grep -E '\bURLSession\b'`. git's ERE engine
# does not support \b, so the pattern matched nothing — and a grep that matches nothing
# exits non-zero, which the script read as "no violation found" and reported as PASS.
#
# That is the worst possible failure mode for a security check: green, in a repo
# containing the exact thing it forbids. It was caught only because every check was
# negative-tested rather than assumed to work. Hence scripts/verify-checks-bite.sh, which
# makes that negative test permanent.
#
# Two defences, both here:
#   1. gg() forces git's PCRE engine, which does support \b, \s and \d.
#   2. assert_grep_engine() proves THAT ENGINE honours \b before any check runs.
#
# Note on which engine gets tested: macOS ships BSD grep, which has no -P at all. An
# earlier version of this guard tested system grep and correctly refused to run, which
# was right but useless — the checks do not use system grep. It tests git grep, because
# that is what gg() calls. Test the engine you actually use.
#
# Rule for anyone editing these scripts: never call `git grep` directly. Use gg().
# For pipelines where git grep is not available (nm output), use word_re() below.

# Proves git's regex engine honours word boundaries in both directions. A check that
# cannot run is a failure, not a skip, and an engine that silently ignores \b means none
# of these checks can run.
assert_grep_engine() {
  local probe=".grep-engine-probe.tmp"
  printf 'let u = URLSession.shared\nlet v = MyURLSessionThing\n' > "$probe"

  local n
  n=$(git grep -cP --no-index '\bURLSession\b' -- "$probe" 2>/dev/null | tail -1 | sed 's/.*://')
  rm -f "$probe"

  # Exactly one line matches: the standalone token, not the embedded one. Any other
  # answer means \b is being ignored in one direction or the other.
  if [ "${n:-0}" != "1" ]; then
    printf '\033[31mFATAL: git grep -P does not honour \\b correctly (got "%s", want "1").\n' "${n:-none}"
    printf 'Every invariant check would silently pass. Refusing to run.\033[0m\n'
    exit 2
  fi
}

# git grep, PCRE, always. Never call `git grep -E` in this repo.
gg() { git grep -nP "$@"; }

# Word-boundary equivalent for pipelines that cannot use git grep (e.g. nm output piped
# to BSD grep, which has no -P). Portable ERE: not preceded or followed by an identifier
# character.
#   word_re URLSession  ->  (^|[^A-Za-z0-9_])URLSession($|[^A-Za-z0-9_])
word_re() { printf '(^|[^A-Za-z0-9_])%s($|[^A-Za-z0-9_])' "$1"; }

# Grep CODE, not prose.
#
# Every source check in this repo originally matched comment lines. The DoD reported
# "AR sources exist" because a comment said "there is deliberately no ARKit session", and
# the ADR-005 networking check would have failed on a comment saying "we never use
# URLSession". False positives are more expensive than missing checks, because they teach
# everyone to ignore the script — so the checks must read code.
#
# Skips whole-line comments (// /// * /*). Trailing comments on a code line still match,
# which is the safe direction: it over-reports on a line that also contains real code.
gg_code() {
  local pat="$1"; shift
  gg "^(?!\\s*(///|//|\\*|/\\*)).*(?:${pat})" "$@"
}

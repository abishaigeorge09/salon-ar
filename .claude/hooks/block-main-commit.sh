#!/usr/bin/env bash
# PreToolUse hook on Bash. Refuses a commit while on the default branch.
#
# Every repo in this system uses branch-then-PR. The rule was written down in
# three places and still got broken, because a document cannot refuse.
set -uo pipefail
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

case "$cmd" in *"git commit"*) ;; *) exit 0 ;; esac

# symbolic-ref first: it reports the branch even on an unborn HEAD (a repo with
# no commits yet), where rev-parse errors and would leave this check silently
# permissive. A gate that fails open is worse than no gate.
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null \
         || git rev-parse --abbrev-ref HEAD 2>/dev/null \
         || echo "")

case "$branch" in
  main|master)
    jq -n --arg b "$branch" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: ("Refusing to commit directly to \($b). Branch first: git switch -c <name>-<what-youre-doing>. Uncommitted changes come with you.")
      }
    }'
    ;;
esac
exit 0

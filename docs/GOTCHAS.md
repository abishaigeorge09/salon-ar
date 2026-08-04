# Gotchas

Every bug in this repo so far has been the same bug wearing different clothes: **a tool did
exactly what it was told, nothing like what was meant, and reported success.**

| What was written | What it did | What it reported |
|---|---|---|
| `git grep -E '\bX\b'` | matched nothing (git's ERE has no `\b`) | no violation found |
| `cp -R src dst` | nested as `dst/src` because dst existed | tested the stale committed scripts |
| XcodeGen `info.path` | overwrote the hand-written plist | shipped with no camera key, no launch screen |
| CI `ls ./*.xcodeproj` | found nothing (it is generated and gitignored) | "nothing to build", green |
| `grep -qv A \| grep -q B` | `-q` exits early and prints nothing | "device not attached", forever |
| source greps | matched comments | "AR sources exist" from a comment saying there are none |

Every one exited 0.

## The rules that follow

1. **Every check is born red.** Write it, plant the violation, *watch it fail*, then make it
   pass. Enforced: `scripts/verify-checks-bite.sh` fails if any ACTIVE row in
   `scripts/confirmations.tsv` has no probe. Coverage is per check id, not per script,
   because script-level coverage let `no-networking-binary` sit unprobed behind five
   siblings that did have probes.
2. **Assert the postcondition after anything that generates, copies or builds.** Use
   `produced()` in `scripts/lib.sh`. Exit 0 is not evidence that the right thing happened.
3. **A check must pass on a clean tree too.** A false positive is more expensive than a
   missing check, because it teaches everyone to ignore the script.
4. **Probe in a scratch worktree, never the working tree.** An ad-hoc probe ending in
   `rm -rf Sources` deleted the real source directory. It was committed, so nothing was
   lost, which was luck rather than design.
5. **Look at the render.** The scaled, clipped UI was invisible to `xcodebuild`, which
   stayed green throughout. Screenshot baselines land in Phase 1.
6. **Search memory before debugging the environment.** The GitHub two-account fix was
   already written down, verbatim, and was rediscovered from scratch.

## Specific traps in this stack

- `git grep -P` supports `\b`; `git grep -E` does not; macOS BSD `grep` has no `-P` at all.
  Use `gg()` / `gg_code()` from `lib.sh`, never `git grep` directly.
- Converting BRE to PCRE: `a\|b` means "a or b" in BRE and the literal `a|b` in PCRE.
- `.xcodeproj` is generated from `project.yml` and gitignored. Its absence is normal.
- Do not hand-write `Sources/App/Info.plist`. XcodeGen owns it.
- Signing team is `LC743Z7W4J`, from the certificate's OU field. The parenthetical in
  `Apple Development: email (63V2MGYZ2K)` is the certificate ID and is *not* the team.
- This repo pins a local `gh` credential helper, because the machine has two GitHub
  accounts and plain git authenticates as the wrong one.

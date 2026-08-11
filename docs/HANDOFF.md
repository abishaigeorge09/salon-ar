# HANDOFF

Written 2026-08-11, at the point the project was paused. This is the document to read first
if the project is picked up again, by me or by anyone else. It records what exists, what was
learned, what is blocked, and what the next person should do first.

It is deliberately blunt about what was **not** proven. The single most expensive habit this
project fought was a check that was green while proving nothing, and a handoff that flatters
the work is the same failure at document scale.

---

## 1. Where the project actually stands

**Status: paused after the spike, before Phase 1.**

| Gate | State |
|---|---|
| Brief and scope contract | Agreed. `docs/BRIEF.md`, nine requirements R-LIVE … R-DEGRADE |
| Architecture, six ADRs | Written and approved. `docs/adr/` |
| Gate 1, design direction | **Passed.** "Chair-side", kitchen sink approved |
| Gate 1b, information architecture | **Passed.** One screen. `docs/design/IA.md` |
| Gate 2, build plan | **Passed.** Six phases. `docs/PLAN.md` |
| Spike, live camera + face tracking + crude mesh | **Built, installed on device, NOT validated by a human** |
| Phase 1, occlusion | **Not started** |

Repo: `github.com/abishaigeorge09/salon-ar`, public.
Open work: **PR #4**, branch `spike/face-tracking`, three commits ahead of `main`, unmerged.
Merged: PRs #1, #2, #3.

`bash scripts/dod.sh --quick` is green: 10 passed, 0 failed, 3 skipped (build, tests,
swiftlint-not-installed). The bite suite proves 29 checks, 0 broken.

### What runs today

A spike app on the iPhone (`AG`, iPhone 16 Pro Max). Full-bleed front camera, ARKit face
tracking, one crude dark mass of three scaled spheres anchored to the head, a lock-state
indicator, and the honesty note. A long-press anywhere opens the approved design direction.

It has no occlusion, so the mass clips through the ears and cuts across the forehead. It has
no hairstyles, no freeze mode and no removal. It is not a product and was never meant to look
like one. Its only job was to answer one question, and that question is still open (§3).

---

## 2. What was learned

### 2.1 The architectural finding, and it is the important one

**An overlay can add hair. It cannot remove it.** This was flagged in the brief as the thing
that must not be discovered during build, and the research confirmed it is real and severe.

The resolution is ADR-001: a **two-mode hybrid**.

- **Live mode is additive.** Real-time, every frame, and it can only ever show a style that is
  bigger than the customer's current hair. Six to eight weeks.
- **Freeze mode does removal on a single frame.** The customer holds still, one frame is
  segmented and the hair region regenerated. Four to six weeks on top.

The constraint that makes freeze mode survivable is written into the ADR and must never be
relaxed: **the generative pass is masked-region-only.** Every pixel outside the dilated hair
mask is carried through byte-identical. This is the defence against **identity drift**, the
failure where a generative pipeline hands somebody back a photo of a stranger with their
haircut. In a salon chair that is not a glitch, it is an insult.

Segmentation at 30–100fps with ~0.89 IoU is well-established on mobile. Real-time *edge
inpainting* has essentially no prior art. That asymmetry is the whole reason removal is
frozen to one frame rather than attempted live.

### 2.2 The brief's central technical assumption was wrong, in our favour

The brief assumed face tracking requires a TrueDepth camera. **It has not since iOS 14.**
`ARFaceTrackingConfiguration` runs on any device with a front camera and an A12 Bionic or
later. The requirement moved from the depth sensor to the Neural Engine.

This materially widens the device matrix: most iPads a salon already owns will work. It is
why `FaceCapability` gates on a **runtime capability check, never a device-model allowlist** —
an allowlist rots on every hardware release and silently excludes devices that work.

### 2.3 Nine checks were green while proving nothing, and four guarded the biometric boundary

This was the dominant theme of the build and the reason the enforcement layer looks
paranoid. A partial list, each one found only by deliberately going looking:

- **`git grep -E '\bX\b'` matches nothing.** Git's ERE does not support `\b`. The security
  invariants reported PASS on a tree that contained `URLSession`, `UserDefaults`, a disk
  write and a direct camera read. All four ADR-005 checks were vacuous simultaneously.
- **The `nm` no-networking check had five separate causes of vacuity**, the worst being
  Xcode 26's **thin launcher stub**: the check was reading 31 symbols of a launcher while the
  real code sat in `salon-ar.debug.dylib` with 611. It would have passed on any app ever
  compiled. It now scans every Mach-O in the bundle and enforces a **symbol floor of 200**.
- **XcodeGen silently overwrote a hand-written `Info.plist`.** The app shipped with no camera
  permission string and no launch screen. The missing launch screen made the entire UI render
  at roughly 2× scale, clipped off the left edge, while `xcodebuild` stayed green.
- **CI passed vacuously.** The macOS job ran `ls ./*.xcodeproj`, found none because the
  project file is generated and gitignored, printed "nothing to build", and passed.
- **`cp -R src dst` nests when `dst` exists**, so the bite harness silently ran stale
  committed scripts and "missing script" was read as "check fired".
- **`gg_code -i PATTERN` used `-i` as the pattern** and pushed the real pattern into the
  pathspec list, matching no files. This disabled ADR-005's `no-image-persistence`.
- **A doc comment satisfied the honesty lint.** It now requires a real string literal.

**The rule that came out of it, and it is the single most transferable thing in this repo:**

> **Every check is born red. Write it, plant the violation, watch it fail, then make it pass.**

That rule is now mechanically enforced by `scripts/verify-checks-bite.sh`, which plants a
violation for every ACTIVE check, requires a non-zero exit, requires a clean-tree pass,
requires prose immunity (a comment mentioning `URLSession` must not fire, because a false
positive teaches everyone to ignore the whole script), and enforces **per-check-id coverage**
so a new check cannot be added without a probe.

`scripts/confirmations.tsv` is the companion: every ADR Confirmation is registered exactly
once as **ACTIVE** or **PENDING with a named trigger**. There is no third state, and `dod.sh`
prints every pending row on every run so the list is uncomfortable to look at.

### 2.4 Smaller traps, all now in `docs/GOTCHAS.md`

- `DEVELOPMENT_TEAM` is the certificate's **OU field** (`LC743Z7W4J`), not the parenthetical
  in the certificate name (`63V2MGYZ2K`, which is the certificate ID). This costs an hour.
- `grep -qv A | grep -q B` is always false: `-q` exits early and prints nothing.
- Source greps match comments. `gg_code` skips whole-line comments; a plain grep once
  reported "AR sources exist" from a comment saying there were none.
- Swift 6: `Type` is a reserved member name; RealityKit materials are not `Sendable`, so
  entity construction is `@MainActor`.
- **A hardcoded "This iPad" was shown on an iPhone.** Found by rendering, not by reading.
  Rendering finds a class of bug that no amount of code review does.

### 2.5 Process learnings

- **The tier call was correct.** FULL was right, and not because the app is complicated. It
  processes biometric data from members of the public who are not our users and never agreed
  to anything. The enforcement layer is proportionate to that, not to the line count.
- **"Verify, never assert" caught me twice on my own claims.** I once reported a push as
  successful having captured `echo`'s exit code rather than git's — the push had been refused
  by the pre-push hook. I also nearly reported a crash that was routine UIKit
  `BackgroundTask` assertion noise while the process was alive.
- **The mirror seam cost about twenty lines and was violated within one commit** — by my own
  spike, which read `frame.camera.transform` directly. The rule is now *counted*: exactly one
  read, and it must carry the `ADR-006-seam` marker.

---

## 3. Roadblocks

Ordered by how much they threaten the project.

### R-1. The spike was never validated by a human, and this is the live blocker

**This is where the project stopped.** The app is installed on `AG` and the last report from
the founder was that it "has still the same issue" — with the specific symptom not captured
before the session ended. Four candidate symptoms were on the table and none was confirmed:

1. UI zoomed and clipped off the left edge (the launch-screen bug; the built `Info.plist`
   **does** contain `UILaunchScreen`, so this should be fixed and its recurrence would mean
   something else is wrong).
2. App launches then immediately exits.
3. App opens but the camera is black or blank.
4. The R-DEGRADE "cannot run the try-on" screen appears, which on an iPhone 16 Pro Max would
   mean the capability gate is wrongly returning false.

**The prime suspect, untested:** the build on the phone is a **debug-dylib** build — a 91KB
launcher stub plus `salon-ar.debug.dylib`, which is Xcode 26's default and is designed to be
launched *by Xcode*. Tapping the icon on the home screen is the flakiest way to run one. The
first action on resuming is to build **Release** (`-configuration Release`), which produces
one self-contained binary, reinstall, and see whether the symptom survives. The project was
regenerated and ready for exactly this when work stopped.

Behind that sits the question the spike exists to answer and which no machine can answer:
**does the mass stay glued to the head when you turn quickly, or does it drift and lag?**
If it holds, ARKit alone is enough and Phase 1 is purely about occlusion. If it swims, the
plan changes shape.

### R-2. Realism is unproven and it is the project's largest risk

`docs/PROTOTYPE-REALISM.md` specifies a week-one **offline composite test**: 20 subjects in
real salon light, deliberately including **dark hair on dark backgrounds, heavily textured
hair, and long-hair-to-bob** (the hardest removal case). It exits GO, GO-ADDITIVE-ONLY, or
NO-GO. **It has not been run**, because it needs a salon and 20 people.

Compounding it, **D-007**: that test is deliberately unconstrained and does not use the
production pipeline, so it proves the ceiling is high enough without proving that ADR-004's
parameterised cards reach it. Second-largest risk in the project.

### R-3. Q-BAR is blank on purpose and stays blank until the salon fills it (D-005)

The realism threshold has no value. This is deliberate: it is set by the salon partner
**before** they see any result, because a bar set afterwards is a rationalisation. It is a
roadblock in the sense that nothing can be declared good enough until someone sets it.

### R-4. No iPad exists (D-001)

ADR-002 claims an iPad matrix that has never touched hardware. One iPhone is attached to the
build machine. **Every iPad claim in ADR-002 is marked unproven** and must stay marked until
the salon visit, where the salon's own iPad is the device that actually matters.

### R-5. Hair texture provenance is unresolved (D-003)

"No artist, no budget" forced a generative asset pipeline. Whether generated hair textures
are commercially usable has not been established. **This must be resolved before any
commercial use, not after.**

### R-6. The AR device tests can never run in CI (D-008)

Physics, not laziness. GitHub runners have no iPhone and face tracking does not exist in the
simulator. The device lane runs locally against `AG` and its output is pasted into the phase
evidence pack. **CI is explicitly not the gate for anything AR**, and the `salon-arDeviceTests`
target does not exist yet — the DoD correctly reports it missing.

### R-7. No crash reporting on the AR path (D-004)

Accepted, not closing. ADR-005 forbids any SDK capable of capturing a screen or view
hierarchy, which rules out every mainstream crash reporter. Field diagnosis is genuinely
harder and that is the price of the privacy position. Any change is a new ADR.

### R-8. Competitor reset behaviour is unverified (D-006)

Style My Hair, My Hair [iD] and YouCam for Business. Research could not determine it from
public sources and correctly declined to guess. Reset between customers is our most
safety-critical interaction and the only place competitor behaviour would genuinely inform
ours. Needs someone to install all three and drive them by hand.

---

## 4. Next steps

### Immediately, on resuming

1. **Build Release and reinstall.**
   ```
   cd ~/dev/misc/salon-ar && export PATH=/opt/homebrew/bin:$PATH
   xcodegen generate
   xcodebuild -project salon-ar.xcodeproj -scheme salon-ar \
     -configuration Release -destination 'id=56539B14-F867-5EAE-AE4D-AD3C881F47E6' \
     -derivedDataPath /tmp/dd-rel build
   xcrun devicectl device install app --device AG \
     /tmp/dd-rel/Build/Products/Release-iphoneos/salon-ar.app
   ```
   This eliminates the debug-dylib suspect in one move.

2. **Capture the actual symptom**, in a screenshot or a sentence, rather than relaying it.
   Everything downstream is guesswork until this exists. If the app launches, capture the
   device console during launch: `xcrun devicectl device console --device AG`.

3. **Get the tracking answer.** Turn the head slowly, then fast. Drift or no drift. This is
   the gate on whether ARKit alone carries the product.

4. **Merge PR #4** once the spike has served its purpose. It is three commits and has been
   sitting open.

### Then, Phase 1 as planned (`docs/PLAN.md`)

- The **skull-and-ear head proxy**, rendered **depth-only** with colour write off (ADR-003).
  This is where the crude mesh stops clipping through ears.
- The **hairline by feathering, not geometry** — a hard geometric edge at the forehead reads
  as a wig every time.
- The **`salon-arDeviceTests` target**, which the DoD currently reports as missing. It hosts
  the occlusion sweep, head pose, calibration latency, session teardown and idle reset
  Confirmations, all of which are PENDING purely because this target does not exist.
- **Maestro** is already installed at `~/.maestro/bin/maestro` and earns its place here,
  driving the yaw/pitch occlusion sweep on the device.

### Blocked on the salon, and none of it blocks a phase, all of it blocks ship

- The visit itself, with 20 subjects including the three hard cases.
- **Q-BAR set before any composite is shown.**
- The stylist's verdict on whether a 2–4 second freeze pause is acceptable in a real chair.
- An iPad, any iPad, to close D-001.

---

## 5. Things not to undo

Written down because each one looks like overhead to someone arriving fresh, and each one
exists because something went wrong without it.

1. **`scripts/confirmations.tsv` has two states and no third.** A Confirmation that is
   neither ACTIVE nor PENDING is a boundary nobody is holding.
2. **`scripts/verify-checks-bite.sh` is not optional and not slow enough to matter.** Nine
   vacuous checks is what its absence looks like.
3. **The symbol floor of 200 in the `nm` check.** Removing it makes the check pass on a
   launcher stub, which is to say on anything.
4. **`gg`/`gg_code` and `assert_grep_engine`.** Never reach back to plain `git grep -E` for a
   word-boundary pattern.
5. **The ADR-006 seam is counted, not documented.** A second `ADR-006-seam` marker fails the
   build. Two seams is how the mirror port turns back into a rewrite.
6. **`project.yml` is the only source of truth for the plist.** Do not hand-write
   `Sources/App/Info.plist`; XcodeGen will overwrite it silently and the app will ship with
   no camera string.
7. **R-NOJUDGE.** `scripts/lint-nojudge.sh` guards the founder's instruction that the product
   **shows, it does not rank**. No copy anywhere tells a person a haircut does not suit their
   face. If recommendation is ever built it is designed with the stylist in the loop, not
   delivered as a verdict from a machine.
8. **ADR-005 as written.** Nothing leaves the device, nothing is written to disk, the session
   dies with the customer. The binary currently carries **4586 symbols across 13 Mach-O files
   with zero networking**, and camera is the only declared permission. Both facts are checked
   on every run, and both were verified rather than asserted.

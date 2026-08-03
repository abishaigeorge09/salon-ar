# ADR-005 — Biometric data

- **Status:** Accepted
- **Date:** 2026-08-04
- **Serves:** R-NOLEAK, R-RESET
- **This ADR is the reason the project is FULL tier.**

## Context and problem statement

Face geometry is biometric data under GDPR Article 9 and under US state biometric law (Illinois
BIPA, Texas CUBI, Washington HB 1493). The subject is a salon customer: someone who did not
download the app, has no account, has no relationship with us, and agreed to nothing.

The founder's stated position: *nothing leaves the device, nothing is written to disk, the
session dies with the customer. If any frame is ever uploaded, that is a separate explicit
decision with consent attached, not a default.*

**That position is correct and is not being argued with. This ADR tightens it and makes it
enforceable.**

## Why the position needed tightening, not weakening

"Nothing leaves the device" is too weak as written, because it is fully satisfied by an
application that writes every customer's face mesh to local storage and keeps it forever. Local
retention of biometric data from non-consenting members of the public is the incident. Egress is
only one of the ways it happens.

## Decision outcome

### The rule

No camera frame, no pixel buffer, no `ARFaceGeometry`, no blend-shape coefficients, and no
derived embedding is:

- transmitted anywhere, or
- **written to disk**, or
- included in a crash report, log, or diagnostic bundle, or
- **held past the end of the session**.

Session state lives in memory only and is zeroed on customer change.

### Concrete constraints that follow

- **No analytics or crash SDK capable of capturing a screen or a view hierarchy.** This
  excludes most of the market's default choices, deliberately.
- **No Photos permission requested.** The app never enumerates or writes the library.
- **Saving a look is a share sheet the customer invokes.** It goes to *their* Photos, because
  they asked, in an action they took. We store nothing and see nothing.
- **Camera usage description in plain salon language**, written for a customer glancing at a
  stylist's iPad, not for a lawyer.
- **No face data in any persisted state restoration.**

### R-RESET, and why it is a safety control

The brief's "back to back by strangers all day on one shared device" makes the reset a
**biometric control, not a convenience feature**:

1. An **unmissable end-session action** that tears the session down and zeroes buffers.
2. An **idle timeout that does it anyway**, because the stylist is mid-conversation with a
   person in their chair and will forget. Designing on the assumption that they will remember
   is designing for a stylist who does not exist.
3. Reset is **destructive and immediate**, not a navigation transition that leaves state alive
   behind a screen.

### Mirror-mode note

The mirror version (ADR-006) makes this harder, not easier: a fixed always-on display in a salon
sees people who never sat down and never looked at a consent screen. That is a materially
different legal posture and it gets its own ADR when the time comes. It is called out here so
the constraint is inherited rather than rediscovered.

## Considered and rejected

- **Cloud inference for better quality.** Would meaningfully improve freeze-mode results. Sends
  a member of the public's face to a server. Rejected, and per the founder's instruction any
  reversal is a separate explicit decision with consent attached.
- **On-device cache of the session for undo or compare.** Convenient, and it is a biometric
  database on a shared salon iPad. Rejected. Compare works from live re-render, not from stored
  frames.
- **Opt-in retention with a consent screen.** Rejected for v1. A consent screen presented by a
  stylist to a seated customer is not meaningfully free consent, and there is no product reason
  to retain anything.

## Consequences

- **Good:** the legal posture is close to the simplest one available. No biometric data at rest,
  no transfer, no retention schedule, no subject-access mechanism to build, no breach surface.
- **Good:** the constraint improves the product. It forces a fast reset, which the shared-device
  reality needed anyway.
- **Bad:** no crash reporting on the AR path, so field diagnosis is genuinely harder. Accepted.
  Mitigated by metric-only local logging that provably contains no image or geometry data.
- **Bad:** freeze-mode quality is capped by on-device compute, permanently.

## Confirmation

The first check here is the one that genuinely bites, and it is why this ADR is enforceable
rather than aspirational.

| Check | Command | Asserts |
|---|---|---|
| **Uploading is not expressible** | `scripts/security-invariants.sh` | Runs `nm` over the built AR module and asserts **no networking symbol is linked at all** — no `URLSession`, no `Network`, no `CFNetwork`, no third-party SDK. Not a policy that data is not uploaded: a binary in which uploading cannot be written. |
| Nothing written to disk | `scripts/verify-no-image-persistence.sh` | No write path for image, pixel-buffer, or geometry data anywhere in the AR module. Fails on `FileManager`, `Data.write`, and cache APIs reachable from frame handling. |
| Buffers are actually zeroed | `xcodebuild test -only-testing:ARTests/SessionTeardownTests` | After reset, session buffers are nil and the retained-object graph holds no `ARFrame`, `CVPixelBuffer`, or `ARFaceGeometry`. Asserts the object is gone, not that a flag was set. |
| Idle timeout fires | `xcodebuild test -only-testing:ARTests/IdleResetTests` | With no interaction for the timeout period, teardown runs unprompted and passes the same assertions. |
| No screen-capturing SDKs | `scripts/verify-no-analytics.sh` | Dependency graph contains no analytics, session-replay, or crash SDK. |
| Permissions are minimal | `scripts/verify-entitlements.sh` | `Info.plist` requests camera only. No Photos, no location, no network entitlement. |

Any future frame upload is therefore not a configuration change. It is a **linker change**, a
new ADR, and a consent flow. That is the friction the founder asked for, made structural rather
than procedural.

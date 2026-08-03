# ADR-002 — Face tracking approach and the device matrix

- **Status:** Accepted
- **Date:** 2026-08-04
- **Serves:** R-LIVE, R-CALIB, R-DEGRADE

## Context and problem statement

The style must hold from every angle as the customer turns their head. That needs a real head
**pose**, not a set of 2D points. A salon owns whatever iPad it already bought, so the device
matrix is a commercial constraint, not a technical footnote: if the answer is "buy a new iPad",
the product does not get used.

## A premise in the brief is wrong, in our favour

The brief assumed ARKit face tracking requires a TrueDepth (Face ID) camera. **It has not since
iOS 14.** `ARFaceTrackingConfiguration` runs on any device with a front-facing camera and an
**A12 Bionic or later**, TrueDepth or not — the requirement moved from the depth sensor to the
Neural Engine. TrueDepth was the gate on iOS 13 and earlier only.

This materially widens the supported set and removes the main reason to consider a 2D fallback.

## Considered options

1. **Vision 2D landmarks only.** Runs on everything. Gives points on a plane, no pose, no
   depth. A style rendered from 2D landmarks slides and swims the moment the head rotates,
   which is the exact promise of the product. **Rejected as a primary path.**
2. **ARKit face tracking, TrueDepth devices only.** Based on the brief's premise. Needlessly
   excludes every A12+ non-TrueDepth iPad. **Rejected as factually unnecessary.**
3. **ARKit face tracking with an A12 floor and a runtime capability check.** **Chosen.**
4. **ARKit with a Vision 2D degraded mode on old devices.** Rejected for v1: it doubles the
   render paths to serve devices on which the product's core promise cannot be kept, and a
   sliding overlay damages trust more than an honest "this iPad is too old" screen.

## Decision outcome

**ARKit `ARFaceTrackingConfiguration`, A12 Bionic floor, gated at runtime by
`ARFaceTrackingConfiguration.isSupported` rather than by a hard-coded device-model allowlist.**

A model allowlist rots on every hardware release and silently excludes devices that would work.
The capability check is what Apple actually guarantees.

### Device matrix

Stated explicitly, in and out, because the salon's existing hardware decides adoption.

**Supported**

| Family | Floor |
|---|---|
| iPhone | XS, XS Max, XR and later |
| iPad Pro | 11-inch all generations; 12.9-inch 3rd generation and later |
| iPad Air | 4th generation and later |
| iPad mini | 5th generation and later |
| iPad (base) | 8th generation and later |

**Not supported**

iPhone X and earlier. iPad 7th generation and earlier. iPad Air 3 and earlier. iPad mini 4 and
earlier. Every non-Pro iPad before 2020.

TrueDepth devices additionally provide a true depth map and are **preferred, not required**.
Where present it improves the head-proxy fit in ADR-003; where absent the mesh still comes from
ARKit.

### Calibration

**[R-CALIB]** Seconds, gesture-free, no wizard. The category norm — IKEA Place's few-second
surface wave, AR Quick Look's implicit detection — is a short automatic lock-on, not a
multi-step onboarding. A customer is sitting in a chair being watched by a stylist; a setup
flow is a humiliation. ARKit acquires a face anchor in well under a second in normal lighting;
the UI shows a lock-on state and nothing else.

### Unsupported devices

**[R-DEGRADE]** A written explanation naming the device requirement in plain language. Never a
crash, never a black camera, never a frozen frame. The stylist must be able to read the screen
and know it is the iPad and not them.

## Consequences

- **Good:** a much wider salon install base than the brief assumed, and no device allowlist to
  maintain.
- **Good:** one render path, one pose source, one set of bugs.
- **Bad:** a salon on an iPad 7 or older cannot use the product at all, and there is no degraded
  mode to sell them. That is a deliberate choice: the honest no is better than a sliding overlay.
- **Risk, recorded in `docs/DEBT.md`:** no iPad exists for development testing. The iPad half of
  this matrix is **claimed and not proven**. It is not called verified, and the salon visit is
  the first real chance to close it.

## Confirmation

| Check | Command | Asserts |
|---|---|---|
| Matrix does not drift from code | `scripts/verify-device-matrix.sh` | The table above is generated from the same constant the runtime gate reads. The doc cannot fall out of step with the binary. |
| Unsupported path is not a crash | `xcodebuild test -only-testing:ARTests/UnsupportedDeviceTests` | With capability forced false, the app presents the explanation screen, does not initialise a session, and does not crash. |
| Pose is real, not 2D | `xcodebuild test -only-testing:ARTests/HeadPoseTests -destination 'platform=iOS,name=AG'` | A yaw sweep on device produces a monotonically changing 6DoF transform. Device only — face tracking does not exist in the simulator, so a green simulator run proves nothing here. |
| Lock-on speed | `xcodebuild test -only-testing:ARTests/CalibrationLatencyTests -destination 'platform=iOS,name=AG'` | Time from session start to first stable face anchor is within the R-CALIB budget on device. |

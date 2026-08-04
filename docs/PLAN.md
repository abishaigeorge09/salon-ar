# PLAN — Gate 2

Six phases. Each has one gate that can be re-derived from the running system by somebody
who did not build it. Under the founder's autonomy directive of 2026-08-04 these are
present-and-continue rather than stop-and-wait, but the gates still refuse: a phase that
cannot pass its gate does not close, and I do not amend a gate so a phase can pass.

**Device reality governs everything.** AR face tracking does not exist in the simulator, so
every AR claim is verified on `AG` (iPhone 16 Pro Max, A18 Pro) and nowhere else. A green
simulator run on this product is worse than no run.

---

## Ordering, and the one thing that dictates it

Phase 1 is not the camera. It is the **head proxy and occlusion**, because ADR-003 is the
decision most likely to be wrong, and everything downstream renders against it. If the
proxy cannot occlude an ear correctly, twelve beautiful hairstyles are worthless, and I
would rather find that out with one grey test mesh than after the asset pipeline exists.

The asset pipeline (Phase 3) deliberately comes after occlusion is proven, for the same
reason: styles are cheap to regenerate and occlusion is not.

Freeze mode (Phase 5) is last of the build phases because it is the only one that can be
**cut entirely** — if the salon rejects the pause, or the composites fail, ADR-001 falls
back to additive-only knowingly. Everything before it ships without it.

---

## Phase 1 — Face tracking, head proxy, occlusion

Serves R-LIVE, R-CALIB, R-DEGRADE. Implements ADR-002 and ADR-003.

Builds the ARKit session, the capability gate, the unsupported-device path, the
skull-and-ear proxy fitted from landmarks, and depth-only occlusion. Renders one grey
placeholder hair mesh — deliberately ugly, so nobody mistakes this phase for a product.

Also lands `ViewpointProvider` (ADR-006) from the first commit, because the seam is cheap
now and a rewrite later.

**Gate:** on `AG`, a yaw and pitch sweep produces **zero hair-coloured pixels inside the
face silhouette and inside both ear regions**, captured as frames and diffed against
approved baselines. Plus: capability gate returns true on `AG`; forcing it false shows the
written explanation and does not crash; lock acquired within the R-CALIB budget.

**Confirmations moved ACTIVE:** `head-pose-is-6dof`, `calibration-latency`,
`device-matrix-parity`, `unsupported-not-crash`, `occlusion-sweep`, `head-proxy-fit`,
`render-baselines`, `off-axis-viewpoint`.

**Model tier:** Opus. This is the hardest geometry in the project and the phase everything
else is built on top of.

---

## Phase 2 — The one screen, wired to the real session

Serves R-LIVE, R-HONEST, R-RESET, R-NOLEAK. Implements ADR-005 and the IA map.

Replaces the kitchen sink with the actual screen: live camera full bleed, lock indicator
driven by real ARKit state, honesty note, carousel and categories bound to real styles,
capture button, End and erase, idle timeout, Session erased takeover.

The components already exist and are approved. This phase is wiring, not design.

**Gate:** the ADR-005 teardown assertions pass on device — after reset the retained object
graph holds no `ARFrame`, `CVPixelBuffer` or `ARFaceGeometry`, asserted as *object absent*
rather than *flag set*. Idle timeout fires unprompted and passes the same assertions.
`nm` on the device binary still links no networking symbol.

**Confirmations moved ACTIVE:** `session-teardown`, `idle-reset`.

**Model tier:** Sonnet. Wiring known components to a known session against a written IA
map. Opus would be paying for judgement that has already been exercised.

---

## Phase 3 — The asset pipeline

Serves R-STYLES. Implements ADR-004.

One shared skull-cap base aligned to the Phase 1 proxy. Generated hair texture sheets with
alpha. A **parameterised, scripted** card layout driven by one config row per style
(length, volume, part, curl, layering, fringe). Exports USDZ under a size budget.

Ships 8–12 styles, **all additive**, because additive is what live mode can honestly render.

**Gate:** `scripts/build-styles.sh` builds every style from config with no hand-placement
anywhere; `styles built == config rows`; **adding a style is one config row and one texture
sheet, demonstrated by actually adding a thirteenth during the gate** rather than asserted.
Every style aligns to the proxy origin within tolerance.

**Confirmations moved ACTIVE:** `styles-build-from-config`, `hundredth-style-is-free`,
`style-alignment`.

**Model tier:** Sonnet for the pipeline scripting; Haiku for the repetitive per-style config
generation, which is mechanical.

---

## Phase 4 — Realism

Serves the risk that makes everything else worthless. Implements ADR-003's degradation.

Ambient light sampling, then deliberately degrading the render to match the camera: grain,
motion blur, depth of field. Apple ships this in AR Quick Look on purpose — a perfectly
clean render against a noisy camera feed is precisely what "pasted on" looks like.

Also the low-resolution segmentation mask as a soft occlusion hint, so the customer's own
flyaway strands read as in front of the style where they should be. This is what separates
a composite from a hat.

**Gate:** `ux-critic` walks the real render on device and the degradation parameters are
non-zero and tracked to measured camera values. **This gate is partly subjective and that
is stated rather than hidden**: a pixel test cannot tell you something looks pasted on.
Sign-off is a human looking at a real face on a real device.

**Confirmations moved ACTIVE:** `camera-match-degradation`, `segmentation-iou` (live path).

**Model tier:** Opus. Judgement about whether something looks real is exactly what a
cheaper model is bad at.

---

## Phase 5 — Freeze mode *(cuttable)*

Serves R-SHORTER. Implements the second half of ADR-001.

Single high-resolution capture, hair segmentation at full resolution, removal, composite of
the target style. **Masked-region-only**: pixels outside the dilated hair mask are carried
through byte-identical from the source frame. Not "preserved well" — not touched.

**Gate:** `scripts/verify-identity-preservation.sh` over a fixed corpus asserts the output
outside the dilated mask is **bit-identical** to the input. One changed pixel on a cheek
fails. Segmentation IoU at or above threshold, **scored per subset** — the textured-hair and
dark-on-dark subsets scored separately, so a good average cannot hide a broken subset.

**This phase is cut, not deferred, if:** the salon reports the 2–4s pause reads as broken,
or the week-one composites fail on removal. ADR-001 then falls back to additive-only
knowingly, which the founder has already said is acceptable.

**Model tier:** Opus. The identity-preservation constraint is subtle and the failure mode is
insulting a customer.

---

## Phase 6 — Hardening and ship

Security red team on the full diff via the `claude-security` skill, findings to its patch
flow. Thermal and battery behaviour under continuous AR on a salon device. Back-to-back
session soak: fifty sessions in sequence with teardown asserted between each.

**Gate:** fifty consecutive sessions with no memory growth and teardown assertions passing
every time; red-team findings closed or explicitly deferred with an owner; the full
confirmations registry showing **zero PENDING rows without a trigger**.

**Model tier:** Opus for red team, Haiku for the soak harness.

---

## Contracts settled before any UI

- `ViewpointProvider` is the only source of the render viewpoint. Nothing reads the AR
  camera transform directly (ADR-006, enforced).
- The head proxy origin is the shared coordinate frame for every style asset.
- Style config schema is fixed at Phase 3 and additive-only thereafter.
- Session state lives in one object with one teardown path. There is no second way to
  destroy a session, because a second path is a path somebody forgets to call.

## Founder input needed, batched

Nothing here blocks a phase. Everything here blocks *shipping*.

| # | Needed | Blocks |
|---|---|---|
| 1 | The salon visit: 20 subjects, real lighting, including dark-on-dark, textured hair, and long-hair-to-bob | The week-one realism test, and therefore Phase 5's go/no-go |
| 2 | Q-BAR filled in **before** any composite is shown | The realism exit decision |
| 3 | A stylist's answer on whether a 2–4s freeze reads as working or broken | Whether Phase 5 exists |
| 4 | Any iPad | The whole iPad half of ADR-002 (D-001) |
| 5 | Hair texture provenance for commercial use (D-003) | Ship, not build |

## Risks, ranked

1. **Realism.** The only risk that makes everything else worthless. Mitigated by testing it
   offline and unconstrained before building, so a NO-GO costs a day.
2. **The pipeline may not reach the realism ceiling** (D-007). The week-one test proves the
   ceiling is high enough; it does not prove parameterised cards reach it. Phase 3's real
   job.
3. **The proxy is an approximation.** Unusual head shapes will show artefacts. The yaw sweep
   keeps it from getting quietly worse; it does not make it perfect.
4. **No iPad.** A whole device family claimed and unproven. Recorded, not assumed away.
5. **Thermals.** Continuous AR on a shared device all day is a real salon condition and no
   competitor documentation covers it.

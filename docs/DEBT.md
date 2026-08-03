# DEBT

Known gaps, each with an owner and a trigger. A check that should apply but cannot run is a
failure, not a skip, and it is recorded here rather than assumed away.

| # | Gap | Why it exists | Owner | Trigger to close |
|---|---|---|---|---|
| D-001 | **No iPad exists for development testing.** ADR-002 claims an iPad matrix that cannot be proven on hardware. The iPad lane is **not called verified.** | One iPhone (`AG`) is attached to the build machine. No iPad, of any generation. | Founder | The salon visit. The salon owns an iPad and it is the exact device that matters. Until then every iPad claim in ADR-002 is marked unproven. |
| D-002 | **CI cannot block on a private repo on the free GitHub plan.** | Required status checks are a paid feature on private repositories. | Me | `.git/hooks/pre-push` is installed by `project-bootstrap` as the stand-in. Closes if the repo goes public or the plan is upgraded. "CI exists" must never be allowed to stand in for "CI blocks". |
| D-003 | **Generated hair texture provenance is unverified.** ADR-004 produces texture sheets generatively; commercial usability has not been established. | No artist and no budget forced a generative pipeline. | Founder | Before ship. Must be resolved before any commercial use, not after. |
| D-004 | **No crash reporting on the AR path**, by design. Field diagnosis is genuinely harder. | ADR-005 forbids any SDK capable of capturing a screen or view hierarchy. | Accepted, not closing | Reviewed only if field failure rate becomes unmanageable, and any change is a new ADR. |
| D-005 | **Q-BAR is blank.** The realism threshold has no value yet. | Deliberate. It is set by the salon partner before they see any result; a bar set afterwards is a rationalisation. | Salon partner | Filled in at the start of the week-one salon visit, before any composite is shown. |
| D-006 | **Reset behaviour of the three closest precedents is unverified.** Style My Hair, My Hair [iD], YouCam for Business. | Research could not determine it from public sources and declined to guess. | Me | Install and drive each by hand. This is our most safety-critical interaction and the only place competitor behaviour would genuinely inform ours. |
| D-007 | **The ADR-004 pipeline is not proven to reach the realism ceiling.** The week-one test proves the ceiling is high enough; it does not prove parameterised cards reach it. | The test is deliberately unconstrained and does not use the production pipeline. | Me | First build phase. This is the second-largest risk in the project after realism itself. |

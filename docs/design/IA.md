# Information architecture — Gate 1b

The kitchen sink made visual rejection cheap. This makes navigation rejection cheap, which
nothing did on the last large build, where two of five founder complaints were information
architecture rather than visuals.

One page: every screen, what reaches it, what it contains, and the main task path from a
cold start.

---

## The shape, and why it is this shape

**There is one screen.** Everything else is a state of it or a sheet over it.

That is a decision, not an omission. The camera is the product; a customer is sitting in a
chair being looked at, and any navigation the stylist has to perform is time spent looking
at a phone instead of at the person. Every competitor examined converges on the same
answer: full-bleed camera, chrome measured in single-digit percent of frame.

The corollary is that **there is no home screen, no menu, and no settings**. Nothing to
navigate to means nothing to get lost in.

```
                         cold start
                             │
                    ┌────────▼────────┐
                    │  Camera permission │   once per device install, never again
                    └────────┬────────┘
                             │ granted            denied ──► Permission refused (dead end,
                             │                                 explains, offers Settings)
                    ┌────────▼────────┐
                    │  Capability gate │   ARFaceTrackingConfiguration.isSupported
                    └────────┬────────┘
                             │ supported          unsupported ──► Unsupported device
                             │                                     (dead end, plain language)
        ╔════════════════════▼════════════════════════════════════════╗
        ║                    T H E   O N E   S C R E E N               ║
        ║                                                              ║
        ║   states:   searching ──► holding ──► lost ──► holding       ║
        ║                                                              ║
        ║   always visible:  live camera (full bleed)                  ║
        ║                    lock indicator                            ║
        ║                    honesty note (R-HONEST)                   ║
        ║                    style carousel + categories               ║
        ║                    capture button                            ║
        ║                    End and erase                             ║
        ╚═══╦══════════════════╦══════════════════╦═══════════════════╝
            │                  │                  │
   hold capture         tap Now/After        idle 90s / End
            │                  │                  │
      ┌─────▼─────┐      ┌─────▼─────┐      ┌─────▼──────┐
      │  Freeze   │      │  Now/After│      │  Session    │
      │  result   │      │  split    │      │  erased     │
      │  (sheet)  │      │  (state)  │      │  (takeover) │
      └─────┬─────┘      └─────┬─────┘      └─────┬──────┘
            │                  │                  │
       dismiss ──────────► back to the one screen ◄─── tap to start fresh
```

---

## Every screen

### 1. Camera permission
**Reached by:** cold start, first install only.
**Contains:** the system prompt, preceded by nothing. No pre-permission explainer screen —
the usage string carries the explanation, and a customer watching a stylist tap through an
onboarding wizard is a worse experience than one extra sentence in a system dialog.
**Leaves to:** the one screen, or the dead end below.

### 2. Permission refused *(dead end)*
**Reached by:** denying camera, or a previously-denied device.
**Contains:** one sentence of plain language and a button to Settings. No retry loop, no
persuasion.

### 3. Unsupported device *(dead end)*
**Reached by:** `ARFaceTrackingConfiguration.isSupported == false` (ADR-002).
**Contains:** the device requirement in plain language, and an explicit statement that
nothing is wrong with their setup. **Never a crash, never a black camera** (R-DEGRADE).
**Leaves to:** nowhere. This is honest: there is no degraded mode, because a sliding 2D
overlay damages trust more than an honest no.

### 4. The one screen
**Reached by:** everything. It is the app.

| Element | Present when | Note |
|---|---|---|
| Live camera, full bleed | always | The product |
| Lock indicator | always | searching / holding / lost. The entire calibration UI |
| Honesty note | always in live mode | R-HONEST. Never dismissible |
| Category tabs | always | Length, Volume, Fringe, Texture |
| Style carousel | always | Circular thumbnails. Never ranked (R-NOJUDGE) |
| Capture button | when holding | Tap = still. Hold = freeze and remove |
| Now/After toggle | when a style is selected | Enters the split state |
| End and erase | always | R-RESET. Never scrolled off, never behind a menu |

**Why the carousel is always visible rather than behind a button:** browsing is the
conversation. Hiding styles behind a control means the stylist taps to open, taps to
choose, taps to close, three times per style, while a person waits.

### 5. Freeze result *(sheet over the one screen)*
**Reached by:** press and hold the capture button.
**Contains:** the composited still, permanently labelled **Simulated**, the style name, and
the sentence that turning your head returns to live. Share and Discard.
**Leaves to:** the one screen on dismiss. **The frame is destroyed on dismiss** — it is not
kept for a gallery, because a gallery of customers' faces is a biometric database
(ADR-005).

### 6. Now/After split *(state of the one screen, not a screen)*
**Reached by:** tapping the Now/After control.
**Contains:** live camera on both halves; left renders nothing, right renders the style.
Both live, both the same person, same instant.
**Why it is a state and not a screen:** it must be enterable and leavable without losing
the face lock. A navigation transition would drop the AR session and force
recalibration in front of a waiting customer.

### 7. Session erased *(full takeover)*
**Reached by:** End and erase, or the idle timeout, or backgrounding the app.
**Contains:** confirmation that the session is gone, and a single tap to start fresh.
**Why a takeover and not a toast:** on a shared device used by strangers back to back, the
next customer must be able to see, without asking, that the previous person is gone. A
toast that fades is not evidence. It is also the only screen that is deliberately *slow* to
leave — a moment of nothing is the point.

---

## The main task path, cold start to agreement

Seven steps, four of them taps.

1. Stylist opens the app. **Camera live, lock acquired in under a second.**
2. Hands the phone to the customer, or holds the iPad up.
3. Customer or stylist taps a category. *(tap 1)*
4. Taps a style. It renders. They turn their head; it holds. *(tap 2)*
5. **The honesty note has already told them this adds and cannot remove.** If they want to
   see shorter, hold the capture button. *(tap 3, held)*
6. Freeze result, labelled Simulated. They discuss it. Dismiss.
7. They agree. Stylist taps **End and erase**. *(tap 4)*

No screen is more than one action from the camera. Nothing is nested. There is no back
button anywhere in the product, because there is nowhere to go back to.

---

## What is deliberately absent

Each of these is a thing a reviewer will ask for, so the reason is recorded now rather than
argued later.

| Absent | Why |
|---|---|
| Home screen | Nothing to put on it. The camera is the app |
| Settings | Nothing to configure. Every setting is a decision we should have made |
| Saved looks / gallery | A gallery of customers' faces is a biometric database (ADR-005). Sharing replaces storing, exactly as Warby Parker does |
| Accounts, sign-in | The person whose face is processed has no relationship with us, by design |
| Favourites | Requires identity, which requires accounts |
| Search | Twelve styles. Search is for catalogues, and the brief says this is not one |
| Undo | Would require keeping the previous frame, which is retention |
| Onboarding / tutorial | A customer in a chair being watched will not sit through it. The lock indicator is the tutorial |
| Recommendations | R-NOJUDGE. Not deferred, refused |
| Back button | Nothing is nested |

---

## The two risks this map carries

**The carousel competes with the face.** It is always visible and it sits over the person's
shoulder in frame. `Tokens.maxChromeFraction` caps chrome at 28% of the frame, but that is a
number I chose and it is untested against a real customer at a real chair distance. **First
thing to check on the real device with a real face in frame.**

**Freeze mode is a mode, and modes get lost in.** The user is in a sheet while the live
session is still running underneath. If dismissal is ever unclear, a stylist ends up
holding a frozen photo of a customer while the customer moves. Mitigation: the sheet is
dismissible by any downward drag, and it dies automatically if the face lock is lost for
more than three seconds.

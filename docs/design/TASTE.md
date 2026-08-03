# TASTE — references, with what is specifically good about each

Gathered by research rather than supplied, at the founder's direction. A link with no note is
worthless in three weeks, so every entry says what to take and what to leave.

Standing rule: **no direction is proposed cold.** Everything below is anchored to a product
that exists.

---

## The two salon-facing precedents, which are the rarest and most useful

### L'Oréal Style My Hair — the closest thing that exists to this product

Stylist-operated, live camera, on a client seated in the chair. The exact scenario.

**Take:** the operating model is validated. A stylist holding a device up to a seated customer
is a thing that already happens commercially, so we are not inventing the ritual, only the
capability. Live AR with continuous tracking, not photo-and-adjust.

**Leave, and note carefully:** it does **colour only, never silhouette**. It never changes the
shape of anyone's hair, which is precisely how it avoids the problem in ADR-001. The closest
precedent to us succeeded by declining our hardest problem. That is worth remembering when the
schedule gets tight.

### L'Oréal My Hair [iD] — professional consultation tool, iPad-first

**Take:** a genuine stylist-facing consultation surface with a catalogue layer alongside the
client-facing try-on. Confirms iPad as a first-class salon device.

**Leave:** rated 3.8 on a thin review base, with complaints that a recent update made photo
upload harder. The lesson is the category-wide one: **professional tools get less UI investment
than consumer ones and it shows.** A salon tool that feels as considered as a consumer app is
itself a differentiator, because the bar is low.

### Perfect Corp YouCam for Business — the only retail kiosk precedent found

**Take:** it is the only product examined with a real operator layer — a separate console for
management plus analytics. Confirms that a shared-device retail AR product needs an operator
surface, which for us is the R-RESET session control rather than a CMS.

**Leave:** the whole back-office. We have no accounts and no cloud, and the analytics layer is
directly forbidden by ADR-005.

**Unverified:** whether any of these three has a reset-between-customers flow. The research
could not determine it and did not guess. Given the biometric posture, ours will be more
visible than theirs regardless.

---

## Consumer hair try-on, mostly as a catalogue of what to avoid

### ModiFace Haircut

Camera capture feeds a **still-frame overlay the user then manually positions** with size and
rotation handles. Reviewers note styles do not adjust to face size and each must be fitted by
hand.

**Take:** nothing about the interaction. **Leave:** all of it. This is the user doing the work
the system should do, and it is the clearest illustration of why real tracking is the product.

### YouCam Makeup

**Take:** the only confirmed **split-screen before/after** in the category, and genuinely
deeper controls than competitors (shine, coverage, blending). Both live AR and still modes with
a toggle, which is structurally similar to our live/freeze split and worth studying for how the
mode switch is presented.

### hano.ai, HairApp, the Aura family

Still-photo generative. Upload, wait, receive.

**Take:** nothing. **Leave:** all of it, and specifically the monetisation — hano.ai blocks the
result behind a paywall *after* the user has taken and reviewed their photo, and HairApp's
reviews are dominated by billing complaints rather than quality ones.

**The one genuinely valuable finding in this group** is a user review of Aura: the result *"turns
me into a whole new person"*. **Identity drift.** It is a worse failure than a visible seam and
it is specific to generative pipelines. It is the direct source of the byte-identical constraint
in ADR-001 and it is the strongest argument for staying overlay-based, since an overlay
structurally cannot alter a face that is live camera feed.

### Hair AI

One of the better-reviewed in the category, and its praise is diagnostic: it "works so well it
looks realistic" and avoids looking like "a silly crooked wig".

**Take:** *"crooked wig"* is the named failure mode of this entire category, in users' own words.
That is the thing to beat, and it is a low bar stated plainly. Another review notes the app
"either took my hair off or fit it well around my hair" — **users can tell which strategy is
running**, which is the empirical case for R-HONEST: they will work it out anyway, so say it first.

---

## Adjacent AR, for interaction conventions

### Warby Parker — the technical bar

ARKit face-mesh anchored glasses, locked to actual facial landmarks through head rotation, with
live material rendering (acetate translucency, metal speculars).

**Take:** this is the bar for "an object anchored to a face that does not swim". Also the flow —
browse catalogue, tap, **swipe down to enter try-on** — and the fact that **screenshot-and-share
IS the compare feature**. No in-app gallery. That fits ADR-005 exactly: sharing replaces storing.

### Lenskart

Full-bleed camera, **horizontal swipe to change product** with an on-screen instruction rather
than a persistent carousel eating the frame. Separate 360° product-only view, decoupled from
try-on.

**Take:** swipe-to-change keeps chrome minimal. The decoupled product view is worth stealing —
a style inspected on a neutral head, separate from wearing it.

**Leave, emphatically:** it opens by analysing your face and recommending frames matched to your
face shape, highlighting "recommended for you" in green. **That is precisely the thing R-NOJUDGE
forbids.** Useful as the clearest example of the pattern we are refusing.

### Apple AR Quick Look — platform conventions and one technique

Minimal chrome: close top-left, share top-right, shutter bottom-centre. **The shutter is
overloaded** — tap for a still, press-and-hold for video. One control, two capture modes.

**Take, as the most valuable single item in this document:** AR Quick Look deliberately
**degrades the synthetic layer** to match the camera — samples ambient light, then adds grain,
motion blur and depth of field so the composite does not look too clean. Apple ships "make the
render worse so it looks real" as a platform behaviour. This is ADR-003's realism mechanism and
it is a shader change rather than a research problem.

### IKEA Place

Camera fills the frame, chrome is nearly absent, and a **single "+" at the bottom** opens the
catalogue. Calibration is a few seconds of gesture-prompted waving with an animated hand icon —
short, visual, no wizard.

**Take:** the calibration norm is seconds and gesture-driven. A customer in a chair being
watched by a stylist will not sit through onboarding (R-CALIB).

---

## The convergent pattern to start from

Every live-AR product examined agrees on this, so it is the baseline rather than a proposal:

- Camera **full-bleed, edge to edge**. Chrome measured in the low single-digit percent of frame.
- Style picker as a **bottom carousel of circular thumbnails**, each showing the style rendered
  on a neutral head rather than as a flat swatch or a word.
- Categories above the carousel. Capture centred below it.
- Close top-left, share top-right, per platform convention.
- Lock-on is a state indicator, not a screen.

## Two things nobody ships, which are ours to take

Both fall directly out of decisions already made, which is the good kind of differentiator —
they cost nothing extra.

1. **A live side-by-side of the customer's real hair against the style.** No product examined
   offers a simultaneous real-versus-style view in one AR frame; YouCam's split-screen is the
   closest and it compares two edits. In a salon this is the *actual* conversation — "this is
   you now, this is you after" — and it is the whole point of the product.

2. **Honest disclosure as a feature.** In a category where every competitor overclaims and the
   users' own words are "crooked wig" and "turns me into a whole new person", stating plainly
   that live mode adds and cannot remove makes us the only trustworthy thing on the shelf.
   R-HONEST turns our hardest limitation into the most credible sentence in the product.

## Still to gather

- Snapchat and TikTok lens carousels: the general bottom-carousel pattern is established, but
  the research could not verify current pixel layout and said so rather than guessing. A
  hands-on screen recording is the fix.
- App Store screenshots: Apple blocked automated fetch (403/404) across every product. Needs
  manual capture from a real browser or the App Store app.
- **Style My Hair, My Hair [iD] and YouCam for Business should be installed and driven by hand.**
  They are the three closest precedents and all three have unverified reset behaviour, which is
  our most safety-critical interaction.

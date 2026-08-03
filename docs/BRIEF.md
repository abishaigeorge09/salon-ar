# BRIEF — AR haircut try-on for salons

**Tier: FULL.** It processes biometric data from members of the public who are not our users
and never agreed to anything.

Every line below is tagged:

- **[STATED]** — said by the founder, verbatim or near it. Not mine to change.
- **[INFERRED]** — my reading of what was stated. Wrong inferences are cheap to correct now
  and expensive later, so they are marked rather than blended in.
- **[PROPOSED]** — mine, new, not derived from anything said. Reject freely.

---

## 1. What it is

**[STATED]** A customer sits in a salon chair. The stylist points an iPad at them, or hands
them an iPhone. The app calibrates to their face, then renders hairstyles onto their head in
real time. They turn their head and the style holds from every angle. The stylist and customer
agree on a cut before scissors touch anything.

**[INFERRED]** The product's value is not the rendering. It is **agreement**. Today the
stylist and the customer reach agreement by looking at a photo of a different person with
different hair, and the disagreement surfaces after the cut, when it is irreversible. The
product succeeds when the two of them are looking at the same thing and both say yes. Every
design decision that follows serves that, not visual spectacle.

**[PROPOSED]** Which means the failure that matters most is not an ugly render. It is a
**confident** render that the cut does not match, because that converts a bad haircut into a
bad haircut we promised. Honesty about what the system cannot show is therefore a feature
requirement, not a legal footnote. See R-HONEST.

## 2. Who it is for

**[INFERRED]** Two users, in the same room, with opposed needs.

| | The stylist | The customer |
|---|---|---|
| Wants | Speed, control, to not look foolish in front of a paying client | To be flattered, and above all not judged |
| Uses it | Many times a day, every day | Once, for a few minutes, ever |
| Tolerance for a wizard | Zero | Some, but they are being watched |
| Owns the device | Yes | No |

**[INFERRED]** The stylist is the buyer and the operator. The customer is the subject and
never installs anything. This is why there are no accounts: the person whose face is being
processed is not the person with a relationship to us.

**[PROPOSED]** The stylist is also the safety control. They are the one who ends a session,
and the design must assume they will forget, because they are mid-conversation with a person
in their chair. See R-RESET.

## 3. What success means

**[INFERRED]** A stylist chooses to open it on the next customer without being asked to.
Nothing else is evidence. Not installs, not session counts, not time in app — a customer
staring at a broken render for four minutes scores well on time in app.

**[PROPOSED]** The one pre-registered number, set at the week-one realism test by the salon
partner and not by us, written here before we are attached to the work:

> **Q-BAR: of the 20 test subjects, the salon partner answers "yes, I would show this to a
> paying customer" for at least ____ of them.**
>
> Value to be filled in by the salon partner **before** they see any result. Blank until then,
> deliberately. A bar set after seeing the output is not a bar.

## 4. MVP scope

**[STATED]** Deliberately small: iPhone and iPad, front camera, one face, portrait, a handful
of styles, no accounts, no cloud, no booking, no payments.

**[STATED]** It has to survive being used back to back by strangers all day on one shared
device.

**[INFERRED]** That last sentence is a hard requirement and not a nice-to-have. It is the
sentence that makes this FULL tier, because "one shared device, strangers, all day" is the
exact shape of a biometric data incident. It drives R-RESET and ADR-005.

### Scope contract

Every feature traces to a requirement. Anything not traceable does not get built.

| ID | Requirement | Source | ADR |
|---|---|---|---|
| R-LIVE | Live camera render of a hairstyle on the customer's head, holding through head rotation | [STATED] | 001, 002, 003 |
| R-CALIB | The app calibrates to their face, in seconds, not as a wizard | [STATED] | 002 |
| R-STYLES | A handful of styles, browsable | [STATED] | 004 |
| R-SHORTER | Answer "what would I look like with it shorter", the most common salon question | [STATED] | 001 |
| R-RESET | Session ends and is destroyed between customers, including when the stylist forgets | [INFERRED] from "back to back by strangers" | 005 |
| R-NOLEAK | No frame, mesh, or derivative leaves the device, is written to disk, or outlives the session | [STATED] | 005 |
| R-NOJUDGE | The system shows. It never ranks, scores, or assesses suitability | [STATED] | — |
| R-HONEST | The UI states plainly what the system cannot show, rather than hoping nobody notices | [PROPOSED] | 001 |
| R-DEGRADE | Unsupported device shows a written explanation, never a crash or a black camera | [PROPOSED] | 002 |

### Out of scope, explicitly

**[STATED]** Accounts, cloud, booking, payments, and the mirror version.
**[INFERRED]** Colour and dye simulation, beards, multi-face, landscape orientation, Android,
the back of the head, and any form of recommendation.

## 5. The two requirements that are really product positions

### R-NOJUDGE — show, do not rank

**[STATED]** "Do not build a system that tells someone a haircut does not suit their face.
Automated judgement about people's appearance is a good way to make a customer feel bad in a
chair they are paying to sit in. For the MVP: show, do not rank."

**[INFERRED]** This is not only an ethical position, it is a competitive one. Lenskart's
glasses try-on opens by analysing your face and recommending frames; the whole AI-hairstyle
category leans on "find what suits you". Declining to do that is a visible, defensible
difference in a category that is otherwise indistinguishable.

**[PROPOSED]** Enforced, not merely intended. No face-shape classification, no fit score, no
ordering by anything except category. The runnable check is a string-lint over user-facing
copy and identifier names, failing the build on `suits`, `flatter`, `best for`, `score`,
`match`, `recommended`, `ideal for`, `face shape`. It is blunt and it will occasionally flag
something innocent. That is the correct trade against a person in a chair being told by a
machine that their face is the wrong shape.

**[STATED]** If recommendation comes later it is designed with the stylist in the loop, not as
a verdict from a machine.

### R-HONEST — say what it cannot do

**[PROPOSED]** Live mode adds hair and cannot remove it (ADR-001). The category's universal
habit is to hide that. Ours is to print it: live mode carries a persistent, plain-language
statement that it is showing added length and volume over the customer's real hair, and the
freeze result is labelled as a simulation.

**[INFERRED]** In a category where every competitor overclaims and users' most common
complaint is that results look like a wig, being the only product that states its own limit is
worth more than one extra style.

## 6. Non-goals that look like goals

**[PROPOSED]** Worth naming so nobody builds them by reflex:

- **Not a photo booth.** Saving and sharing is a customer-initiated share sheet, not a gallery
  we keep. Anything we keep is a biometric database.
- **Not a catalogue.** Styles exist to support one conversation, not to be browsed for pleasure.
  Eight good ones beat forty that are half-broken.
- **Not a mirror.** ADR-006 keeps the door open and builds nothing.

## 7. Open

| Question | Owner | Blocks |
|---|---|---|
| Product name and final repo location (currently `~/dev/misc/salon-ar`) | Founder | Nothing yet |
| Q-BAR value, set before results are seen | Salon partner | Week-one exit decision |
| Which iPad the salon owns. Sets the real device floor; A12 may be optimistic | Salon partner | ADR-002 verification |
| Salon partner identity and when the visit happens | Founder | Week-one realism test |
| Do stylists tolerate a 2–4s freeze mid-consult, or does it read as broken | Salon partner | ADR-001 freeze mode survives or is cut |
| No iPad exists for development testing | Founder | Recorded in `docs/DEBT.md`, not silently skipped |

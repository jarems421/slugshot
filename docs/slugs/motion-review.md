# Motion review

Every slug animation passes two separate gates. Passing one never implies the other: Inferno's first flame passed its finite-pose and bounds checks and was still "just like a PNG", and a first-person Floppy passed bone checks while its mesh stood still.

`roble3-animation-quality-gate` is pinned third-party source, so this project gate adds to it rather than editing it. Use its contact sheet and its seven review dimensions in Blender. A contact sheet alone cannot pass a motion here, because attractive stills can make an awful animation.

## Order of review

1. **1× from the gameplay camera.** The first look, every time. Inspect: the holder's first-person view. Fired slug: the shooter's view at real distance. Idle: wherever the player actually meets the slug.
2. **1× from the other views that matter:** side for arcs and contact, third person from behind and above.
3. **Slow motion only to diagnose.** It explains a failure already seen at 1×. Something visible only when slowed does not count as visible.

A browser preview chooses between ideas. A native Studio capture at 1× is what passes a motion.

## Gate 1: technical

Answers "is it broken?" Facts, with evidence. `python tools/slugs/review_motion.py <study>` fills in the first three for a browser study. In Studio, measure the same things on the live instance.

| Check | Pass |
| --- | --- |
| Finite poses | No NaN or missing bones across the whole motion |
| Continuity | No unintended single-frame jumps, except a declared swap. A large spike is a question to answer, not an automatic failure: a fast spin spikes too |
| Readable on screen | Share of the frame and seconds visible from the gameplay camera are recorded, so "you can't see it" is measured |
| Contact | Sole on its surface while grounded, measured from the deformed mesh and not the pivot. Contained in the canister through the continuous motion, not just held poses |
| Real instance | The instance the player sees deforms, on every skeleton copy |
| Frame rate | Same result at 30 and 60 FPS |
| Interruption | Interrupt, unequip, remove and re-enter leave no stuck pose or leaked instance |
| Engine | Clip names survive export and reimport if authored in Blender, and it plays in Studio |

## Gate 2: visual design

Answers "is it good?" Judge each at 1×, in plain words, and say what fails. These are opinions until the owner gives a verdict.

| Dimension | Question |
| --- | --- |
| Timing | Are the beats readable in the time available? Does anything rush or drag? |
| Arcs | Do parts travel on curves, or slide on straight lines? |
| Anticipation | Is there a visible gathering before the big move? |
| Weight | Does it feel like the right mass? Does it land, or just stop? |
| Transitions | Does it flow in and out of what is around it, with no visible cut? |
| Follow-through | Do antennae, tails and the head lag and settle? |
| Personality | With the name hidden, would you know which slug this is? |
| Staging | From the gameplay camera, is the idea readable in one look? |

Common wording: "stiff" means one rigid piece, "frozen frame" means too small or too regular, "like a PNG" means a shape that appears rather than evolves. The [design language](owner-design-language.md) has more.

## Recording a review

Use this in the species record or the motion library:

```markdown
**Motion review, <date>, <slug> <motion>:**
- Technical: PASS or FAIL, evidence path, what was and wasn't run (browser / Studio, FPS, camera).
- Visual, my view: strongest and weakest dimension, one sentence each.
- Owner verdict: exact words, or pending.
- Status: Considering | Implemented/verified | Confirmed.
```

Never write "approved" without the owner's words. If it failed, say which gate failed, because the fix differs: a technical failure gets debugged, while a visual failure at concept stage gets a new concept (see the [animation director](../../.claude/skills/slugshot-animation-director/SKILL.md)).

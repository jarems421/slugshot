---
name: slugshot-animation-director
description: Design a brand new Slugshot motion before anyone builds it, such as a new idle, inspect act, reaction or ability acting. Produces three motion concepts on the real model, a real-speed comparison and an owner choice. Use only when the performance does not exist yet or every attempt has failed. If a motion already exists and looks stiff, wrong or needs tuning, use slugshot-procedural-animation instead.
---

# Slugshot animation director

Separates designing a motion from building it. Read [the motion library](../../../docs/slugs/motion-library.md), the slug's record in [the catalogue](../../../docs/slugs/catalog/index.md) and the motion rows of the [lesson index](../../../docs/lessons-index.md). Open older notes only from a link in those.

**Before starting, check this skill applies.** Use a direct fix, with no concepts, when:

- the motion is already approved and the owner asks for a change ("a tad less", "stiffer"). Change one thing and state the number.
- the owner points at an existing motion ("it already does it in the HUD"). Reuse it unchanged first. The owner's past "I give up on the current animation" ended this way.
- something is a bug: a snap, a float, a frozen rig.

## Phase A: Explore

Write a short brief: the slug's personality in the owner's words, what the motion is for, where it plays, its real duration, and what the player can see in that time. For a transformation, take the timing from `Combat.Slugs`. For an inspect, take the slug's window from `SlugInspect`.

Write three concepts that differ in idea, not just in amounts: different anticipation, weight, rhythm and which body part leads. If two would read the same at real speed, replace one. Reuse a library technique freely, but do not reuse another slug's character: Floppy's timing on Inferno gives you Floppy. No effects yet.

## Phase B: Preview

Add a study at `tools/slugs/motion-preview/studies/<id>.js` (see the [README](../../../tools/slugs/motion-preview/README.md)) and build it. All three concepts share one model, clock, camera and light. Then run `python tools/slugs/review_motion.py <id>` and look at the contact sheet and the technical report yourself. Parallel workers may each draft a concept only in their own study file and output folder; the main session compares them.

Publish the page as a private Artifact (build with `--cdn`) for the owner, and say which concept you would pick and why. A preview in the browser is for choosing an idea. It cannot settle feel.

## Phase C: Critique and select

Watch at 1× from the gameplay camera first, then use slow motion only to find out why something fails. Keep rejected concepts in the study file and log them in the motion library. Combine ideas only if the owner asks or the parts really belong together.

**Do not polish an unchosen concept.** Polish waits until the owner picks one. If none works, write down what each got wrong and make a new set from those critiques. Do not keep revising the least bad one.

## Phase D: Implement

Choose the technique by how the motion behaves:

| The motion | Technique | Skill |
| --- | --- | --- |
| Reacts to the game, blends with anything, or must never cut | Luau springs | `slugshot-procedural-animation` |
| A fixed authored shape, exported as a clip | Blender action | `el4cteo-blender-animation`, with the row in [skill routing](../../../docs/slugs/skill-routing.md) |
| Mesh or weights break in the pose | Fix the rig first | `el4cteo-blender-character-rigging` |
| A face pose does not read | Shape or bone poses | `el4cteo-blender-facial-shapekeys` |

Almost every approved slug motion so far is Luau, so assume Luau unless there is a reason not to. Port the chosen concept exactly first, then adjust only what fails in the engine. Never run two agents on one live Blender scene.

## Phase E: Validate and learn

Pass the [motion review](../../../docs/slugs/motion-review.md): the technical gate and the visual gate are separate, and neither implies the other. Give the owner one clean Studio window with the rebuilt place. Then record what was accepted, rejected and why in the [motion library](../../../docs/slugs/motion-library.md), the owner's wording in the [design language](../../../docs/slugs/owner-design-language.md), and any reusable fix in the [lesson index](../../../docs/lessons-index.md).

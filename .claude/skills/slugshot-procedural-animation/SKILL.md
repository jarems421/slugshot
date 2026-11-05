---
name: slugshot-procedural-animation
description: Write or fix Slugshot slug motion in Luau - spring-driven Bone.Transform poses, target poses, follow-through, blending idle with inspect and reactions, ground contact and frame-rate independence. Use for InfernoMotion, FloppyIdle, inspect acting, SlugIcon and any new slug's runtime motion, or when a slug in Roblox floats, snaps, looks stiff or stops moving. Not for Blender keyframes or for choosing what a new motion should be.
---

# Slugshot procedural animation

Slug motion is Luau on the client, because `Bone.Transform` does not replicate. Read the slug's current motion script and the motion rows of the [lesson index](../../../docs/lessons-index.md). The maths lives in [`MotionKit`](../../../experiments/creatures/shared/MotionKit.luau); recipes and tested numbers are in the [motion library](../../../docs/slugs/motion-library.md).

Do not rewrite an approved motion to use the kit. It exists for new motion. Change approved motion only for what the owner asked.

## Who owns each transform

Every bone, joint or pose has one writer per frame. Find the owner and add to it; a second writer races it. Search for `.Transform =` before adding one.

| Thing | Owner |
| --- | --- |
| Floppy's body, idle and loaded acting | [`FloppyIdle`](../../../experiments/creatures/floppy/client/FloppyIdle.client.luau) |
| Floppy's lids, gaze and mouth | [`FloppyFace`](../../../experiments/creatures/floppy/client/FloppyFace.client.luau) |
| Inferno on the ground and in the air, both forms | [`InfernoMotion`](../../../experiments/creatures/inferno/client/InfernoMotion.client.luau) |
| Inferno loaded in the gun, during inspect | [`inspect`](../../../experiments/creatures/inferno/inspect/init.client.luau), timed by `Flow` |
| Gun toss and catch, and the shared inspect clock | [`SlugInspect`](../../../experiments/movement/client/SlugInspect.luau) |
| A fired slug's pivot, scale and `TransformFold` | [`SlugTransformation`](../../../experiments/combat/client/SlugTransformation.luau) |
| A fired Floppy after landing | [`FloppyRecovery`](../../../experiments/combat/client/FloppyRecovery.luau) |
| Hotbar and inventory slugs | [`SlugIcon`](../../../experiments/combat/client/SlugIcon.luau) |
| Slugs in the lobby grove | [`GroveSlugs`](../../../experiments/lobby/hub/client/GroveSlugs.client.luau) |

Render order matters: native animation can reset bones between simulation and rendering. Idle runs at Character +2, the face at +3 and the viewmodel copy at +10.

## Rig facts

- Work in concept axes, never bone axes. Sideways comes from a pair of bones (antennae on Inferno, eyes on Floppy), up from the world or the pivot, front from their cross product. Convert into each bone's axes once. Imported axes can point anywhere.
- Author amounts in concept units and scale from the bone spacing, so motion survives any model size. Motion that reads on the ground is invisible at loaded scale unless sized for it (about 0.001 studs at 0.076 scale).
- Roblox can make one skeleton per skinned mesh. Drive every copy, or the eyes leave the body.
- A model can arrive before its bones, welds or handle. Retry setup until they exist; do not register a partial rig.
- `TransformedWorldCFrame` is a frame behind. Walk the parents for this frame's position (`movedFrame`, `Rig.frame`).
- Measure from bones. `GetBoundingBox` is inflated on imported skinned models.
- Capture rest values once. Reading a live joint as its rest pose bakes in whatever it was doing.

## Motion rules

1. **A performance sets targets and gives kicks; springs move the rig.** One move then flows out of whatever the last one left, so nothing can cut. To blend, change targets. Never interpolate between poses or play over the top.
2. **Fixed time step.** Use `MotionKit.advance`, so motion is the same at any frame rate. Take speeds from baked values, not from `dt`, unless guarded as in `rate()`.
3. **Grounded parts stay grounded.** The sole does not move while the upper body acts: bend from the spine, each part trailing the one below (`stepChain`). Never move the whole model to compensate for a head or to fit a space; that is what made Floppy "stiff and choppy". Solve the sole against the surface if the pose must stay supported.
4. **Anticipation, action, follow-through.** Press, hold briefly, then go; arrive past the mark and settle. Damping below 1 gives overshoot, and only moves that should wobble get it. Antennae and tails lag the speed of the body (`antennae` in InfernoMotion).
5. **Turns wrap.** Sample an unwrapped angle, then bring a finished turn near zero (`wrapTurn`). Blending CFrames a whole turn apart loses the spin.
6. **Stop cleanly.** Reset on interrupt, unequip and removal, and test those paths. A `ReviewHold` attribute freezes a rig for capture; `TimeScale` slows a fired slug on this screen only.
7. **Same act in first and third person.** Review on the exact instance the player sees: a clone without its Motor6Ds does not deform while its bone values still look right.

## Check it

Run `python tools/verify_slugs.py`; for combat files, `python tools/verify_combat.py`. These do not run Roblox. Then follow the [motion review](../../../docs/slugs/motion-review.md), with real key presses in Studio, from the gameplay camera, on the instance the player sees. Bone values changing does not prove motion. If the mesh should deform, prove it with an exaggerated pose.

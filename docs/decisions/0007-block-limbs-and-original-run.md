# ADR 0007: Block limbs and an original block-limb run

Date: 2026-10-29
Status: Accepted for the experiment only; reconsider after the owner's v4.7 playtest
Approval evidence: owner feedback on the private v4.5 and v4.6 labs, 2026-10-29 ("no elbows, hands or knees … that's my final verdict"; the run should match the Huss Valley Runner reference: steadier, sharper, leaning forward)
Builds on: [ADR 0003](0003-clip-presentation.md), [ADR 0005](0005-mixamo-variants-transitions.md)

## Context

Restyling the Mixamo run in the converter (v4.5 straight limbs, v4.6 arms driven by the legs) still looked wrong to the owner:
- it was shaky and slid;
- it was not sharp enough;
- it was too upright;
- elbows and knees still showed.

The shake had two sources:
- Ground contact pulled the body down to keep a foot on the floor. With straight legs spread, both feet rise, so the torso dropped twice per stride.
- Three mocap loops (jog, run, sprint) were blended on one phase, and their cycles do not line up.

## Decision

- **Block limbs.** The elbow, wrist, knee and ankle joints are held straight after every clip, action and pose adjustment (`Config.Animation.RigidJoints`). Hands stay hidden ([v4.6](../movement.md#what-changed-in-v46-owner-feedback-on-v45)).
- **Feet push, never pull.** Foot contact only pushes the body up out of the floor (`GroundContact.PullDown = false`). The torso keeps its clip height, and straight legs lift clear in the stride, as in classic Roblox runs. Roll body contact stays two-sided.
- **Original run.** Run, Sprint and the back-pedal are generated in `OriginalClips.luau` for rigid limbs:
  - a smoothed triangle swing (a sharp reversal at each end, a constant rate through the middle);
  - a held forward lean, with the hips compensated so the legs swing about vertical;
  - arms opposite the legs, flaring out on the back swing;
  - a small chest twist and bob.
  
  Each clip's natural speed is the passing foot's speed, so the foot does not slide where it meets the floor.
- **No mocap locomotion loops.** The private manifest no longer maps Jog, Run, Sprint, the four sprint diagonals or the strafe. All builds use the original clips for these. Mocap one-shots (start, stop, turn, landings, rolls, flips, mantles) remain, shown with rigid limbs.

## Consequences

- The run is our own code and ships in the public build too.
- Clips that bend the knees to lower the body (crouch, landing squash, mantles) lose that depth: rigid legs are pushed back up. They read like an R6 rig. Crouch may need a dedicated block-limb pose.
- The converter's styling options (`planar`, `upright`, `limit`, `splay`, `armsFromLegs`, `knees`) are now unused but kept for future clips.
- The v4.6 converter-restyled run is superseded.

## Addendum: v4.8 (same day)

The owner said the v4.7 run looked like a basic Roblox run. It was an even pendulum swing, the same structure as the default R6 run. The run is now pose-to-pose (`snapRun`):
- each step holds a kick pose (trailing leg straight back near horizontal, opposite arm reaching forward);
- then it snaps through the passing pose into the mirror;
- the arms are symmetric.

The mocap start, stop and turn transitions are removed from the private manifest; they read as slow and slippery. Stopping is a quick idle blend with no slow-motion cadence (`MinCycleRate` 0.85). A reversal is the body turning, with the turn and acceleration leans capped low. The smoothed-triangle generator remains for the back-pedal only.

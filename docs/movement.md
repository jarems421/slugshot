# Movement lab

Experimental branch: `experiment/movement-sandbox`. The foundation project remains unchanged. This is a playable prototype for review, not an approved final movement set or camera design. Do not merge into `main` until the owner has reviewed the gameplay.

## Play and compare

```powershell
python tools/verify_movement.py                       # checks; builds build/SlugshotMovementLab.rbxlx (public, original clips)
python tools/build_movement_playtest.py --retarget    # private Mixamo lab (v4), plus the v1 and v2 labs
```

Open a place in Studio and press Play. Studio does not reload a rebuilt `.rbxlx`: close and reopen it after rebuilding.

- `SlugshotMovementLabPrivate.rbxlx`: **v4.4**, the owner's Mixamo clips with transitions, crouch, vault, wall run and parkour mantle (the HUD shows `original + N private clips`). Built only from privately retargeted clips (see [assets](movement-assets.md)); never commit or publish it.
- `SlugshotMovementLab.rbxlx`: the same code with original clips only (HUD: `original clips`). Wall run works with the original wall-hop clip; vault, parkour mantle and transitions need Mixamo clips.
- `SlugshotMovementLab-v2.rbxlx`: v2 (clips, rolls, flips), rebuilt from commit `0b06985`.
- `SlugshotMovementLab-v1.rbxlx`: the first lab, rebuilt from commit `e2b5688`.

For live editing, serve `movement.project.json` with the Rojo plugin on port **34873**.

| Control | Experimental action (v4.4) |
| --- | --- |
| WASD / native movement controls | Run (eight directions; jog while accelerating) |
| Shift / gamepad L3 | Sprint (also stands up from a crouch) |
| C / gamepad R3 | Crouch toggle (crouch walk in four directions) |
| Space / native jump | Jump. **Into a ledge** 0.7-5.7 studs above your feet: mantle onto it (holding Space mid-jump reaches higher ledges). **Into a thin wall up to 3.6 studs, at speed**: vault over it. **Jump onto a wall while running along it** (not head-on): wall run along it automatically, locked on until your feet reach the ground or the wall ends. Hold Space to run up the wall (easing into a slow slide) and over its top when you reach it; release to slide down; tap Space to kick off. Ledges are mantled only when the jump would not clear them, and never when under 2.2 studs above the ground. **In the air beside a wall**: wall jump; presses up to 0.35 s early count. The held direction picks the kick: toward the wall leaps up it (once per wall per airtime), along it jumps sideways, away or nothing kicks out (also for the tap off a wall run). Up to 8 kicks per airtime, enough to climb between two walls; each restores the flip |
| Q / gamepad B | **Acrobatics**: on the ground, roll toward your input (forward, back, left or right of your facing); in the air, front flip, or backflip when holding back. Pressing during a flip or just before landing queues a landing roll |
| RMB / gamepad L2 | Shoulder aim pose, stable camera, small FOV change |
| Click / gamepad R2 | Harmless aim marker; no damage or projectile system |
| H | Lab only: take 15 damage to preview hit reactions and the injured idle (no combat rules) |
| P / R | Cycle Baseline, Athletic, Precise profiles / respawn |

v1's separate F flourish is gone: Q is the single context-sensitive control. Touch/gamepad bindings exist but have not been device-tested.

## What changed in v4.4 (owner feedback on v4.3)

- **Directional wall jumps.** The kick follows the held input: toward the wall leaps straight up it (58 studs/s up, facing the wall, jump clip), along the wall jumps off sideways (keeps the run speed, 8 studs/s out), away or nothing kicks out as before. The up-leap works once per wall per airtime, so a single wall cannot be climbed forever. The same choice applies to the tap off a wall run.
- **Up and over.** Holding Space on a wall run mantles over the top when it comes in reach, and so does a Space press near the top or the wall ending under you. Ledge checks also run straight after a kick, so leap up a wall, then over.
- **Faster mantles.** Target 0.2-0.3 s (was 0.32-0.48), clips up to 5x, full approach speed kept on top (at least 14 studs/s), 0.2 s cooldown.

## What changed in v4.3 (owner feedback on v4.2)

- **Wall run stays on.** It no longer ends after 2 s or when input stops pointing along the wall; only the ground, the wall's end or a kick ends it. Holding Space climbs, easing into a 2 studs/s slide; released, the slide starts at 1.5 studs/s.
- **Wall jumps climb between walls.** The 3-kick limit per airtime stopped climbing after three kicks; it is 8 now, presses up to 0.35 s early count (was 0.15) and the reach is 4.5 studs. The corridor walls are 40 studs tall to practise on.
- **Parkour mantle.** A new original speed-vault clip (`MantleVault`, in `OriginalClips`): left hand planted, body tipped over, both legs swung out sideways over the top, right foot lands. The Mixamo-based version (from Vault Over Box) read as a hunched ball on the blocky rig and is no longer used.
- **Mantle style by reach.** Parkour when the jump brings the feet within 2 studs of the ledge top at its face; otherwise the climb (reaching for a high ledge).
- **HUD** shows the last rejected request, so a cancelled move can be reported.

## What changed in v4.2 (owner feedback on v4.1)

- **Crouch idle** stands at the crouch walk's height and stance (it was lower), breathing with the crouch idle's torso and head.
- **Wall-run height control.** Hold Space to run up the wall (11 studs/s, fading over the 2 s limit); release to slide down, slowly at first. A quick tap (under 0.2 s) kicks off. The body is held 2.1 studs from the wall instead of being pushed into it.
- **Wall hand** spreads only as far as the wall: the shoulder angle is solved from the real distance to the wall, the body roll and the rig's arm length. Measured: the hand stops about 0.15 studs from the surface.
- **Mantle** happens only when the jump would not clear the ledge: the feet's path is predicted to the ledge face, and if they pass over the top it is a normal jump. Ledges under 2.2 studs above the ground below are never mantled. Holding Space up the staircase no longer mantles; a 3-stud box taken with an early jump is jumped onto; 4.5 and 5.5 stud ledges still mantle.
- **Falls** no longer use Falling Idle (the crouched, limbs-out pose). They sway gently around the top of the jump clip in use, so they match the jumps.

## What changed in v4.1 (owner feedback on v4)

The owner played v4 and reported the problems below. Changes are in [ADR 0006](decisions/0006-wall-run-and-v4-feedback.md).

- **Wall run and wall jump did nothing.** Studio does not fire `UserInputService.JumpRequest` for every Space press (it did not fire at all in a real-key test), and wall hops only listened to it. Space/ButtonA presses are now read directly; `JumpRequest` remains for touch.
- **Wall run was a hop, not a run.** It is now a state: jump onto a wall while running along it and you attach, with no second press, from parallel to about 53° into the wall. You keep the jump's rise briefly, then sink slowly while running along the wall for up to 1.6 s. The body tilts off the wall with the wall-side hand on it. Space kicks off; releasing or steering away drops off; the wall's end or the ground ends it. A corridor of two long walls east of the ledges lets you chain wall runs.
- **Wall jump looked scrappy.** Both wall jumps (from a run or from mid-air) now play the kick-off part of the owner's Wall Run / Diagonal Wall Run clips, turned so they end facing the jump direction.
- **Mantle was slow.** Ledges up to 4.6 studs use a one-hand parkour mantle (the hand-plant part of Vault Over Box); taller ones play faster. Measured: 0.41 s at 3 studs, 0.46 s at 4.5, 0.51 s at 5.5 (was about 0.75-0.9 s).
- **Too many jumps.** One running jump (Running Jump) and one standing jump derived from it (mirrored, smaller swing; none of the owner's files is a standing takeoff).
- **Crouch:** the "all fours" drop (from Strafing) is gone; entering a crouch crossfades. The crouch idle keeps the crouch walk's raised arms (Crouching Idle's hands hang to the floor).
- **Stops and idle cut three times.** The neck-stretch fidget is removed; transitions blend into locomotion over their last 0.35 s; the idle/moving mix eases over time instead of following braking speed.
- **Running:** wider hip and shoulder swing, straighter elbows, cadence capped at 1.3x. The owner still dislikes it; it is the next item.
- **Falling pose on box edges:** the presentation's ground check is a sphere about the footprint, not one ray under the centre.

## What changed in v4 (Mixamo clips)

The owner downloaded 49 Mixamo clips (several per state) and asked for all of them to be used for variety ([ADR 0005](decisions/0005-mixamo-variants-transitions.md)). All 49 are in use, as 54 runtime clips (mirrors add the rest). The full mapping is in `tools/mixamo_manifest.json`.

- **Running.** Jog → run → sprint by speed, eight directions with diagonals, and sideways strafes. The idle has a hurt version below 35% health and occasional fidgets.
- **Transitions** chosen from motion, so other players see them too: a start from standing, a skid to a stop (gun-ready or back-pedal stops while aiming or backing up), a 180° turn on reversal, crouch in/out, settling after aiming, and a flinch when hurt.
- **Jumps** pick a standing, running (two variants), sideways (four variants) or aiming takeoff. **Landings** come in three strengths by impact: normal, hard (about 15-25 stud drops) and heavy (kneel and rise).
- **Rolls** alternate two forward variants. Q pressed before touchdown uses a dedicated landing roll. Back and side rolls are still the original clips.
- **Flips** alternate two front and two back variants. A long fall uses a drop flip instead.
- **Climbs:** ledges of 5 studs or more use a hanging climb. **Vault:** run and jump into a low thin wall (vault course west of spawn). **Wall run:** sprint along the long wall and jump twice.

## What changed in v3 (traversal)

The owner asked to build on established free systems, then chose to adapt mantle and wall hop from the MIT-licensed [Place1 movement system](https://github.com/alexkkork/place1-movement-system) ([ADR 0004](decisions/0004-place1-traversal.md)). Its ledge, clearance and wall detection is ported with its licence notice into `client/Traversal.luau`. Movement, clips and server checks follow this lab's own architecture.

- **Mantle.** Space into a ledge. Below 3.2 studs: a one-hand step vault (`MantleLow`). Above: a two-hand climb (`MantleHigh`): reach, pull, press, knee onto the edge, step through into a stride. The root closes to the wall, then follows the clip's over/up curves, so the clip decides the motion's timing. Duration scales with height (0.34-0.55 s). You leave the top with 80% of your approach speed.
- **Wall hop.** Space in the air beside a wall: kick away (30 studs/s out, 54 up), keeping some along-wall speed, and turn to face the new direction. The kick owns movement for 0.22 s, then air control returns. Up to 2 hops per airtime. A hop restores the flip, so hop then Q (holding toward the wall) is a backflip off it. Presses too early after takeoff are buffered for 0.15 s.
- **Test course** east of the wall: ledges of 1.5, 3, 4.5, 5.5 and 7.5 studs (the last needs a jump), and a chimney: kick between the walls, then mantle onto the 14-stud block.
- Parts can opt out with a `NoParkour`, `NoClimb`, `NoMantle` or `NoWallHop` attribute (Place1's convention).

## What changed from v1 to v2, and why

v1 playtest feedback: the evade read as a dash, the flourish as a procedural spin, running and jumping lacked expression. v2 keeps v1's strongest parts (native Humanoid physics/input/camera, smoothed profiles, server request validation, attribute-replicated presentation that every client renders for every character) and replaces the presentation and actions:

- **Authored clips instead of procedural sine poses.** Original keyframed R15 clips (`shared/OriginalClips.luau`): idle, run, sprint, back-pedal, left/right strafes, jump, fall, land, forward (diagonal shoulder) roll, back roll, left/right side rolls, front flip, backflip. Poses are readable degree keyframes sampled with smooth Hermite curves, so they can be retimed or swapped for Animation Editor or Mixamo clips by name.
- **Directional locomotion.** Run/sprint/back-pedal/strafe blend by velocity direction relative to facing and share one cycle phase; cadence follows ground speed within a clamped range.
- **Physics-driven air poses.** Rising follows the jump clip by vertical speed, then the legs reach for the floor from predicted time-to-land; landings absorb in proportion to impact speed and less when running.
- **Rolls drive movement from their own root motion** (scaled to `Acrobatics.Roll.Distance`), so travel matches the body; jump cancels the last part of a roll. Directional variants are chosen relative to facing; the presentation turns the clip by any remaining angle.
- **Flips fit the airtime.** Playback rate fits the predicted time to land (clamped), with a small configurable minimum lift. The physical root and camera never rotate.
- **Ground contact on the real rig.** Forward kinematics on the actual R15 proportions keeps the feet (locomotion, landing) or the lowest body part (rolls) at each clip's authored floor clearance.
- **Transitions.** Pose-snapshot crossfades between ground/air/action states; lean into turns and acceleration; aim arm pose blends and is reduced during acrobatics.

All tuning is in `experiments/movement/shared/Config.luau` (`Acrobatics`, `Animation`, profiles, camera). Profiles: Baseline 16, Athletic 24/30 run/sprint, Precise 21/27 studs/s.

## Boundaries and known rough edges

- Mixamo motion is realistic but Roblox speeds are not: cadence is capped at 1.3x, so feet slide at sprint. Strafe clips twist the hips toward travel, as Mixamo authored them.
- The wall-run pose is procedural (sprint cycle, roll and a reaching arm), not a clip. The hand is placed by a simple angle solve, not full IK, so it is approximate on unusual rigs. Wall running on sloped walls is not implemented.
- Crouch changes speed and pose only. The collision height is unchanged, so it does not let you fit under anything.

- The clips are hand-keyed by an AI author from pose sheets, not by an animator; expect clean and readable rather than mocap-natural. The blocky default R15 limits how organic they can look.
- Stride slip remains at Roblox speeds: cadence is chosen to read naturally at 24-30 studs/s rather than to lock feet exactly.
- No foot IK for slopes/steps: contact correction is vertical only, so feet can clip or float on the ramp and steps.
- Flips triggered late in a jump play fast (up to 2.6x, raised for the longer Mixamo flips); very late presses become a landing roll instead.
- Aiming stays camera-directed through a flip (verified with the marker), but this is not a weapon system: no grip, muzzle or hit validation.
- Mantle hands are tuned for typical heights with no arm IK, so they can hover slightly above very low or very high edges. Mantles need anchored, collidable parts; moving platforms are unsupported.
- A jump plus quick kicks can lift the feet over 20 studs: lab values to tune, not design decisions.
- Request validation (variants, rates, ground state, geometry, cooldowns, rate limit) is not competitive anti-cheat.

## Playtest priorities

1. Compare v1, v2 and v3 on the flat lane: does running read as fast and athletic without looking floaty or erratic?
2. Roll in each direction from standing and running, and near the wall. Is the distance (12 studs) and recovery right, and do rolls feel like evasions rather than dashes?
3. Jump early and late, flip forward and back, queue landing rolls. Is one context-sensitive button better than separate controls?
4. Aim (RMB) through rolls and flips and place markers: is the camera comfortable?
5. Run and jump into each ledge on the traversal course and climb the chimney. Do mantles feel responsive and grounded? Is wall-hop height/distance right, and does hop then backflip read well?
6. v4.4 (private lab): wall run up the 16-stud wall holding Space and over the top; run at it holding W and jump twice (leap up, then over); tap off a wall run holding forward (sideways) and holding away (out); mantle each ledge. Note any 'Last rejected' reason on the HUD. Which still look or feel wrong?
7. Decide which clips are good enough and which should be replaced (more Mixamo choices, or Animation Editor work).

[Research](research/movement.md) · [Assets and Mixamo pipeline](movement-assets.md) · [Results](movement-verification.md) · [ADR 0003](decisions/0003-clip-presentation.md) · [ADR 0004](decisions/0004-place1-traversal.md) · [ADR 0005](decisions/0005-mixamo-variants-transitions.md) · [ADR 0006](decisions/0006-wall-run-and-v4-feedback.md)

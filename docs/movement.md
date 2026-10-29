# Movement lab

Experimental branch: `experiment/movement-sandbox`. The foundation project remains unchanged. This is a playable prototype for review, not an approved final movement set or camera design. Do not merge into `main` until the owner has reviewed the gameplay.

## Play and compare

```powershell
python tools/verify_movement.py           # checks; builds build/SlugshotMovementLab.rbxlx (v3)
python tools/build_movement_playtest.py   # also builds the v1 and v2 labs for comparison
```

Open a place in Studio and press Play. Studio does not reload a rebuilt `.rbxlx`: close and reopen it after rebuilding.

- `SlugshotMovementLab.rbxlx`: **v3**, v2 plus mantle and wall hop (adapted from Place1).
- `SlugshotMovementLab-v2.rbxlx`: v2 (clips, rolls, flips), rebuilt from commit `0b06985`.
- `SlugshotMovementLab-v1.rbxlx`: the first lab, rebuilt from commit `e2b5688`.
- `SlugshotMovementLabPrivate.rbxlx`: only when privately retargeted Mixamo clips exist (see [assets](movement-assets.md)); never commit or publish it.

For live editing, serve `movement.project.json` with the Rojo plugin on port **34873**.

| Control | Experimental action (v3) |
| --- | --- |
| WASD / native movement controls | Run (directional: forward, back-pedal, strafes) |
| Shift / gamepad L3 | Sprint |
| Space / native jump | Jump. **Into a ledge** 0.7-5.7 studs above your feet: mantle onto it (holding Space mid-jump reaches higher ledges). **In the air beside a wall**: wall hop away from it, up to 2 per airtime; each hop restores the flip |
| Q / gamepad B | **Acrobatics**: on the ground, roll toward your input (forward, back, left or right of your facing); in the air, front flip, or backflip when holding back. Pressing during a flip or just before landing queues a landing roll |
| RMB / gamepad L2 | Shoulder aim pose, stable camera, small FOV change |
| Click / gamepad R2 | Harmless aim marker; no damage or projectile system |
| P / R | Cycle Baseline, Athletic, Precise profiles / respawn |

v1's separate F flourish is gone: Q is the single context-sensitive control. Touch/gamepad bindings exist but have not been device-tested.

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

- The clips are hand-keyed by an AI author from pose sheets, not by an animator; expect clean and readable rather than mocap-natural. The blocky default R15 limits how organic they can look.
- Stride slip remains at Roblox speeds: cadence is chosen to read naturally at 24-30 studs/s rather than to lock feet exactly.
- No foot IK for slopes/steps: contact correction is vertical only, so feet can clip or float on the ramp and steps.
- Flips triggered late in a jump are fast (up to 1.8x); very late presses become a landing roll instead.
- Aiming stays camera-directed through a flip (verified with the marker), but this is not a weapon system: no grip, muzzle or hit validation.
- Mantle hands are tuned for typical heights with no arm IK, so they can hover slightly above very low or very high edges. Mantles need anchored, collidable parts; moving platforms are unsupported.
- A jump plus two quick hops lifted the feet over 20 studs in testing: a lab value to tune, not a design decision.
- Request validation (variants, rates, ground state, geometry, cooldowns, rate limit) is not competitive anti-cheat.

## Playtest priorities

1. Compare v1, v2 and v3 on the flat lane: does running read as fast and athletic without looking floaty or erratic?
2. Roll in each direction from standing and running, and near the wall. Is the distance (12 studs) and recovery right, and do rolls feel like evasions rather than dashes?
3. Jump early and late, flip forward and back, queue landing rolls. Is one context-sensitive button better than separate controls?
4. Aim (RMB) through rolls and flips and place markers: is the camera comfortable?
5. Run and jump into each ledge on the traversal course and climb the chimney. Do mantles feel responsive and grounded? Is wall-hop height/distance right, and does hop then backflip read well?
6. Decide which clips are good enough and which should be replaced by mocap (Mixamo) or Animation Editor work.

[Research](research/movement.md) · [Assets and Mixamo pipeline](movement-assets.md) · [Results](movement-verification.md) · [ADR 0003](decisions/0003-clip-presentation.md) · [ADR 0004](decisions/0004-place1-traversal.md)

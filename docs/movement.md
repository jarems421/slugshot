# Movement lab

Developed on `experiment/movement-sandbox` and merged into `main` at the owner's request on 2026-10-30, after reviewing the gameplay. The movement code still lives only in `experiments/movement` and its own Rojo projects; the foundation place is unchanged. Moves, numbers and the camera remain experimental, not final design decisions.

**New map playtest:** [Rocklock cavern v3](rocklock.md) reuses this exact controller in a separate spacious place. The original lab is preserved.

## Play and compare

```powershell
python tools/verify_movement.py                       # checks (format, lint, full type check); builds the public lab
python tools/build_movement_playtest.py --retarget    # private lab with the owner's Mixamo clips, plus the v1 and v2 labs
python tools/r6pose/preview.py mantleHigh --ledge 4.5 # render an original clip's keys on the R6 rig (see below)
```

Open a place in Studio and press Play. Studio does not reload a rebuilt `.rbxlx`: close and reopen it after rebuilding.

- `SlugshotMovementLabPrivate.rbxlx`: **v7.39**, adding the owner's Mixamo clips (the HUD shows `original + N private clips`): the running jump, landings, hit reactions, injured idle, wall jumps and the neck-stretch fidget. Built only from privately retargeted clips (see [assets](movement-assets.md)); never commit or publish it.
- `SlugshotMovementLab.rbxlx`: the same code with original clips only (HUD: `original clips`). Every move works: run, idle, flips, slide, mantles, kong vault, wall run and wall jumps are original clips. Without the private clips it uses an original jump and landing, plays the wall-hop clip for wall jumps, and has no fidget.
- `SlugshotMovementLab-v2.rbxlx`: v2 (clips, rolls, flips), rebuilt from commit `0b06985`.
- `SlugshotMovementLab-v1.rbxlx`: the first lab, rebuilt from commit `e2b5688`.

For live editing, serve `movement.project.json` with the Rojo plugin on port **34873**.

| Control | Experimental action (v7.39) |
| --- | --- |
| WASD / native movement controls | Run (eight directions: run ahead, strafes either side and the back-run behind, blended between) |
| Double-tap W / gamepad L3 | Sprint (24 studs/s; the run is 18) until W is released (gamepad: until the stick is released), with a very slight camera bounce and wider view |
| Shift / gamepad B | **Slide** while running (12+ studs/s): current speed +15 (max 26), slowing to 20 over 0.8 s, steering a little. Pressed in the air, mid-action or inside the 0.25 s cooldown, it waits 0.4 s (or while Shift is held, until you land) and slides on touchdown. Jump during it leaps out keeping the speed (slide-jump); Shift again stands up. Camera dips 1.4 studs and the FOV kicks to 82 |
| Ctrl | **Shift lock** toggle: mouse locked to the centre, body faces the camera (strafing on A/D), camera 1.75 studs over the right shoulder. Actions keep their own facing, then the body turns back to the camera |
| Space / native jump | Jump (same height as v7.38; shorter horizontal reach and a 4% in-air speed boost). **Into a ledge** 0.7-5.7 studs above your feet: mantle onto it (holding Space mid-jump reaches higher ledges). **Into a thin wall up to 3.6 studs, at speed**: vault over it. **Jump onto a wall while running along it** (not head-on): wall run along it automatically, locked on until your feet reach the ground or the wall ends. Steer with the keys: along the wall runs, nothing slows to a cling (dragging slowly down), back along it turns round. Jumping straight into a wall and doing nothing clings to it too. Hold Space at any point to run up the wall (3 s of full-speed climbing per run, then easing into a slow slide); at the top it keeps running along the edge. Release to slide down. Press Space again near the top to mantle over; press it holding away from the wall (or back) to jump off at once; a tap lower down (released within 0.3 s) kicks off. Ledges are mantled only when the jump would not clear them, and never when under 2.2 studs above the ground. **In the air beside a wall**: wall jump; presses up to 0.35 s early count. One press kicks off where you hold (camera relative; where the camera faces if you hold nothing), always at least 30° out from the wall and facing the way you go. This also applies to the tap off a wall run. Holding almost straight into the wall leaps up it instead (once per wall per airtime). Up to 8 kicks per airtime, enough to climb between two walls; each restores the flip. **Anywhere else in the air** (a second press): double jump with a flip toward the keys held, as seen on screen: W front full step-out (winged layout twisting a full turn, stepping out), A/D butterfly twist, S back full (arms overhead), all four diagonals a tilted corkscrew; once per airtime |
| H | Lab only: take 15 damage to preview hit reactions and the injured idle (no combat rules) |
| P / R | Cycle Baseline, Athletic, Precise profiles / respawn |

There is no ground roll (removed in v7.8) and Q is unbound. Touch/gamepad bindings exist but have not been device-tested.

**Pose tools.** `tools/r6pose/preview.py` renders any literal key table in `OriginalClips.luau` (idle, air, mantles, kong vault) on the R6 block rig with the game's curves. Mantles can be placed on the client's path against a ledge, printing hand and foot positions relative to the top and face; `--help` lists options. It needs numpy and matplotlib, and writes to `build/r6pose/` (ignored). The Luau tables are the only copy of the poses.

## What changed in v7.39 (slower movement pace)

- **Confirmed:** owner requested run ?18, sprint ?24, wall run ?24 and slide cap ?26 studs/s, calmer running/sprinting limbs and camera bounce, slightly slower flips, and shorter horizontal jump reach with the same height.
- **Implemented:** Athletic and Precise run/sprint are 18/24; Baseline stays the stock 16/16 comparison. Wall run starts at 24, including faster approaches, and targets 24 with input. Slide cap is 26; +15 boost, 20 ending speed, 0.8-second quadratic decay, steering, buffering and airborne decay are retained.
- **Implemented:** locomotion's playback-rate range is 0.65?1.15 so the existing speed matching can slow the limbs at the new speeds. Ground bounce is 0.018 studs at 3.2 footfalls/s for run, 0.035 at 3.7 for sprint, with continuous phase, speed scaling and eased entry/exit. Flip playback is scaled by 0.92, with minimum rate 0.78.
- **Implemented:** first-jump air-speed multiplier 1.08?1.04; airborne wall-kick launch 40?34, wall-run kick 38?32, tangent limit 32?26 and carry limit 44?36 studs/s. Wall-run kick momentum fraction 1?0.9. Every profile's JumpPower/gravity, flip upward launch, wall-kick upward launches and wall-climb parameters are unchanged.
- **Verified offline:** full movement/foundation checks and private build pass; direct comparison with the ignored v7.38 checkpoint confirms unchanged vertical launches and slide timing/decay settings. A fresh Studio window opens `build/SlugshotMovementLabPrivate-v7.39.rbxlx`.
- **Unresolved:** actual distances, animation cadence/foot slide, camera comfort, flips finishing cleanly near touchdown, wall corners and peer presentation. See [evidence](movement-verification.md#v739-slower-movement-pace-2026-10-31).

## What changed in v7.38 (uneven walls and corners)

- **Confirmed:** owner wants small wall bumps/ledges to carry a smooth wall run and a short animated turn around corners.
- **Implemented:** look ahead up to 5 studs for parallel protrusions up to 0.85 studs deep and move outward with velocity, rather than teleporting through them. Side support probes at root height and ?1.1 studs bridge thin horizontal seams; missing support has 0.12 seconds of grace. Larger obstacles and unsupported ends can still stop a run.
- **Implemented:** turn onto nearby inside faces before contact; at an outside end, detect the adjacent face and round the shared edge at the wall-hug radius. Outside turns cap travel at about 14.7 studs/s, support stopping/reversing, and retain jump-off. A brief procedural crouch, bank and head turn follows the actual body rotation on local and peer rigs.
- **Implemented:** a blue wall with orange raised strips and a thin ledge at X?-90; a square corner tower near (-55, -78), and an L-shaped inside corner near (-12, -80). Jump onto them as on the existing corridor; test both directions. The course is in the northwest part of the lab.
- **Verified offline:** formatting, lint, strict Luau and public/test/private builds. New engine-raycast fixtures cover flat support, small versus large protrusions, both corners, distant ends, opt-outs and moving-part rejection; they have not run in Studio.
- **Unresolved:** actual input/physics/animation and peer behavior, correction counters and subjective smoothness. This targets static, near-vertical part geometry; arbitrary sloped terrain, moving platforms, acute corners and all map shapes are not established. See [evidence](movement-verification.md#v738-uneven-walls-and-corners-2026-10-31).

## What changed in v7.37 (drag limb spacing)

- **Confirmed:** the owner likes the overall positioning, but the wall-side shoulder looks compressed and the legs still look odd.
- **Implemented:** the raised R6 wall arm is offset slightly out and up as the drag pose blends in, reducing overlap at the torso. The free leg angles sideways less, separating the two legs while keeping their overall direction. Other actions and wall-drag movement are unchanged.
- **Verified, limited:** automated movement checks pass. In one Studio client, the R6 wall drag was visually inspected and its oriented blocks measured: leg separation about 0.09 studs and shoulder/torso overlap about 0.31 studs. Exact fit varies during blending; opposite-wall presentation and the owner's subjective verdict remain open. See [results](movement-verification.md#v737-drag-limb-spacing-2026-10-30).

## What changed in v7.36 (wall drag legs)

- **Confirmed:** the owner likes the body and arm placement, but the legs looked bent forward; they should angle to the side like the supplied Mario reference.
- **Implemented:** both R6 legs now angle sideways toward the wall rather than forward, mirrored by wall side. The torso and arm pose, drag behavior and wall spacing stay the same. R6 legs are single rigid blocks, so they cannot bend at a knee.
- **Verified, limited:** automated movement checks pass; a one-client Studio probe reached the wall-drag action, and the real R6 leg orientations were measured. The Studio capture was blank, so the appearance and the other wall side still need the owner's review. See [results](movement-verification.md#v736-wall-drag-legs-2026-10-30).

## What changed in v7.35 (first jump and drag pose)

- **Confirmed:** the owner reports that stopping on a wall now works, but the drag pose looks flat against the wall with dangling legs. The first jump should travel a little farther, with a smaller height increase; the request does not change the double jump.
- **Implemented:** the ground-jump arc is slightly longer and the normal jump's in-air speed target is 8% higher with movement input. Double-jump launch settings are unchanged. The drag holds the root farther out, leans the body away, and raises the wall-side arm and leg; the free leg is also raised. R6 limbs cannot bend at the knee or elbow.
- **Verified, limited:** a single Studio probe comparison measured approximately 13.9 to 15.8 studs of travel and 10.0 to 10.9 studs of peak height for running first jumps; this is one sample per build, not a controlled frame-rate study. One wall-side pose was viewed in Studio before the final free-leg adjustment. Subjective pose quality, mirrored wall contact, and live double-jump regression need owner review. See [evidence](movement-verification.md#v735-first-jump-and-drag-pose-2026-10-30).

## What changed in v7.34 (front flip refinement)

- **Confirmed:** the owner requested a substantial improvement to the existing front flip, rather than necessarily a new move.
- **Implemented:** the chosen front full step-out retains its original spin, twist, timing and directional mapping. Its arms now sweep asymmetrically through the twist and recovery, and the legs separate earlier into the step-out. Other directions are unchanged. Subjective quality is awaiting the owner's Studio playtest.
- **Confirmed workflow:** rebuild and reopen the updated Studio place for the owner after playtestable changes.

## What changed in v7.33 (wall input and drag)

- **Confirmed:** the owner still experienced running without W and a roughly two-second delay after releasing it, and rejected the drag pose in the supplied references.
- **Implemented:** attachment and steering now use current input instead of the smoothed locomotion vector. A catch without run input starts with zero along-wall speed; releasing input uses the fast stop rate instead of slow speed bleed. The pose measures motion along the actual wall, and no longer expires after 12 seconds while still attached.
- **Considering:** the original R6 drag pose now reaches the wall arm higher and back, with the free arm and leg forward. It is a new interpretation of the reference, not a verified match; the block rig cannot bend its limbs like the pictured character.
- **Verified, limited:** in a single Studio client using the movement probe, a no-input catch had no along-wall velocity, and a 34-stud/s run stopped along the wall within 0.1 s of releasing the probe input. Running resumed. Pose appearance, real keys, jump-off, mirrored walls and multiplayer need review; see [results](movement-verification.md#v733-wall-input-and-drag-2026-10-30).

## What changed in v7.32 (slide at once, pose refit)

- **Owner:** after stopping a wall run, it took a solid 2 seconds to start dragging down, when it should be almost instant. The v7.31 pose was not accurate at all.
- **Causes:**
  - With Space held, stopping kept climbing (v7.28 ran straight up with no direction and Space held) until the climb allowance ran out.
  - The pose blend measured the whole horizontal speed, including the pull toward the wall, so it barely blended in and showed a mix of the run and the slide.
- **Fixes:**
  - Whenever the run along the wall is below 6 studs/s, the body slides straight down, whether or not Space is held. Running up the wall with Space still works while moving along it.
  - The pose blend uses only the speed along the wall.
- **Pose refit**, after the owner's references:
  - The body is turned three-quarters (65°) away from the wall, looking out.
  - The wall-side arm goes out flat and back, with the hand on the wall at head height (it was above the head).
  - The other arm is out in front, and the wall-side foot is against the wall.
  - The body is held 1.2 studs from the wall. Fitted at the blocks' corners: hand and foot within 0.04 studs of the wall, nothing else within 0.3.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.31 (wall slide pose, instant stop)

- **Owner** (with two reference images of a classic platformer wall slide):
  - The pose should be exactly that: back to the wall, one hand flat on it behind, the other arm out in front.
  - The hand was halfway through the wall.
  - The slide should go directly down. Letting go of W after landing on a wall (or mid-run) should go straight into the slide, not keep running for a moment.
- **Wall slide pose**, replacing v7.30's face-the-wall cling:
  - The body turns 75° away from the wall with a slight lean into it, facing out.
  - The wall-side hand reaches back and up, planted on the wall above the head; the other arm is out in front.
  - The wall-side foot is against the wall, the other a little forward, with a slight sway.
  - It is mirrored for walls on the left, and eases in over about 0.1 s.
- **Fit:** on the R6 renderer for the body 1.1 studs from the wall (`WallRun.Cling.Hug`), measuring contact at the blocks' corners. The hand's corner touches the wall (0.02 studs) and the foot touches; no other part comes within 0.3.
  - v7.30 measured the hand at its end's centre, so half the block sank into the wall.
- **Instant stop:**
  - Letting go of the run input stops at 400 studs/s² (`WallRun.Stop`; 34 to 0 in under 0.1 s).
  - Holding the run input still runs, and a faster attach still bleeds down slowly.
  - The slide reaches its 4 studs/s drag at 200 studs/s² (`WallRun.Cling.Accel`), so it goes straight down.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.30 (cling pose)

- **Owner:** the drag looked really bad (the feet half on the wall, still running while sliding down). It should look like a controlled drag: a Spider-Man-like cling with one hand on the wall and one arm off it, the feet stuck to the wall, slowly dragging down. Stopping a wall run should come to a stop quickly, then drag the same way. Jumping off works at any time.
- **Cling pose** (`Presentation.wallRunPose`), blended in as the speed along the wall drops below 6:
  - The body turns to face the wall, with the right hand planted on it overhead and the left arm hanging out off it.
  - Both feet are against the wall, staggered, and the head looks down.
  - The loose arm and legs sway slightly while dragging.
  - Fitted on the R6 renderer: the hand and feet within about 0.15 studs of the wall, the hand at head height.
- **Distance:** while clinging, the body is held 1.2 studs from the wall (`WallRun.Cling.Hug`; 2.1 while running) so the hand and feet reach it.
- **Stopping:** letting go of the keys stops the run quickly, from 34 to 0 in about 0.3 s (`WallRun.Steer` 120, was 70).
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.29 (cling and slow drag)

- **Owner:** jumping onto a wall and doing nothing (no running, no jump off) should stay on it and slowly drag down. The same applies after stopping a wall run.
- **Cling:** moving into a wall (faster than 4 studs/s) or holding into it while airborne now attaches without running along it, unless there is a ledge in reach to mantle. The usual 2-stud minimum height and re-attach delay still apply.
- **Slow drag:** below 6 studs/s along the wall without Space held, the body drags down at a steady 4 studs/s (`WallRun.Cling`), instead of the slide speeding up.
  - Holding Space still climbs.
  - Steering along the wall runs.
  - Pressing Space while holding away kicks off.
- **Legs:** the run cycle slows to a stop as the speed along the wall drops, instead of running in place.
- **Change of behaviour:** a press while holding into a clung wall now climbs, rather than the old up-kick leap.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.28 (wall-run steering)

- **Owner:** once a wall run started there was no control over its direction. Letting go of W still ran on the same way; only Space did anything.
- **Steering:** the input sets the run along the wall.
  - Holding along it runs at 34 studs/s; pushing into the wall counts as forward.
  - No input slows to a cling. With Space held, that means running straight up the wall.
  - Input back along the wall brakes, turns round and runs the other way. The body turns smoothly, and the arm moves to the wall's side.
  - Speed changes at 70 studs/s² (`WallRun.Steer`). A faster attach bleeds down at 12 (`WallRun.Bleed`), keeping the momentum.
- **Presentation:** the wall's side is found each frame, so other players see the arm on the right side after a turn. The run cycle follows the real speed along the wall.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.27 (crouch removed)

- **Owner:** remove crouch as a feature for now, from everything.
- **Removed:**
  - the C / gamepad R3 binding and the client's crouch state, speed and camera dip;
  - the server's `Crouch` request and the `Crouching` attribute;
  - the presentation's crouch clips, crouch idle and crossfade;
  - the original R6 crouch clips and the config;
  - the Studio probe's `Crouch` command and the HUD entry.
- The private manifest already had no crouch clips (v7.25).
- `verify_movement.py` passes.

## What changed in v7.26 (a real squat)

- **Owner:** the v7.25 crouch was horrible. It did not squat at all, it just stayed standing and walked slowly.
- **Cause:** ground contact only pushes the body up out of the floor (`GroundContact.PullDown = false`). A staggered stance of straight block legs barely lowers the hips, and the clip dropped the body only 0.5 studs, so it read as standing.
- **Squat:**
  - Both block legs angle about 60° forward like thighs, knees apart. The hips drop 1.2 studs (contact lifts back about 0.25, so it nets about 1 stud lower).
  - The chest leans 34° over the knees, the head up and the arms resting forward.
  - It breathes while idle.
- **Moving:**
  - A low duck walk, with the legs alternating between about 54° and 70° forward. A wider swing lifts the body more, since straight legs that come nearer vertical push the hips up.
  - Side-steps open the leading knee out.
  - Still 13 studs/s.
- **Camera:** it dips 1 stud while crouched (`Crouch.CameraDrop`), so the squat also reads from behind.
- Checked with `tools/r6pose/preview.py`. `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.25 (original R6 crouch, a bit faster)

- **Owner:** the front full step-out is perfect. The crouch animation was horrible: its arms looked like they were holding an imaginary gun. The crouch should also be a bit faster (noticeably, not much).
- **Original R6 crouch set** (`crouchIdle`, `crouchForward`, `crouchBack`, `crouchLeft`, `crouchRight`) replaces the owner's Mixamo crouch:
  - Idle: a low staggered stance (left foot forward, right back), leaning in, head up, arms relaxed and hanging a little forward, breathing.
  - Walk: quick, short sneaking steps with a gentle opposite arm swing; backing up is more upright.
  - Sideways: side-steps, the leading leg reaching out.
  - R6 legs are blocks, so the stance is a stagger rather than bent knees, and the walk bobs a little as the legs pass.
  - Checked with `tools/r6pose/preview.py`.
- **Into and out of the crouch** is a 0.3 s crossfade; the mocap stand-up clips are no longer used. The workaround for the mocap crouch idle (its hands dropped to the floor) is removed.
- **Speed:** 13 studs/s (was 10), with the step rate matched so the feet do not slide.
- The public build now has the crouch too. The private manifest drops the 7 crouch clips (12 entries, 14 clips with the mirrored wall jumps); private clips regenerated.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.24 (front full step-out chosen)

- **Owner:** picked the front full step-out ("really nice"). They want it a fraction faster (not noticeably), and the face should not look back at the camera during the flip.
- **Face:** the twist lagged the somersault (110° of flip with 20° of twist), so partway round the face turned back toward the camera. The twist now follows the somersault exactly (identical keys). The face is then always away from the camera or side-on: its backward component is -cos²(angle), never toward the camera.
- **Speed:** about 4% faster (rotation done by 0.46, was 0.48).
- The twisting aerial, X-out full, their poses and the G key are removed.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.23 (twisting front flip candidates)

- **Owner:** the front aerial did not work. The front flip needs more spin to match the rest, and must not be a basic front flip.
- **Research:** front full twist technique ([FlashMavi](https://www.flashmavi.com/learn/how-to-do-a-front-flip-full-twist-gymnastics)). Kick the heels up with the arms slightly open, close the arms in front of the chest to twist with the head turned, then open and lift the arms to stop.
- **Candidates on G**, each twisting a full turn spread over most of the flip (about 1100°/s) through open shapes; the v7.20 twist kick was too fast to see:
  1. **Twisting aerial** (`FlipFront`): the front aerial's split and windmilling arms. It twists a full turn as the arms wrap in, then flings them open to land.
  2. **Front full step-out** (`FlipFront.2`): a winged layout. The arms snap across the chest to twist a full turn, fling open and up, and the legs split to step out.
  3. **X-out full** (`FlipFront.3`): a tuck that bursts into a wide X. The X spins a full twist like a star, then closes to land.
- All three were rendered on the R6 renderer before porting.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.22 (front aerial chosen)

- **Owner:** use the front aerial, ever so slightly faster, with a bit more flair.
- **Faster:** the rotation now finishes at 0.44 (was 0.48), peaking near 1100°/s at rate 1.
- **Flair:** the arms windmill through the split. The right arm reaches overhead along the body while the left sweeps back wide; they swap at the top. The head is thrown back further at the peak. Checked on the R6 renderer.
- The layout step-out, X-out and the G key are removed.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.21 (researched front flip candidates)

- **Owner:** none of the v7.20 candidates. The twist kick was so fast the animation was hard to see. They asked for research into how nicer, acrobatic front flips look before making them.
- **Research** (gymnastics and tricking references):
  - The **front aerial** keeps the legs extended and split along the rotation plane, while the inverted torso stays put and the legs rotate around it.
  - The **front layout** keeps the body straight with a slight hollow, the arms spread like wings at takeoff and the heels kicked up. It lands with the arms rising.
  - A **step-out** splits the legs mid-flip and lands one at a time.
  - An **X-out** splits the arms and legs across the rotation plane into an X.
  - Sources: [Flip (acrobatic)](https://en.wikipedia.org/wiki/Flip_(acrobatic)), [Front aerial](https://en.wikipedia.org/wiki/Front_aerial), [FlashMavi: front flip layout](https://www.flashmavi.com/learn/how-do-do-a-gymnastic-front-flip-layout), [Double Leg (trick)](https://en.wikipedia.org/wiki/Double_Leg_(trick)).
- **Candidates on G** (the HUD shows the current one):
  1. **Front aerial** (`FlipFront`): the rear leg kicks up and over in a wide split, the torso arched with arms swept back and out, landing on the kicking leg first.
  2. **Layout step-out** (`FlipFront.2`): a straight, winged body with the heels up, splitting late to step out, arms rising to land.
  3. **X-out** (`FlipFront.3`): a quick tuck that bursts into a wide X held at the top (the spin slows while open), then closes to land.
- **Speed and checks:**
  - All three spin at about 1000°/s or less (the twist kick peaked near 1650° plus its twist), through open shapes that read at game speed.
  - They were rendered on the R6 block renderer before porting.
  - The old flip kick and the v7.20 candidates are removed.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.20 (front flip candidates)

- **Owner:** the front flip (the flip kick) looked underwhelming and out of place next to the other flips.
- **Cause:** it was the only flip with no twist. The back, diagonals and sides all spin in a twist.
- **Three candidates**, cycled with **G** in the lab (the HUD shows the current one). The owner picks one; the others are then removed:
  1. **Twist kick** (`FlipFront`): the tuck spins a full twist, with one arm thrown overhead so the twist reads, then snaps open into the held flying kick.
  2. **Tornado kick** (`FlipFront.2`): a faster front tuck that opens into the kick and spins a full turn about the body, the kicking leg sweeping round, before landing.
  3. **Star full** (`FlipFront.3`): a front flip in a wide star (arms and legs out) that snaps in to twist a full turn, then opens back into the star to land.
- The old flip kick is no longer used.
- **HUD text fixed:** a PowerShell edit in v7.14 had garbled the separators (`Â·`). They are restored.
- `verify_movement.py` passes; not yet run in Studio. The new flips were not checked on the renderer (they are built by the flip generator, which the preview tool cannot read).

## What changed in v7.19 (subtler sprint shake)

- **Owner:** the v7.18 shake was really bad. It should be very subtle but noticeable, with no tilting side to side.
- The roll and side wobble are removed. Only a 0.05-stud bounce on each footfall remains (was 0.12), sprinting on the ground only.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.18 (clearer sprint)

- **Owner:** make it more obvious when you are sprinting rather than running: a little shake, not too much, and a slower normal run (22).
- **Run speed:** 22 studs/s (Athletic; was 24). The sprint stays at 30, and the run and sprint clips separate more.
- **Sprint shake** (`Camera.SprintShake`), sprinting on the ground only, eased in and out:
  - a 0.12-stud camera bounce on each footfall;
  - a 0.06-stud side wobble;
  - a 0.7° roll swaying once per stride.
- **Sprint field of view:** 78 (was 74; normal is 72).
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.17 (wall-run top: hold, press to mantle, press to jump off)

- **Owner:** holding Space up a wall run mantled onto the top automatically, which was annoying. Holding should keep running along the top. A fresh press should mantle, and a press aimed off the wall should jump off.
- **Holding Space at the top:** once nothing is beside the head (1 stud above the root, `WallRun.TopMargin`), the climb stops rising and the run holds its height along the top edge. Letting go slides down as before.
- **A fresh press on a wall run:**
  - Holding away from the wall, or back against the run: jumps off at once.
  - Otherwise: mantles over the top when it is in reach.
  - Lower down, it climbs while held, and a tap still kicks off on release.
- **The end of the wall** now drops you off instead of mantling.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.16 (wall runs, kicks and mantles out of a flip)

- **Owner:** after v7.13 a jump onto a wall attaches at once, but a double-jump flip onto a wall still slid down it before the run caught.
- **Cause:** the flip counted as a busy action until it finished. Wall runs, air wall jumps and mantles all waited for it.
- **Fix:** a flip now gives way immediately to a wall run, a wall jump or a mantle. The flip animation hands over with the action's usual fade.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.15 (vault keeps its momentum; animated start)

- **Owner:** the vault itself was fine, but the part after it was slow and the frictionless movement stopped. They also wanted the start more animated.
- **Causes:**
  - A vault always landed 2.4 studs past the wall, over a time set by the wall's height: about 13 studs/s against a 24-30 run.
  - The clip's travel curve also eased to a stop at the landing before the run speed was handed back.
- **Momentum:**
  - The vault keeps the approach speed. Its time is set so the hands plant (`Vault.PlantAt`) as the body reaches the wall at that speed, within 0.4-0.7 s (`Vault.Time`).
  - The landing is as far past the wall as the speed carries, up to 8 studs (`Vault.MaxLand`), and only on open ground; otherwise the old 2.4.
  - Travel is even: the face is reached at the plant and the landing at the end, with no easing, so the run carries straight on.
  - At 27 studs/s from 3 studs out: a 0.43 s vault landing 7 studs past a 1.6-stud wall.
  - The server's vault reach check uses the longer maximum landing.
- **Animated start:**
  - The takeoff winds the arms back with the lead knee driving up.
  - The arms whip forward as the body tips into the dive, then the superman reach.
  - The plant is now at 0.15 of a 0.58 s clip.
- **Contacts** (`preview.py kongVault --vault 3 --depth 1.6 --approach 3 --land 7`): hands on the top at 0.13-0.15 s, feet just over the near edge at 0.18 s, and every foot below the top is past the far side.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.14 (a more animated kong vault)

- **Owner:** make vaults more animated and parkour style.
- **The kong vault** (short walls) has 9 keys instead of 6, and 0.55 s of clip (the real time still follows the wall height):
  1. A driving takeoff, with the knee up and arms swinging.
  2. A stretched superman dive with the arms reaching long.
  3. A head-down plant with the hips high.
  4. A tight tuck of the knees through the arms.
  5. A hard push-off as the arms punch back and the chest lifts.
  6. A flying stride, with the lead leg reaching, the trail knee still up and the arms thrown open.
  7. Reaching for the ground.
  8. A one-foot touchdown leaning into the run.
  9. Into the stride.
- **Contacts checked** with `tools/r6pose/preview.py kongVault --vault 3 --depth 1.6` (which now also reports how far past the face the feet are):
  - Hands on the top at 0.09-0.11 s, 0.6-1.3 studs past the face.
  - The feet clear the near edge at 0.14 s.
  - Whenever a foot is below the top, it is past the far side.
  - A first version swung the trail leg back too early and passed it through the far edge; the trail knee now stays up until clear.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.13 (responsive wall runs and wall jumps)

- **Owner:** jumping onto a wall to run on it always attached after a slight delay, and lower than where they tried to connect. Wall jumps felt even less responsive.
- **Causes:**
  - A wall run could not attach until 0.13 s after leaving the ground, and attaching capped the upward speed at 13 (30% of the jump's), so the body stuck below the jump's path.
  - An air press near a wall became the double-jump flip whenever the kick was not ready yet (just out of reach, within 0.13 s of takeoff, or in the 0.15 s cooldown), so the kick never came.
  - A kick off a wall run fired only when Space was released (holding climbs).
- **Fixes:**
  - The wall run attaches from 0.03 s after takeoff (`WallRun.GroundDelay`; the 2-stud minimum height still keeps it off the floor). It keeps 55% of the jump's rise, up to 20.
  - Air wall jumps can fire from 0.06 s after takeoff (`WallHop.GroundDelay`). An air press with a wall in reach, or one the body is moving toward and will reach within the 0.35 s buffer (looking up to 4 studs further), waits for the kick instead of being spent on the flip.
  - On a wall run, pressing Space while holding away from the wall (`WallRun.KickAway`) kicks off on the press. Holding along or into the wall still climbs, and a tap still kicks on release.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.12 (running landings, strafe reversals)

- **Owner:** landing from a wall jump and running straight away showed the legs spread, and should flow into the run, not cut. Strafing left then straight to right cut from one clip to the other.
- **Running landings:**
  - The landing clip was still blended in at about 45% while running, which spread the legs; it now fades out completely when moving (`Land.MovingScale = 1`).
  - The switch from the air pose to the stride is a 0.22 s crossfade (`Fade.LandMoving`; was 0.08).
  - Landings standing still are unchanged.
- **Direction changes:** reversing a strafe passes the velocity through zero, so the travel angle, and with it the blend, flipped from the left strafe to the right in one frame. Each direction clip's weight now eases toward its target (`DirectionBlendRate = 10`, about 0.2 s), so the hips turn through the middle instead of cutting. The same smoothing applies to any direction change, such as run to back-run.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.11 (faster wall run, further wall jumps)

- **Owner:** the wall run was quite slow. Wall jumps should go further, since you have momentum and a wall to push off.
- **Wall run:** the minimum speed on the wall is 34 studs/s (was 26; sprint is 30).
- **Kicks off a wall:**
  - From the air: 40 studs/s out (was 30), keeping 80% of the along-wall speed (was 55%, now capped at 32).
  - Off a wall run: 38 out (was 28), keeping all of the run's speed (was 85%).
- **Momentum:** after the kick's 0.22 s lock, the speed was cut to sprint speed (30), which lost most of the push. It now keeps up to 44 studs/s (`WallHop.MaxCarry`). It bleeds in the air at the slide-jump rate and brakes on landing. Dropping off a wall run keeps its speed the same way.
- Every speed stays under the server's 56 studs/s cap. `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.10 (jumping off edges)

- **Owner:** standing on the edge of a ledge or wall and pressing Space sometimes did the double-jump flip instead of the first jump.
- **Cause:** the Humanoid's floor check can miss the ledge under the feet at an edge and report the body as falling. The press then took the air path (the flip), and the Humanoid's own jump would not fire. Walking off an edge and pressing a moment late did the same.
- **Fix:**
  - A jump press is a ground jump while anything is under the body's footprint (a 1-stud sphere below the root, `Acrobatics.Jump.Footprint`), or within 0.15 s of walking off without jumping (`Acrobatics.Jump.Coyote`).
  - When the Humanoid thinks it is falling, the client launches the jump itself, at the profile's jump power.
  - The same footprint check restores the flip and kicks on landing.
- **Server:** the touchdown and ground checks use the same footprint, so an edge jump is not mistaken for an unearned air boost. The air-boost check now starts 0.35 s after leaving the ground (was 0.25), to cover coyote jumps.
- `verify_movement.py` passes; not yet run in Studio.

## What changed in v7.9 (light server authority)

The owner chose the light option: clients keep running their own movement, so it stays responsive, but the server corrects movement that nothing can explain.

- **Unearned air jumps:** an upward boost while airborne (over 25 studs/s between 0.1 s samples, more than 0.35 s after leaving the ground) needs an accepted action within 0.6 s of it: a double jump, wall kick, wall run or mantle. If none arrives, the character is snapped back to where the boost started, with no velocity.
- **Through walls:** if the straight path between two samples crosses an anchored, collidable part, it needs an accepted mantle or vault around that time (mantles carry the body over geometry). Otherwise the character is snapped back to the last position before the wall.
- **Upward speed cap:** over 75 studs/s it is clamped to 75 (the fastest real launch is the 62 jump).
- **Kept:** the horizontal speed cap (56) and the teleport check.
- **Timing:** each suspect is resolved 0.6 s after it is seen, so a request that arrives a little after the motion it caused still counts. Nothing is checked in the 3 s after spawning.
- **Counting and switches:** every correction counts in `MotionCorrections`, plus `SuspectAirBoosts` or `SuspectWallPasses`. The HUD shows `Corrections`. Each kind can be switched off in `Config.Validation.Corrections`.
- **Limits:**
  - A client that ignores the server's teleport can keep sending its own position. Enforcing against that needs server ownership or kicks (the strong option).
  - An honest player is snapped back only if their action was rejected (rare; for example a double jump the server thinks was already used).

## What changed in v7.8 (cleanup pass)

The owner asked for every problem from the whole-system review to be fixed before committing.

- **Ground roll removed** (owner: not used any more). Removed: the roll and landing-roll code, its config, server validation, presentation handling, the three original roll clips, the private roll mappings and the probe's `Action` command. The double jump is now the only flip, so the flip's minimum-lift option went too.
- **Dead references removed:**
  - start, stop and turn transitions whose clips no longer exist;
  - diagonal sprint and jog clip names;
  - the hanging climb (`MantleHang`, `HangHeight`);
  - the old R15-era `Idle` clip, always shadowed by `Stand`;
  - the rejected flip trail;
  - `OriginalClips.replaces` and the unused private mappings (breathing idle, falling idle, motion-capture mantles and vault). The private clips were regenerated: 21 clips.
- **Full type check:** `verify_movement.py` now type-checks every movement script in strict mode against the Roblox API, using pinned luau-lsp 1.70.1 definitions (downloaded with a hash check into ignored `.tools/`) and a sourcemap. It previously checked one 17-line file. The 26 errors it found were fixed; they were typing gaps, not behaviour bugs.
- **Ledge detection:** forward rays at four heights (knee, waist, chest, head) and in three lanes across the body. If the deep probe of the top finds nothing usable, it probes again closer to the edge. Thin floating slabs, narrow pillars and ledges met off-centre are now found. The knee-height centre ray is still tried first, so existing ledges behave as before. Two test pieces were added east of spawn: `FloatingLedge` and `NarrowPillar`.
- **Per-frame work:** the presentation's debug attributes are written only in Studio, and the client and server reuse their ray settings instead of building them every frame.
- **Air-boost detection (server, counting only):** while a player is airborne, any rise in upward speed of over 25 studs/s between 0.1 s samples is counted in `SuspectAirBoosts` unless an action was accepted within 1 s of it. So is any upward speed over 75. Nothing is corrected: client physics is still trusted (see the boundaries below).
- **Pose tools** moved into the repo (above).
- **Private clip audit on R6:** nothing is broken. The landing (deep forward slump, arms out) and the crouch set (hunched, arms held out) read most like mocap on R6, so they are the first candidates for original replacements if the owner wants them.

## What changed in v7.7 (mocap neck stretch, layered on the idle)

- **Owner, 2026-10-30:** the original neck stretch looked weird. Use the owner's Mixamo clip instead and make the transitions smooth, so it does not look like idle → neck stretch → idle. Remove the dust-off.
- **Clip:** `NeckStretch` is now the private Mixamo "Neck Stretching" (3.2 s, manifest entry, no trim). The original R6 NeckStretch and DustOff are deleted. It is the only fidget: after 6-10 s standing still. The public build has no fidget.
- **Layered, not blended:** the clip's own stance differs from the R6 idle (shoulders 38-47°, hips 19°). A full blend pulled the body into that stance and back, which is what read as three separate states. The fidget now adds only the clip's motion since its first frame on top of the live idle (`Clips.layer`, `move.additive`). The idle keeps rocking and breathing, and the clip's body motion is under 5°, so the change is almost all head (up to 39°). That motion starts and ends at zero, eased in over 0.5 s and out over 0.6 s.
- **Studio check (private build, F5, standing still 18 s):** the stretch played twice. The left arm stayed within 6° of where it started, so the body kept the idle stance. The head never moved more than 10.4° in 0.1 s, so there were no snaps. Frames showed the head tilt and roll with the body unchanged. Whether it reads well is the owner's call.
- A spec checks that layering starts on the base pose and scales the clip's motion by weight.

## What changed in v7.6 (leg spacing, calmer idle, idle fidgets)

- **Legs:** at 0.15 studs the legs looked disconnected. With the idle's 7-degree stance, the tops stuck out past the torso. `Avatar.LegSpread` is now 0.06: a small gap, with the outer edges nearly flush with the torso.
- **Idle arms:** the owner said they moved too much. Each shoulder now keeps about a third of its old swing around the rest pose (arms 10 degrees out), and the arm shake is now barely visible. The weight rock, head looks and chest lift are unchanged.
- **Idle fidgets:** after standing still for 6-10 s, the character plays one of two original R6 fidgets, alternating between them:
  - **NeckStretch (3.4 s):** tilts right with the left shoulder pressed down, rolls the head forward and over to the left, looks up with the chest lifted, then shakes out.
  - **DustOff (2.75 s):** looks down; the right hand swipes down the left side of the chest twice, then the left hand the right side; both hands brush down the thighs, then flick out.
  - Hand positions were fitted on the R6 renderer.
- **Fidget blending:** each fidget starts and ends on the idle's centre pose. It eases in over 0.5 s and out over 0.6 s, on top of the live idle (`Animation.Moves.Fidget`). Moving, crouching or aiming cancels it with the usual 0.25 s crossfade. Fidgets do not play while injured.
- A spec checks that both fidgets exist and end where they start.

## What changed in v7.5 (wider legs)

- The owner said the legs looked narrow and asked for them further apart, not splayed into a V.
- Each R6 hip joint now sits 0.15 studs further out (`Avatar.LegSpread`), set on the server when the character is built. The legs stay parallel, with a 0.3-stud gap between them, and their outer edges sit just past the torso's.
- The presentation reads joint offsets from the rig, so poses and floor contact follow. The prototype renderer uses the same spacing.

## What changed in v7.4 (fall transition, R6 mantles)

- **Into a fall:** the owner said stepping off stairs cut straight to falling, unlike the smooth wall-run kick-off.
  - Cause: on leaving the ground the air state reset, and a crossfade only started on a later change, so the first air pose snapped in.
  - Walking off an edge now keeps the run going and eases into the fall over 0.3 s (`Animation.WalkOff`), so short drops down stairs stay in the run.
  - A jump's takeoff now fades in over 0.12 s.
- **Mantles:** the owner said wall-run mantles lasted "like 0.01 seconds" and the short-wall vault was horrendous. They asked for research into parkour and acrobatic mantles, and for them to be smooth, visible, frictionless and not slow.
  - Causes: the durations were 0.2-0.3 s (from an earlier "faster" request). The clips were R15 originals whose bent limbs fold oddly on R6, plus private mocap (Sprint To Wall Climb, Climbing, Vault Over Box) that clashes on R6.
  - The new clips are original R6, modelled on parkour technique: the climb-up (grip, pull the chest over, transfer onto the hands, a leg onto the top, stand), the step vault and the kong vault.
  - They were checked frame by frame against the ledge with the client's root path. The hands meet the top at the plant (within about 0.1 studs for typical heights), and the feet clear the obstacle.
  - **Climb-up** (MantleHigh, 0.55 s; also for hang heights): catch, pull, lean over onto the hands, step up, stand into the run.
  - **Step-up** (MantleLow, 0.4 s): right hand plants, left foot onto the top, right leg swings through.
  - **Pop-up** (MantleVault, 0.45 s; when a jump or wall-run kick nearly reaches the top): both hands slap the edge, the legs tuck up through, the feet land on top.
  - **Kong vault** (Vault, 0.5 s; the thin low walls): a head-down dive onto both hands, the legs tucked through, push off, land running, at a near-constant forward speed.
  - Private clips under these names are no longer loaded (`OriginalClips.replaces`).
  - Durations are now 0.38-0.6 s (`Mantle.Duration`), and the closing of the gap to the wall eases out so the approach speed carries in.
- Research sources: Wikipedia (Vault, urban movement), Breaking Muscle (parkour climb-up), Wikibooks (speed vault), MovNat (vaulting guide), a mocap guide on climbing animation (height-matched mantles, motion warping), and an itch.io developer note on ledge-climb timing.
- `verify_movement.py` passes. Not checked in Studio by me.

## What changed in v7.3 (Restless idle, running jump back)

- **Idle:** the owner picked Restless and asked for more animation. It is now a 7.2 s loop keyed every 0.6 s. The weight rocks foot to foot and the head looks around, once back over the shoulder. The arms swing loose and shake out once, and the chest lifts with the shoulders rolled back. Battle, Swagger and the G key are removed.
- **Jumps:** the owner missed the mocap running jump. It only looked wrong when walking off stairs, where the arm shot up the moment the feet left. Real jumps play the mocap jump again. The R6 `Air` clip (calm, arms out) and the long-fall flail apply only when walking off an edge.
- **Cause of the stairs case:** a fall counted as a jump when it started rising faster than 10 studs/s, and stepping off the top of a staircase can. It now needs `Animation.StepRise` (30 studs/s); jumps launch at 50-62.
- Checked on the R6 renderer (idle key poses); `verify_movement.py` passes.

## What changed in v7.2 (air, idles, strafes and back-run)

- **Falls:** the owner said the right arm shot up on every fall, so short drops looked like skyscraper falls. Airborne poses came from the private mocap jump, and any fall held its apex, which has an arm up. An original R6 `Air` clip now drives jumps and falls: a takeoff, a running leap, a balanced apex with the arms out, a calm fall and the reach for the ground. A flailing `FallLong` loop fades in only after 0.6 s of falling (`Animation.LongFall`).
- **Idles:** the owner found the v7.1 idles basic. They are replaced by bolder stances (G cycles them):
  - **Battle:** a fighting stance turned 25°, lead leg and arm forward, rear arm back as if ready to sling, rocking.
  - **Swagger:** weight on the back leg, front foot out, chest turned, nodding and looking.
  - **Restless:** rocking foot to foot, looking around, arms swinging loose.
- **Strafes and back-run:** the owner found them underwhelming and slow next to the run. The old strafe was a short-stride cycle built for 16 studs/s and played at 24 (the cadence was capped), and the back-pedal was small and upright. Both now come from the run generator at its cadence:
  - The strafes turn the hips 60° into the travel, with the chest turned 75% of the way back and the head facing the camera.
  - The back-run is the run played backwards, upright, with a shorter reach.
  - The old strafe and block back-pedal code is removed.
- Checked on the R6 renderer (air poses, idles, strafe); `verify_movement.py` passes.

## What changed in v7.1 (Power run, stairs, R6 idles)

- **Run:** the owner picked Power and asked for it bouncier and more energetic, unique rather than plain.
  - The flight rise is about twice as high (0.16 hip units) and springy: the top is rounded and the dip onto each foot is sharp.
  - The chest pumps forward 6° on each dip, and the heel kick is higher (34°).
  - The arms dwell at the ends of the swing for a punchier pump (reach 115°, back 75°).
  - The sprint goes further: lean 40°, reach 130° and a bigger kick.
  - Stride and Dash are removed.
- **Arm stuck up on stairs:** the presentation called the body airborne whenever it rose faster than 6 studs/s, so running upstairs played the jump's rise pose, with an arm thrown up. It now stays grounded while rising slower than a launch (`Animation.StepRise`, 30 studs/s; jumps start at 50-62).
- **Idle:** the owner saw the private Mixamo "Breathing Idle", whose slouch reads as rolled-forward shoulders on R6. Three original R6 idles replace it, preferred over the mocap (`Stand`, `Stand.2`, `Stand.3`; G cycles them):
  - **Ready:** a hero stance, chest up, arms a little behind and out, glancing side to side.
  - **Relaxed:** weight on one leg, hip dropped, free leg forward.
  - **Alert:** a wide stance, scanning left and right.
  - All three are 4.8 s loops of two breaths.
- **Into idle:** the run blends to idle about half as fast (`IdleBlendRate` 7), so stopping eases in instead of cutting.
- Checked on the R6 renderer; `verify_movement.py` passes. Not checked in Studio by me: the stairs fix.

## What changed in v7.0 (continuous run candidates)

The owner called the flips "pretty much perfect" but the run and sprint "still poo". Asked what was worst, they picked all of: stiff, robotic and choppy; the arms; the legs and stride; and the lean and posture. They asked for several runs to pick in-game, with a sprint more extreme than the run.

- **Cause of the stiffness:** the v5 run was pose-to-pose, matched to the reference's kick holds (hold, then snap). In motion it reads as freeze-and-jerk.
- **New generator (`flowRun`), continuous at 60 fps:**
  - Each leg sweeps back at a near-steady rate while planted, flicks up behind after toe-off, then swings through fast to strike.
  - The arms swing opposite the legs and lead slightly. They cross in a little going forward and flare out going back.
  - The chest twists against the hips and rolls toward the planted leg, while the head counters both.
  - The body drops onto the planted foot (so it never floats) and rises in flight.
- **Three styles** (G cycles them; the HUD names the current one). Each sprint has more lean, reach, swing and flick at a quicker cadence:
  - **Stride:** long and flowing, lean 32°, with a flaring back swing.
  - **Power:** an action-hero pump. Arms reach 105° and cross in, with a 15° shoulder turn and a bigger bounce.
  - **Dash:** a deep 42° lean, arms held back and out, quick feet.
- The v5 pose-to-pose run (`snapRun`) is removed. The run style is a local attribute, so peers see the default (Stride).
- Checked on the R6 block renderer, side and behind, for all six cycles; `verify_movement.py` passes.

## What changed in v6.9 (butterfly twist chosen, windmilling arms)

The owner picked the single butterfly twist but found the arms restricted (crossed on the chest through the twist). The arms now windmill. A wind-up swings both arms across against the turn. The wings open, then the right arm reaches overhead along the body while the left sweeps back. Both go wide at the swap, then the left is overhead and the right back, before opening to land. The double twist, the twist kick, the G key and `Config.Lab.FlipStyles` are removed; the HUD keeps a "Last flip" readout. Checked on the R6 renderer; `verify_movement.py` passes.

## What changed in v6.8 (side flips as horizontal twists)

The owner rejected all the v6.7 side candidates. Side flips should be a horizontal twist, the flat counterpart of the back and diagonal twists: acrobatic, not "a torpedo". Research (butterfly kick and twist: Wikipedia, FlashMavi's wushu tutorial, the FIG aerobic code) gave these cues:
- The upper body dips low and forward with the arms wide, and a straight leg kicks above horizontal.
- In the air the body is flat (within 45° of horizontal), the legs straddle, and the arms open like wings. The hands come together to start a full twist, and the arms open again to land on one leg.

The torpedo look came from a straight, closed body rolling in place. The new candidates, cycled with G:
- **Butterfly twist** (one twist, peak about 1650°/s at rate 1).
- **Double butterfly twist** (two twists, peak about 3300°/s).
- **Twist kick:** one twist, then the held flying side kick.

All three sweep a full turn about the vertical while twisting about the body's length. The left leg kicks first on a flip to the right. Checked on the R6 renderer; `verify_movement.py` passes.

## What changed in v6.7 (flip kick chosen; readable side candidates)

- **Front:** the owner picked the flip kick but found it a bit too quick. Its spin now peaks at about 1650°/s at rate 1 (was 2200). The kick lands at 0.31 s (was 0.27). It is still faster than the Webster's peak of about 1300°/s. The Webster and swan dive are removed, and so is the F key.
- **Side:** the owner said the three side candidates all looked the same. Selection was checked through the code (`FlipRight.2` and `.3` reach the presentation, and no private clip overrides them). The likely cause is that each was about 0.35 s of sideways spinning with nothing held long enough to read. They are replaced by candidates that end or pause in a readable shape:
  - **Side flip kick.** A sideways tuck that snaps into a held flying side kick toward the side.
  - **Tornado kick.** An upright turn about the vertical with one leg swept straight out.
  - **Aerial.** A no-hands cartwheel that holds a wide split upside down.
- The HUD shows the last flip played (variant and style), to confirm what played.
- Checked on the R6 renderer; `verify_movement.py` passes.

## What changed in v6.6 (acrobatic front and side candidates)

The owner found the v6.5 double front and side tuck "too basic". They want acrobatic flips, unique to the front and the side, that do not look like the back full. There are three original candidates for each, switchable in the lab so the owner can pick; the rest will be removed:

- Front (F cycles):
  - **Webster.** The rear leg kicks up and over, the legs split, and the arms sweep back like wings. It lands on the kicking leg.
  - **Flip kick.** A fast tight tuck that snaps (at 0.27 s) into a flying front kick, held into the landing.
  - **Swan dive.** It hangs flat, face down, with the arms spread, then whips round in a tuck.
- Side (G cycles):
  - **Aerial.** Folded at the waist with the legs split wide, cartwheeling with no hands (the outside leg leads).
  - **Butterfly kick.** The body goes flat and spins a full turn about the vertical, with the legs scissoring and the arms out.
  - **Barrel roll.** It dives flat toward the side and rolls a full turn about its length.
- Clip support: flip poses can tilt the whole body (`tilt`), and a style can spin about the vertical (`vertical`). Choices register as clip variants (`FlipFront.2`, `.3`), which the server already accepts.
- Checked on the R6 block renderer; `verify_movement.py` passes.

## What changed in v6.5 (double front, parkour side flip)

The owner said the diagonals are perfect. The front, back and side flips all looked alike: straight bodies twisting with the legs up. Only the back and the diagonals keep that twist now:

- S: the back full is unchanged except that the arms stay locked overhead (it was arms crossed).
- W: a double front tuck. A whip into a tight ball (legs to the chest, arms round them), two turns at up to about 2200°/s at rate 1, then a kick-out to a wide-armed, legs-split open pose before the landing.
- A/D: a parkour side flip. The outside leg kicks up and over (the left leg on a flip to the right), then a tight sideways tuck with no twist.
- Removed: the front full, the twisting cartwheel and their arms-crossed and spiral poses.
- Checked on the R6 renderer (the side flip's lead leg corrected after a render); `verify_movement.py` passes.

## What changed in v6.4 (one diagonal flip)

The owner asked for all four diagonal flips to be the S+A/S+D tilted corkscrew. W+A/W+D now use its pose, spin and twist exactly, tipping forward-diagonal, with the forward flips' stretched set as the lead-in instead of the backflip's arch. The butterfly twist and its scissor pose are removed. Checked on the R6 renderer; `verify_movement.py` passes.

## What changed in v6.3 (Ctrl shift lock)

The owner asked for a shift lock on Ctrl so they can play the moves with it. Roblox's own mouse lock is off in the lab (`EnableMouseLockOption = false`), so Shift stays free for the slide. The lab's lock does not depend on the player's Roblox "Shift Lock Switch" setting:

- Ctrl toggles it. The mouse is re-locked to the centre after the camera scripts each frame (they reset it every frame).
- The body turns to the camera's heading (rate 30) whenever no action is running. Wall runs, slides, kicks and mantles keep their own facing.
- The camera sits 1.75 studs to the camera's right. The offset is worked out in camera space, so it stays put when an action turns the body.
- Not run in Studio by me; `verify_movement.py` passes.

## What changed in v6.2 (every flip a twist)

The owner liked only the v6.1 back full ("a really cool twirl"). The front still read as a basic front flip, and the trail was disliked. Every direction is now a fast twisting spin with the back full's timing (a full twist between about 0.1 and 0.43 s), told apart by axis and shape:

- W: front full. Layout, arms locked overhead, twisting right.
- S: back full, unchanged.
- A/D: cartwheel axis with a full twist. One arm overhead, the other across the chest.
- W+A/W+D: butterfly twist. The body dives flat toward the direction (about 86°), rolls a full turn about its length with the legs scissored, and comes back upright.
- S+A/S+D: a tilted corkscrew. Off-axis back layout, legs split, one arm overhead.
- The trail is off (`Animation.FlipTrail.Enabled = false`). The v6.1 tuck, straddle, split and pike shapes are removed.
- Checked on the R6 block renderer; `verify_movement.py` passes.

## What changed in v6.1 (flashy flips)

The owner found the flips "loose tumble rolls in the air": not compact, not flashy. They asked for something much cooler and more distinctive, in Slugterra's spirit. Searches on Slugterra's action style found only episode listings, so the set follows real acrobatics and martial-arts tricking moves instead.

- **Why they looked loose:** the old flip was an R15 knee tuck. On R6 the bent knee folds into a straight leg sticking out about 45° from the body, so it never got compact. It also turned about the hips, so the body swung around a point below itself instead of spinning in place, and its spin was nearly even.
- **One distinct flip per direction** (original R6 block poses, 60 fps keys; left mirrors right):
  - W: front tuck. Legs to the chest, arms round them, then a kick-out to a V.
  - S: back full. A layout backflip with a full twist, arms crossed.
  - A/D: aerial. A cartwheel in a wide straddle.
  - W+A/W+D: off-axis front-side flip in a front-back split with the arms straight out.
  - S+A/S+D: corkscrew. A piked back-side flip with a full twist.
- **Timing:** each snaps from a stretched set into its shape by 0.13 s. It spins fastest while compact (about 1400°/s at rate 1), then kicks out and slows into the landing. The rate still matches the airtime.
- **Spin centre:** clips can set a `pivot` (hip units above the Root pivot), so flips turn about the torso's middle.
- **Trails:** pale-cyan ribbons trail off the hands and feet while a flip plays, for every viewer (`Animation.FlipTrail`, experimental, can be switched off).
- Checked on the R6 block renderer (key frames from the side and from the camera). `verify_movement.py` passes. The clip spec now checks that three flips turn the body over; that Studio test has not been run.

## What changed in v6.0 (higher, bouncier jump)

The owner asked for a noticeably higher and bouncier first jump, without frog leaps.

- Athletic JumpPower 62 (was 52) and Precise 60 (was 50). During a ground jump, gravity is 1.12 times normal (`Profiles.JumpGravity`) until the landing, a double jump, a wall kick or any other action. Athletic: 8.7 studs high (was 6.9) in 0.56 s of airtime (was 0.53). Raising the jump power alone would also have stretched the airtime and floated more. Baseline stays the stock Roblox jump.
- The mantle prediction uses the same gravity. Flips, wall kicks and double jumps are unchanged (they turn the extra pull off). Since the jump clears more, ledges up to about 1.5 studs higher are now jumped onto instead of mantled. That is for the vault and mantle pass.
- The presentation's landing reach still predicts with normal gravity, so its reach starts a few hundredths of a second late on a ground jump.

## What changed in v5.9 (faster slide, buffered input, new pose)

Owner feedback on v5.8: the slide should be noticeably (not crazily) faster; presses straight after a jump, a slide-jump or coming off a wall run were ignored until the body had settled; and the animation should look cooler.

- **Faster.** The start speed adds 15 to the current speed (at least the run speed) instead of multiplying it by 1.3, capped at 46: about 39 from an Athletic run (was 31) and 45 from a sprint. It slows to 20 (was 14) over 0.8 s, so a slide covers about 26 studs (was about 19). The FOV kick is 82.
- **No lost presses.** Cause: Shift was only accepted on the ground with no other action running, so a press in the air or on the landing frame (a flip or wall kick not yet cleared) was thrown away. A press that cannot start yet now waits 0.4 s, and while Shift stays held it waits until the body is on the ground and free; it starts the slide on touchdown. A slow press on the ground is still refused, not buffered. The cooldown is 0.25 s (was 0.4); the server allows 0.6 of it for arrival jitter.
- **New pose** (original, 60 fps keys, contacts fitted on the R6 block render): the lead leg kicks out while the body drops (0.06 s), lands low with a small overshoot and a hand plant (0.12 s), and settles. The pelvis leans back 50° with the torso a little further. The body turns toward the trailing left hand, which brushes the floor behind. The right leg lies along the ground and the left knee is up. The right arm reaches ahead and the head looks forward. It drifts while held and starts to sit up by 0.74 s, so the hand-off to the run reads as a pop-up.

## What changed in v5.8 (slide; sprint on double-tap W)

The owner chose a slide over a dash for Shift (dash judged too much movement with the double-jump flip) and dropped ground rolls. They asked for a CoD/Rivals-style slide: quick, snappy, cancellable.

- **Slide on Shift.** It needs a running speed of 12 studs/s or more. It goes the way you are moving, boosted 1.3x (capped at 40), holds speed early and slows to 14 by 0.75 s, and steers up to 1.2 rad/s. It ends on time, at a wall, or on leaving the ground. Jump cancels it into a slide-jump that keeps the speed (speed above the run target bleeds at only 10 studs/s² in the air); Shift again stands up. Server-validated as a grounded action with a 0.4 s cooldown.
- **Pose.** An original clip, checked on the R6 renderer: drop in over 0.1 s; leaned back 43°; the right leg straight out along the ground; the left leg tucked forward and out; the left hand trailing by the hip; the right arm forward. Body contact sits it on the floor. The camera dips and the FOV kicks.
- **Sprint on double-tap W** (two presses within 0.3 s), lasting until W is released. Gamepad: L3, until the stick is released.
- **Q unbound.** Rolls are off the controls (the code stays for tests); air flips are the double jump.

## What changed in v5.7 (wall-run tap versus hold)

With v5.2's kick on press, climbing only worked if Space was still held from the jump onto the wall; pressing it later kicked you off. Tap and hold are now told apart on release:

- A press starts climbing at once; letting go within 0.3 s (TapTime) was a tap, and kicks off at the release. v4's 0.2 s window was shorter than many ordinary taps, which is why it needed double taps.
- The 3 s of full-speed climbing counts time actually held, so holding later in the run still climbs.

## What changed in v5.6 (spammed double jumps)

It still sometimes failed, mostly when double jumps are chained. The server restores the flip only after seeing a landing. It checked every 0.1 s and needed vertical speed under 8, so a land-and-jump lasting a frame or two was missed and the next flip was rejected after the client had already relaunched.

- **Server.** It now checks for a touchdown every frame (at the ground and not rising). As a backstop, a flip 0.8 s after the last accepted one is accepted even if no landing was seen (Validation.FlipInterval; a double-jump cycle is about 0.9 s).
- **Client.** The Humanoid's Landed state also restores the flip, catching a landing that jumps again on the same frame.
- If it still happens, the HUD's 'Last rejected' line names the cause.

## What changed in v5.5 (fast double taps)

The owner found a fast double tap gave a small jump without the flip. Three client causes are fixed (not reproduced in Studio):

- **Debounce.** Jump presses within 0.12 s were dropped; that window now only ignores a JumpRequest echo of the same key press.
- **Too early.** A second press while the body is still leaving the ground, or in the first 0.1 s of the jump, is held for 0.35 s and fires the flip as soon as allowed (it used to be dropped).
- **Flip reset.** The client restored the flip whenever FloorMaterial reported ground, which lags a few frames after takeoff, so client and server could disagree and the server could reject the flip after the relaunch. It now resets only on a real landing, matching the server.

## What changed in v5.4 (double-jump flips)

The owner asked for flips as a double jump, with the direction from the keys held.

- **Second press in the air.** Space again (when no mantle or wall kick applies, and from 0.1 s after leaving the ground) relaunches upward at 44 studs/s, carries the current speed toward the input and flips. It is once per airtime; wall kicks restore it as before.
- **Eight directions, read on screen.** The body turns to the camera's facing, so W, W+D, D, S+D, S, S+A, A and W+A are front, front-right, right, back-right, back, back-left, left and front-left flips. One original tucked flip spins about the horizontal axis across each direction (OriginalClips.flipToward, spin about an axis added to the clip builder); the back half uses the backflip's arms and head. Key poses were checked on the R6 renderer.
- **One set.** The mocap flips (Front Flip, Front Twist Flip, Backflip, Run To Flip, Stylish Flip) are no longer mapped, so all directions match. Q in the air plays the same directional flips without the extra lift.

## What changed in v5.3 (wall-jump direction)

The owner found wall jumps uncontrollable. Off a wall run, the kick mostly carried you forward. Running at a wall took two presses, then always bounced you straight back, facing where you came from. The cause was the v4.4 three-way kick (up, side or out). Holding W along a wall run gave the side kick: run speed plus only 8 studs/s out. Holding W into a wall gave the up-kick, so the second press fell back to a straight bounce out.

- **Direction follows input.** A kick goes where you hold, camera relative, or where the camera faces with no input. It is turned off the wall to at least 30°, keeps any speed already going that way (at least 30 studs/s, 28 off a wall run), and faces the launch.
- **Up-kick narrowed.** Only input within about 32° of straight into the wall leaps up it (was 60°), still once per wall per airtime.

## What changed in v5.2 (wall-run controls)

The owner found kicking off a wall run needed a double tap, and holding Space only climbed for about a second.

- **Kick on press.** The kick used to fire on release, and only if Space was held under 0.2 s, so ordinary presses counted as climbing. A press now kicks off at once (or mantles if the top is in reach). Climbing is Space kept held from the jump onto the wall.
- **Longer climb.** Holding keeps the full 11 studs/s for 3 s (about 33 studs), then eases into the slow held slide over 1 s. It used to taper from the start over 2 s and stop rising after about 1.5 s.

## What changed in v5.1 (owner feedback on v5.0)

Standing idle looked broken: the legs tilted forward under an upright torso, as if floating. The mocap idle stands on slightly bent knees, and the block leg had followed the thigh. Each limb is now aimed from hip to ankle (shoulder to wrist), so the feet stay where the clip puts them. Renders show straight idle legs, and landing and jump legs under the body. The run has no knees, so it is unchanged.

## What changed in v5.0 (R6 rig)

The owner said v4.9 still did not look like the reference: the limbs there look "disconnected", "free" where they join the body, with the torso leaned more. The cause is the rig. The reference uses classic R6 ([ADR 0008](decisions/0008-r6-rig.md)).

- **R6 character.** One-block limbs pivoting at the R6 joints; the arms' tops swing out past the shoulder. All clips are converted from R15 terms when applied.
- **Run matched frame by frame.** A solid-block R6 renderer compared our cycle with 60 fps reference frames, side-on at 2:53.8-2:54.4 and from behind at 2:44.6-2:45.1:
  - lean 36° (10° whole body, 26° chest), with the head following the torso;
  - the planted leg 28° forward, sweeping back steadily into a straight 88° back kick;
  - the kicked leg holds, then drops quickly to plant;
  - the forward arm reaches 88° early and holds; the back arm falls late to 46° behind;
  - limbs swing out as they go back: arms up to 60°, legs up to 22°;
  - 0.47 s per two steps, keyed at 60 fps.

  Run and Sprint are the same cycle.
- **R15 extras dropped.** The R15 leg splay and arm stretch do not apply: R6 legs and arms are the reference's own proportions.

## What changed in v4.9 (owner feedback on v4.8)

The owner: arm and leg movement "almost perfect". They asked for more forward lean in the upper half only, legs a bit wider, and longer arms.

- **Upper-body lean.** Most of the lean is now at the waist. Whole body 6°/8°, chest bend 16°/18°, so the chest leans 22°/26° in total (v4.8: 16°/20° from the hips). The arm angles grew by the extra lean, so the swing looks the same against the ground.
- **Wider legs.** Each leg angles 6° out to the side, read as stance width; the stride is unchanged.
- **Longer arms.** Upper and lower arms are 1.25x longer (`Config.Avatar.ArmScale`), stretched on the server with their attachments and joint offsets.

## What changed in v4.8 (owner feedback on v4.7)

The owner said v4.7 looked like a basic Roblox run, not the reference. A closer frame study of the Runner, side-on at 2:53.7-2:54.5, found the differences ([results](movement-verification.md#v48-pose-to-pose-run-2026-10-29)). The owner also flagged a slow-motion stop with a gap before idle, and a slippery turn clip that kept playing after a reversal.

- **Pose-to-pose run.** Each step holds a kick pose for 40% of the step:
  - the trailing leg straight back near horizontal (Run 84°, Sprint 90°);
  - the planted leg 24-26° forward;
  - the opposite arm reaching forward (100-105° from the leaning torso), the other arm 32-35° back.

  Then it snaps through the passing pose into the mirror. Both arms do the same mirrored swing. Lean is 16°/20°. Run and Sprint share a 0.53 s cycle, so their blend lines up.
- **No transition clips.** The mocap start, stop and turn clips are gone. Stopping blends straight into idle (faster idle blend), and the run's cadence no longer drops below 0.85x while braking. A reversal is just the body turning.
- **Less skid lean.** Turn bank capped at 6° (was 16°), acceleration pitch at 5° (was 10°).

## What changed in v4.7 (owner feedback on v4.6)

The owner's verdict: no elbows, knees or hands, only block limbs. The run was still shaky, sliding, not sharp, and too upright ("looks disabled"). See [ADR 0007](decisions/0007-block-limbs-and-original-run.md).

- **Block limbs.** Elbows, wrists, knees and ankles are held straight for every animation.
- **Steady torso.** Feet only push the body up out of the floor and no longer pull it down, so straight legs lift clear in the stride instead of dropping the body twice per step.
- **New original run.** Run, Sprint and the back-pedal are generated for block limbs, replacing the mocap jog/run/sprint/diagonals/strafe in every build:
  - sharp swings that reverse quickly at the ends;
  - a forward lean (Run 10°, Sprint 14°);
  - legs ±52°/±62°;
  - arms ±70°/±80°, opposite the legs and flaring out up to 40° on the back swing;
  - a 0.43 s cycle at rate 1.

  Natural speed equals the passing foot's speed (Run 9.0, Sprint 10.7 hip units/s).

## What changed in v4.6 (owner feedback on v4.5)

The owner found v4.5 "horrible": hands showed, and the arms were tucked in like a walking stance. Their reference is the Roblox chase game Huss Valley's Runner run (no knife), studied from frames of a YouTube guide (Chrisu, "HUSS VALLEY PRO GUIDE!", around 2:44 and 3:36; private copy only). Observed there: straight arms in big strokes that flare outward to near horizontal on the back swing and come in close in front; straight legs with a big back kick; slight forward lean; fast cadence.

- **No hands.** The R15 hand parts are hidden on spawn (the owner wants no hands anywhere in the game). Ground contact and the wall-run reach ignore hidden parts.
- **Arms driven by the legs.** Each arm swings opposite its own leg (gain 1.6, soft cap 95°), so every run clip gets the same even, big stroke. Several Mixamo sprints barely move one arm.
- **Arms out from the body.** 12° out at all times, up to 40° more at the full back swing.
- **Aiming off.** The RMB aim pose and click marker are switched off (`Config.Lab.Aim = false`); the HUD no longer lists them.

## What changed in v4.5 (running style)

The owner asked for a "Robloxy" run instead of an athletics sprint: straight arms and legs, long strides and long arm strokes, keeping the energy. The jog, run, sprint and four diagonal loops (private lab only) are restyled by new converter options, not new clips:

- **Straight limbs.** Elbow bend 8% of the source (was 55%), knee bend 15% (was untouched). The hips rise frame by frame by the change in leg reach, so the planted foot stays on the floor.
- **Pendulum swing.** Shoulders (and hips on the forward loops) keep only their forward/back swing, timed from the source. The arms no longer pump across the chest. The diagonals keep their leg motion so the feet still track the travel direction.
- **Upright.** The chest keeps 35% of the source's average forward lean; the legs counter-rotate so foot placement is unchanged.
- **Long strokes.** Arm and leg swing 1.4x about the mean pose (was 1.3 legs, 1.25 arms); the clip speed scales with it, so cadence drops and strides lengthen. A soft cap (arms 70°, legs 65° from hanging) stops the hardest-pumping clip swinging the straight arms overhead.

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

- **Light server authority (v7.9).** Each player's client owns its character's physics. The server checks requests (variants, rates, ground state, geometry, cooldowns, rate limit), caps horizontal and upward speed, and snaps characters back from unexplained air boosts and wall passes. A client that ignores the server's teleport is not stopped, so this is not competitive anti-cheat. The strong option (server-run movement) stays open for later.
- Roblox speeds outrun natural cadence: it is capped at 1.3x, so feet slip at sprint.
- The wall-run pose is procedural (the run cycle, a body roll and a reaching arm), with the hand placed by an angle solve rather than IK. Wall running on sloped walls is not implemented.
- The original clips are hand-keyed by an AI author and checked on the R6 renderer, not made by an animator.
- No foot IK for slopes and steps: ground contact corrects height only.
- Flips started late in a jump play faster, up to 2.6x.
- Mantle hands are tuned for typical heights with no arm IK, so they can hover slightly above very low or very high edges. Mantles need anchored, collidable parts; moving platforms are unsupported.
- A jump plus quick kicks can lift the feet over 20 studs: lab values to tune, not design decisions.
- Aiming is switched off (`Config.Lab.Aim`, owner 2026-10-29) until aiming is in scope; its code stays.
- Studio checks since v5.9 are partial: v7.7's fidget was checked in Studio, but most later changes passed only the automated checks. See [results](movement-verification.md).

## Playtest priorities

1. v7.32 (also with Space held): jump at a tall wall holding W, then let go: straight into the wall slide (back to the wall, hand on it behind, other arm out), going directly down. Run along a wall and let go: the same, at once. Jump off at any point.
1. v7.28: on a wall run, let go of W (slow to a cling; hold Space to run straight up), hold back along the wall (turn round), hold forward again.
1. v7.24: double-jump forward (W): the front full step-out, a fraction faster, the face never turning back to the camera.
1. v7.18: run, then double-tap W to sprint: is the difference clear, and is the shake subtle enough?
1. v7.17: hold Space up the 16-stud wall: you should run along its top edge, not mantle. Press Space again to mantle up; press while holding away to jump off.
1. v7.16: jump, double-jump flip onto a corridor wall: the run should catch at once. Flip next to a wall and press Space: kick at once. Flip into a ledge: mantle.
1. v7.15: sprint at the short walls west of spawn and vault each: the run should carry straight through at the same speed, landing further past the wall. Try jumping early and late.
1. v7.13: jump onto the corridor walls from different distances; the run should catch right where you meet the wall. Press Space early toward a wall in the air: it should kick, not flip. On a wall run, hold away from the wall and press: instant kick.
1. v7.12: land from a wall jump while holding W; strafe A then D and back quickly (with Ctrl shift lock too). Both should flow without cuts.
1. v7.11: wall run along the corridor walls and kick off; kick between the chimney walls. Is the run fast enough, and do kicks carry far without feeling floaty?
1. v7.10: stand right on the edge of each ledge and the chimney top and press Space; walk off an edge and press Space just after. Each should be a normal jump, not the flip.
1. v7.8 regression: run, sprint, slide and slide-jump; double-jump flips in all eight directions; wall run, wall jump and up-kick; and a mantle on each traversal ledge plus the kong vault on the short walls. Note any "Last rejected" reason on the HUD.
2. New ledge detection: jump into `FloatingLedge` (thin slab, east of spawn) and at `NarrowPillar` slightly off-centre. Both should mantle.
3. Stand still for 10 s: the neck stretch should ease in and out over the idle.
4. Play normally for a few minutes (double jumps, wall kicks, wall runs, mantles, vaults, slides, landing and jumping again quickly): the HUD's `Corrections` should stay at 0. Any snap-back in normal play is a false positive to report. Then two clients: watch each other's flips, slides, mantles and wall runs.
5. Decide on the landing clip: keep the mocap, or try an original R6 candidate.
6. Later, before competitive play: whether to move from the light option to server-run movement.

[Research](research/movement.md) · [Assets and Mixamo pipeline](movement-assets.md) · [Results](movement-verification.md) · [ADR 0003](decisions/0003-clip-presentation.md) · [ADR 0004](decisions/0004-place1-traversal.md) · [ADR 0005](decisions/0005-mixamo-variants-transitions.md) · [ADR 0006](decisions/0006-wall-run-and-v4-feedback.md) · [ADR 0007](decisions/0007-block-limbs-and-original-run.md) · [ADR 0008](decisions/0008-r6-rig.md) · [ADR 0009](decisions/0009-cleanup-type-check-and-trusted-physics.md)

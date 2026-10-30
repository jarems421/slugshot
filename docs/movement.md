# Movement lab

Experimental branch: `experiment/movement-sandbox`. The foundation project remains unchanged. This is a playable prototype for review, not an approved final movement set or camera design. Do not merge into `main` until the owner has reviewed the gameplay.

## Play and compare

```powershell
python tools/verify_movement.py                       # checks (format, lint, full type check); builds the public lab
python tools/build_movement_playtest.py --retarget    # private lab with the owner's Mixamo clips, plus the v1 and v2 labs
python tools/r6pose/preview.py mantleHigh --ledge 4.5 # render an original clip's keys on the R6 rig (see below)
```

Open a place in Studio and press Play. Studio does not reload a rebuilt `.rbxlx`: close and reopen it after rebuilding.

- `SlugshotMovementLabPrivate.rbxlx`: **v7.8**, adding the owner's Mixamo clips (the HUD shows `original + N private clips`): the running jump, landings, crouch set, hit reactions, injured idle, wall jumps and the neck-stretch fidget. Built only from privately retargeted clips (see [assets](movement-assets.md)); never commit or publish it.
- `SlugshotMovementLab.rbxlx`: the same code with original clips only (HUD: `original clips`). Every move works: run, idle, flips, slide, mantles, kong vault, wall run and wall jumps are original clips. Without the private clips it uses an original jump and landing, plays the wall-hop clip for wall jumps, has no fidget, and crouching only slows you down.
- `SlugshotMovementLab-v2.rbxlx`: v2 (clips, rolls, flips), rebuilt from commit `0b06985`.
- `SlugshotMovementLab-v1.rbxlx`: the first lab, rebuilt from commit `e2b5688`.

For live editing, serve `movement.project.json` with the Rojo plugin on port **34873**.

| Control | Experimental action (v7.8) |
| --- | --- |
| WASD / native movement controls | Run (eight directions: run ahead, strafes either side and the back-run behind, blended between) |
| Double-tap W / gamepad L3 | Sprint until W is released (gamepad: until the stick is released); also stands up from a crouch |
| Shift / gamepad B | **Slide** while running (12+ studs/s): current speed +15 (max 46), slowing to 20 over 0.8 s, steering a little. Pressed in the air, mid-action or inside the 0.25 s cooldown, it waits 0.4 s (or while Shift is held, until you land) and slides on touchdown. Jump during it leaps out keeping the speed (slide-jump); Shift again stands up. Camera dips 1.4 studs and the FOV kicks to 82 |
| Ctrl | **Shift lock** toggle: mouse locked to the centre, body faces the camera (strafing on A/D), camera 1.75 studs over the right shoulder. Actions keep their own facing, then the body turns back to the camera |
| C / gamepad R3 | Crouch toggle (crouch walk in four directions) |
| Space / native jump | Jump (Athletic: 8.7 studs, a springy arc). **Into a ledge** 0.7-5.7 studs above your feet: mantle onto it (holding Space mid-jump reaches higher ledges). **Into a thin wall up to 3.6 studs, at speed**: vault over it. **Jump onto a wall while running along it** (not head-on): wall run along it automatically, locked on until your feet reach the ground or the wall ends. Hold Space at any point to run up the wall (3 s of full-speed climbing per run, then easing into a slow slide) and over its top when you reach it; release to slide down; tap Space (released within 0.3 s) to kick off. Ledges are mantled only when the jump would not clear them, and never when under 2.2 studs above the ground. **In the air beside a wall**: wall jump; presses up to 0.35 s early count. One press kicks off where you hold (camera relative; where the camera faces if you hold nothing), always at least 30° out from the wall and facing the way you go. This also applies to the tap off a wall run. Holding almost straight into the wall leaps up it instead (once per wall per airtime). Up to 8 kicks per airtime, enough to climb between two walls; each restores the flip. **Anywhere else in the air** (a second press): double jump with a flip toward the keys held, as seen on screen: W flip kick, A/D butterfly twist, S back full (arms overhead), all four diagonals a tilted corkscrew; once per airtime |
| H | Lab only: take 15 damage to preview hit reactions and the injured idle (no combat rules) |
| P / R | Cycle Baseline, Athletic, Precise profiles / respawn |

There is no ground roll (removed in v7.8) and Q is unbound. Touch/gamepad bindings exist but have not been device-tested.

**Pose tools.** `tools/r6pose/preview.py` renders any literal key table in `OriginalClips.luau` (idle, air, mantles, kong vault) on the R6 block rig with the game's curves. Mantles can be placed on the client's path against a ledge, printing hand and foot positions relative to the top and face; `--help` lists options. It needs numpy and matplotlib, and writes to `build/r6pose/` (ignored). The Luau tables are the only copy of the poses.

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

- **Client-trusted physics.** Each player's client owns its character's physics. The server checks requests (variants, rates, ground state, geometry, cooldowns, rate limit), caps horizontal speed and counts unexplained air boosts. A rejected request only cancels the animation; the client has already applied the velocity. This is not competitive anti-cheat. How much movement the server should own is an open decision before PvP.
- Roblox speeds outrun natural cadence: it is capped at 1.3x, so feet slip at sprint.
- The wall-run pose is procedural (the run cycle, a body roll and a reaching arm), with the hand placed by an angle solve rather than IK. Wall running on sloped walls is not implemented.
- Crouch changes speed and pose only. The collision height is unchanged, so it does not let you fit under anything.
- The original clips are hand-keyed by an AI author and checked on the R6 renderer, not made by an animator.
- No foot IK for slopes and steps: ground contact corrects height only.
- Flips started late in a jump play faster, up to 2.6x.
- Mantle hands are tuned for typical heights with no arm IK, so they can hover slightly above very low or very high edges. Mantles need anchored, collidable parts; moving platforms are unsupported.
- A jump plus quick kicks can lift the feet over 20 studs: lab values to tune, not design decisions.
- Aiming is switched off (`Config.Lab.Aim`, owner 2026-10-29) until aiming is in scope; its code stays.
- Studio checks since v5.9 are partial: v7.7's fidget was checked in Studio, but most later changes passed only the automated checks. See [results](movement-verification.md).

## Playtest priorities

1. v7.8 regression: run, sprint, slide and slide-jump; double-jump flips in all eight directions; wall run, wall jump and up-kick; and a mantle on each traversal ledge plus the kong vault on the short walls. Note any "Last rejected" reason on the HUD.
2. New ledge detection: jump into `FloatingLedge` (thin slab, east of spawn) and at `NarrowPillar` slightly off-centre. Both should mantle.
3. Stand still for 10 s: the neck stretch should ease in and out over the idle.
4. Two clients: watch each other's flips, slides, mantles and wall runs. Check `SuspectAirBoosts` stays at 0 in normal play; it should only count boosts with no accepted action.
5. Decide on the landing and crouch clips: keep the mocap, or try original R6 candidates.
6. Decide how much of movement the server should control before PvP.

[Research](research/movement.md) · [Assets and Mixamo pipeline](movement-assets.md) · [Results](movement-verification.md) · [ADR 0003](decisions/0003-clip-presentation.md) · [ADR 0004](decisions/0004-place1-traversal.md) · [ADR 0005](decisions/0005-mixamo-variants-transitions.md) · [ADR 0006](decisions/0006-wall-run-and-v4-feedback.md) · [ADR 0007](decisions/0007-block-limbs-and-original-run.md) · [ADR 0008](decisions/0008-r6-rig.md) · [ADR 0009](decisions/0009-cleanup-type-check-and-trusted-physics.md)

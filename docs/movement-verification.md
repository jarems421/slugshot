# Movement prototype verification

Date: 2026-10-28. Studio 0.745.0.7451137, Rojo 7.7.1. Experimental branch only; no Roblox experience or animation published. This records technical progress, not a claim that movement feels excellent.

## v7.8 cleanup pass (2026-10-30)

Automated and offline evidence only. The Studio MCP was not connected in this session, so nothing below ran in Roblox.

- **`python tools/verify_movement.py`: PASS.** Foundation checks; stylua; selene (0 errors, 0 warnings); luau-lsp strict analysis of every movement script with the pinned Roblox definitions (0 errors); public and test builds; private-asset and test isolation.
- **Type check before fixes: 26 distinct errors.**
  - Possibly-nil `Humanoid` and `Vector3` upvalues.
  - Untyped mixed tables (blend anchors and clip specs).
  - Untyped `GetAttribute` counters.
  - A dynamic `Enum.HumanoidRigType` lookup.
  - The runtime-only `PlayerModule` require.
  - None needed a behaviour change.
- **Private clips regenerated** with `python tools/build_movement_playtest.py --retarget` (exit 0): 21 clips, against 31 before. Blender printed its usual unsupported "Short" FBX property warnings.
- **Pose preview tool** (`tools/r6pose/preview.py`) reproduces the v7.4 prototype contacts from the Luau tables:
  - Kong vault over a 3-stud wall: hands 0.07 below the top and 0.46 past the face at 0.10 s; feet 0.03 above the top at 0.14 s.
  - Climb-up onto 4.5 studs: hands 1.5-2.2 above the top from 0.30 s as the body passes over.
- **Back-diagonal blend:** checked because the review suspected a strafe/back-run blend might cancel the leg swing. It does not. The left-hip swing is 89.5° peak to peak at 135°, against 108.1° for the strafe alone and 78.5° for the back-run alone; extremes stay aligned.
- **Private clip audit on R6** (renders kept in the session scratchpad, not committed). Fourteen clips were checked: jumps, landings, hit reactions, crouch set, injured idle, wall jumps. None is broken. The landing (deep forward slump, arms out) and the crouch set (hunched, arms out) read most like mocap on R6.
- **Not verified:**
  - The roll removal, the move-layer cleanup and the new ledge detection (`FloatingLedge`, `NarrowPillar`) have not been checked in Studio.
  - Neither have the air-boost counter's false-positive rate, two-client replication after the cleanup, or the per-frame savings.

## v5.0 R6 rig and frame-matched run (2026-10-29)

The owner: the limbs in the reference look "disconnected", "free" where they join the body; the torso leans more; "analyse the video better". See [ADR 0008](decisions/0008-r6-rig.md).

| Check | Observed result |
| --- | --- |
| Rig | The 5:40 avatar line-up and plain avatars (notDao and Zeno at 2:57, PeepoThe_Frog at 4:16) show classic R6: single-block arms and legs and one torso. Facing is confirmed from accessories in a front view at 3:09 (cat on the left shoulder, bag at the front) |
| Method | Studio was not reachable from this session (no Studio MCP), so poses were compared offline. A Python solid-block R6 renderer uses the standard R6 joint pivots and the same R15-to-R6 conversion as `Presentation.toR6`, beside every-frame (60 fps) reference crops at matched phases and camera angles |
| Reference cycle | 0.46-0.47 s per two steps; kick hold about 0.07 s; pass about 0.05 s later. The kicked leg climbs 30-45-70-90° over about 0.1 s; the arm reaches horizontal about 0.05 s before the leg peaks and drops late. Seen from behind, the back-swinging arm sticks out to the side and the kicked leg angles outward. Torso lean is about 35-40° (plain avatars) |
| Iterations | v4.9 on R6: lean too small, head too upright → 36° with the head following. Shared snap timing: the drop out of the kick was too late and the arm reach too early → per-limb leave/pass/arrive timing. Behind view: arms and legs too tight → outward flare on the back swing (arms 55°, legs 22°) |
| Other moves on R6 | Rendered through the same conversion: idle, rolls and flips acceptable. Mocap running and standing jumps and the landing clash with the run: knee squats become waist folds and tucks become stiff pikes |
| Checks | `python tools/verify_movement.py` passes; private lab HUD `MOVEMENT LAB v5.0` |

Not established in Studio: the R6 spawn and physics (stand height, ground checks, traversal heights), the 90° joint-frame conversion on the live rig, peers, and how it all looks in motion. Reference footage, frames and renders stay outside the repository.

## v4.8 pose-to-pose run (2026-10-29)

The owner: v4.7 "looks like a basic Roblox run", not the reference. They also flagged a slow-motion stop with a gap before idle, and a turn clip that kept sliding after a reversal. Arms should be symmetric (the no-knife run).

| Check | Observed result |
| --- | --- |
| Reference, closer study | Side-on frames at 2:53.7-2:54.5. Facing was confirmed from the front view at 3:09: dark cat on the left shoulder, bag on the front. Each step holds about 0.1 s in a kick pose (trailing leg straight back near horizontal, planted leg angled forward, opposite arm reaching forward to about horizontal, back arm short), then snaps through the pass. About 0.5 s per two steps, with a forward lean. The v4.6 "outward flare" was a misread of the forward reach seen from behind. That shot has a knife in the right hand, so the arms follow the free left arm, mirrored |
| v4.7 versus the reference | v4.7 was an even, constant-speed swing about vertical, the same structure as the default R6 run: no holds, no high back kick, no forward reach. Its cadence of about 0.34-0.39 s at Athletic speeds was faster than the reference |
| Prototype render (v4.8 maths) | Kick holds over frames 0-3 and 7-11 of 16, snaps at 4-5 and 12-15; right leg back at horizontal while the right arm reaches forward, then mirrored; arms close to the sides in the front view |
| Build | Manifest down to 31 clips (no Start/Stop/StopAim/StopBack/Turn in the generated module). Private lab HUD `MOVEMENT LAB v4.8`; `python tools/verify_movement.py` passes |

Not established in Studio: how the run, stop and reversal look and feel; the actual hip unit (and so the playback rate); the planted foot's contact in the kick hold.

## v4.7 block limbs (2026-10-29)

The owner tested v4.6. Verdict: no elbows, knees or hands. The run was shaky, slid, was not sharp, and was too upright. See [ADR 0007](decisions/0007-block-limbs-and-original-run.md).

| Check | Observed result |
| --- | --- |
| Cause of the shake | Ground contact held the lowest foot on the floor. With straight legs at ±60°, both feet rise about 0.5 hip units, so the body was pulled down twice per stride. The forward tier also blended three mocap loops with unaligned cycles |
| Prototype render | A Python copy of the block-run maths, rendered as a stick figure: straight block limbs; even ±62° legs and ±80° arms on Sprint; arms out to near horizontal on the back swing (front view); 14° lean; body level, feet up to 0.53 hip units clear at the split |
| Speeds | Natural speed = passing-foot speed: Run 8.98, Sprint 10.70 hip units/s at a 0.433 s cycle. At 2.2 studs per unit, the Athletic profile plays Run at about 1.1x and Sprint at about 1.27x (cap 1.3) |
| Build | Private manifest down to 36 clips, with no Jog/Run/Sprint/diagonal/strafe entries in the generated module. Private lab rebuilt with HUD `MOVEMENT LAB v4.7`; `python tools/verify_movement.py` passes |

Not established in Studio: the run, crouch, landings and mantles with rigid legs, the real hip-unit size, foot slip at actual speeds, peers, and feel.

## v4.6 reference run (2026-10-29)

The owner tested v4.5 in Studio: "looks horrible". Hands showed and the tucked, planar arms read as a walking stance. The reference is the Huss Valley Runner run (no knife); see [what changed](movement.md#what-changed-in-v46-owner-feedback-on-v45).

| Check | Observed result |
| --- | --- |
| Reference frames | yt-dlp download of the owner's link (489 s, 720p60) into ignored `private-assets/reference/`; Blender extracted frames. 2:44.6-2:45.3 (Runner, "PRESS SPACE TO DASH") gave one full cycle from behind; 3:36.9 a side view (that clip is a Catcher holding a knife, so it was used for the arm shape only) |
| Arm flare only (stroke x1.4) | Run matched the reference's outward back swing. Sprint barely changed even at x1.9: measured left shoulder -10..+38°, because its source arm hardly swings. Rejected in favour of driving the arms from the legs |
| Arms from legs (v4.6) | Shoulder swing (+ forward): Run -82..+81°, Sprint -75..+82°, SprintForwardLeft -79..+68°, SprintBackLeft -51..+76°, Jog -64..+66°; means within 3° of hanging. Renders show near-horizontal straight strokes flaring out at the back. Lowest ankle 0.00-0.05 hip units in contact frames |
| Checks | `python tools/verify_movement.py` passes; private lab rebuilt with HUD `MOVEMENT LAB v4.6` |

Not established in Studio: hidden hands on the live rig and on a second client, rolls touching the ground without hands, the wall-run reach, and how the run looks and feels. Aim was disabled by config, not removed.

## v4.5 running style (2026-10-29)

The owner asked for a straight-armed, straight-legged run with long strides that reads as Roblox rather than athletics. Converter-only change; see [what changed](movement.md#what-changed-in-v45-running-style).

| Check | Observed result |
| --- | --- |
| Offline render (v4.4 style + straight elbows/knees only) | Stick-figure render of the generated Sprint (approximate R15 proportions; the renderer was first checked on Idle, which stands upright with arms down). Straightening alone left a 35° forward lean and the straight forward arm swung out sideways at shoulder height, because the source pumps across the chest. Rejected |
| Offline render (planar, no cap) | Run (from Sprint.fbx) swung the straight arms above shoulder height and the forward leg near horizontal. Added a soft cap (`limit`: arms 70°, legs 65°, tanh-shaped) |
| Offline render (v4.5) | Jog, Run and Sprint: arms hang beside the body and swing forward/back only (front view); the chest leans visibly less; knees near straight; the lowest ankle is 0.00-0.05 hip units above the floor in contact frames (flight frames higher). Jog reads as a pendulum run. Run's back swing still reaches about 70° behind. SprintForwardLeft (before the cap): arm swing follows the turned chest; legs unchanged |
| Clip speeds | Jog 3.58, Run 8.54, Sprint 10.10 hip units/s (scaled by the 1.4 leg swing, so cadence drops at a given speed) |
| Checks | `python tools/verify_movement.py` passes; `build_movement_playtest.py --retarget` rebuilt the private lab |

Not established: how it looks on the real rig in Studio, foot slip at actual speeds, transitions into and out of the restyled loops, and feel in hand. The renders show private clip data, so they stay in local temporary storage outside the repository.

## v4.4 owner feedback pass (2026-10-29)

Changes from the owner's v4.3 playtest ([ADR 0006 addendum](decisions/0006-wall-run-and-v4-feedback.md#addendum-v44-same-day)), tested with real key presses in the private lab. [Sanitized evidence](evidence/2026-10-29-movement-v4.4.json).

| Check | Observed result |
| --- | --- |
| Wall run, up and over | Along the 16-stud wall, holding Space: attached at y 9.7, climbed, then mantled onto the top (MantleHang, 0.33 s, root at the top's stand height) |
| Up-kick | Holding into the wall, a second Space press leapt straight up (`WallKickUp`, 55 studs/s up, the jump clip rendered) and carried over the 16-stud top. On the 40-stud wall, a second kick on the same wall became an outward kick (WallJumpRight.2) |
| Side kick | Wall run, tap while holding along the wall: launched 8 studs/s out and 28 along with the WallJump clip, then re-attached to the same wall further along |
| Mantle speed | The 5.5-stud ledge: MantleVault in 0.30 s (v4.3: about 0.46 s); the 4.5-stud ledge was jumped onto. 0 rejections throughout |
| Checks | `python tools/verify_movement.py` passes |

Not established: two-client rendering of the up-kick (it uses the same attribute path as other kicks; not re-run, to avoid opening test windows while the owner may be playing), and feel in hand.

## v4.3 owner feedback pass (2026-10-29)

Changes from the owner's v4.2 playtest ([ADR 0006 addendum](decisions/0006-wall-run-and-v4-feedback.md#addendum-v43-same-day)), tested with real key presses. [Sanitized evidence](evidence/2026-10-29-movement-v4.3.json).

| Check | Observed result |
| --- | --- |
| Wall run lock | Holding Space 0.6 s then releasing: the run lasted 1.9 s and ended only when the feet reached the floor. A quick jump: 1.1 s, also ending on the floor. Before the change, the run ended at 2 s or when the input moved |
| Wall jump climbing | Reproduced first: in the 12-stud corridor the 4th and later presses were ignored (3-kick limit), and early presses were missed. After the change, presses every 350 ms gave 8 consecutive kicks; presses every 250 ms climbed onto the top of the 40-stud walls in 4 kicks |
| Mantle style | Space about 3 studs before the face: 3 and 4.5 studs were jumped onto; 5.5 studs used `MantleVault`; 7.5 studs (reaching) used `MantleHigh`; all ended on top with 0 rejections |
| Parkour clip | Held-pose sheets of the Mixamo segment (hunched, unreadable) and of the new original clip (front and three-quarter views): planted arm, raised free arm, body tipped about 55°, legs swung out sideways |
| Two clients | The peer saw all 5 wall runs (3 hold-and-tap with kick clips, 2 ride-outs to the floor). 0 motion corrections. 5 rejections (2 flip-state, 2 geometry-WallRun, 1 geometry-WallHop) came with crouch and flip input that the script never sent, so they were probably from someone playing in the test window; their cause was not established |
| Public build, tests | Studio math and clip tests pass. The 5.5-stud ledge mantled (MantleHigh with that press timing), with 0 rejections |
| Checks | `python tools/verify_movement.py` passes |

Not established: the cause of the geometry rejections above (the HUD now shows the last rejection), and feel in hand. That test session's windows stayed open after `EndTest`, could no longer be reached by the test tools, and were left for the owner to close.

## v4.2 owner feedback pass (2026-10-29)

Changes from the owner's v4.1 playtest ([ADR 0006 addendum](decisions/0006-wall-run-and-v4-feedback.md#addendum-v42-same-day)), tested with real key presses in the private lab. [Sanitized evidence](evidence/2026-10-29-movement-v4.2.json).

| Check | Observed result |
| --- | --- |
| Crouch height | The Root joint's vertical offset is -0.34 at crouch idle against -0.35 to -0.44 while crouch walking, so the two are at the same height |
| Wall run, one client | Holding Space for 0.9 s climbed from y 10.8 to 15.3. Releasing slid down, gently at first (about 10 studs over 0.7 s). A 90 ms tap kicked off, and the kick attached to the opposite wall |
| Wall hand | Front view mid-run: the hand stops about 0.15 studs from the wall surface, with the root 2.0 studs out (it had gone into the wall) |
| Mantle rule | Holding Space up the staircase: 0 mantle frames (it had mantled every step). Space about 3 studs before the face: the 3-stud box is jumped onto with no mantle, while the 4.5 and 5.5 stud ledges are mantled and end on top. Pressed against the face, a mantle runs (prediction logged: no time to clear) |
| Fall pose | A long fall shows the "fall" state with the jump's apex pose swaying, arms bent around the body; a held-pose comparison showed Falling Idle as the crouched, limbs-out pose |
| Two clients | 3/3 hold-and-tap runs (owner peak y≈19, kick clip on the peer) and 2/2 quick-release ride-outs (peak y 8-10) were seen by the peer. Server: 11 accepted, 0 rejected, 0 motion corrections; no script errors |
| Public build, tests | Wall run climbs (peak y≈19) and kicks off with the original clip, with 0 rejections. Studio math and clip tests pass. Network emulation was 0/0/0/0 |
| Checks | `python tools/verify_movement.py` passes |

Not established: how wall climbing and the mantle rule feel in hand, gamepad and touch (a wall-run tap needs a button release, which touch `JumpRequest` does not report), and the running restyle (next owner item).

## v4.1 owner feedback pass (2026-10-29)

Fixes for the owner's v4 playtest ([ADR 0006](decisions/0006-wall-run-and-v4-feedback.md)), checked in the private lab with real key presses (Studio's `user_keyboard_input`) where input mattered. [Sanitized evidence](evidence/2026-10-29-movement-v4.1.json).

| Check | Observed result |
| --- | --- |
| Jump input | Reproduced the owner's report before the fix: Space in the air beside the wall did nothing, and `JumpRequest` did not fire for any Space press (counted with a listener). After the fix, real Space presses trigger wall run, kick-off and mantles |
| Wall run, single client | Running parallel to the wall 3.5 studs out, one Space attaches without a second press and pulls in to the wall. A 35° approach also attaches. The run ends at the wall's end. Mid-run Space kicks off with a WallJump clip (about 8 studs away, up to y≈18). Kicking across the new corridor attaches to the opposite wall. An earlier build attached too low and sank to the floor in about 0.8 s; fixed by keeping 30% of the jump's rise and attaching only from 2 studs up |
| Wall jump and mantle poses | Held frames on the real rig: WallJump clips push off, throw the arms and tuck the legs, ending facing the jump. MantleVault plants one hand and loops the legs |
| Mantle timing | Real Space press: 3 studs MantleVault 0.41 s, 4.5 studs MantleVault 0.46 s, 5.5 studs MantleHang 0.51 s (v4: about 0.75-0.9 s); 0 rejections |
| Two clients | The second client sees the wall run in 6/6 runs (3 kick-offs, 3 ride-outs), each kick with a WallJump clip, and ride-outs end at the 1.6 s limit. Before an observer fix, the action often arrived while the replicated body was still on the ground and ended at once. Server: 12 accepted, 0 rejected, 0 motion corrections; no script errors |
| Public build | Wall run attaches and kicks off with the original WallHop clip. Studio tests pass: math, and clip decode/sampling/loop/root motion/climb/variants/blend |
| Edges and crouch | Standing with the root 0.3 studs past a box edge renders as grounded (further out, the Humanoid itself falls). The crouch idle keeps raised arms like the crouch walk |
| Checks | `python tools/verify_movement.py` passes |

Test-process notes:
- **Network emulation left on.** Studio network emulation was found at 60/60/10/10 ms in the private-lab and test windows, so earlier v4 playtests may have run with emulated lag. It is now reset to 0 in every window the test tools could reach; one window was left alone because it was in a Play session. The two-client script's 0-baseline assertion caught it.
- **Updating open windows.** Scripts in the already-open private lab were updated in place through `ScriptEditorService:UpdateSourceAsync`; a plain `Source` assignment is limited to 200,000 characters. Relaunching Studio hung while orphaned test windows were open.

Not established: how the wall run feels in hand, gamepad/touch input, the running restyle's look (next owner item), and sloped walls (deferred by the owner).

## v4 Mixamo clips (2026-10-29)

These are the owner's 49 Mixamo downloads, retargeted privately into 54 clips and played in the private lab ([ADR 0005](decisions/0005-mixamo-variants-transitions.md)). The [sanitized evidence](evidence/2026-10-29-movement-v4.json) lists outcomes and hashes only. Clip data, FBX files and pose captures stay in ignored storage.

| Check | Observed result |
| --- | --- |
| Files | All 49: 30 fps, with skin, full Mixamo skeleton, T-pose bind. Pose sheets were drawn from the source FBX and checked against the intended use of each clip |
| Converter, real data | First real run exposed five problems, all fixed: <ul><li>pelvis-yaw facing correction turned strafes and crouch walks sideways (removed; Mixamo already faces forward)</li><li>travelling loops kept half their travel as an offset (drift removed and recentred)</li><li>one-shot clips carried their own travel (removed)</li><li>run-out rolls recovered only at the end</li><li>the turn clip ended backwards (aligned to its end facing)</li></ul>After the fixes, directions were checked: strafes ±X, diagonals at 45°, sideways jumps ±X |
| Visual review | Held frames on the real R15 rig, side and front views: idle, jog, run, sprint, diagonals, strafe, crouch, turn, stop, landings, roll, flip, climbs, vault, wall run, aim jump, injured idle, flinch. Strafe clips twist the hips toward travel, as authored |
| Single client (private lab) | <ul><li>Start, stop and 180° turn fire (the turn only after a fix: a reversal passes through a stop, which had cleared the direction)</li><li>Crouch in and out at 9.9 studs/s</li><li>Aim settle, flinch (health 100→85) and idle fidget</li><li>Jumps: standing / running / aiming</li><li>Rolls: two forward variants, 11.7-12 studs</li><li>Flips: two front and two back variants, root up 1; drop flip from height</li><li>Landings: 12 studs → normal, 30 → hard, 60 → heavy; landing roll</li><li>Mantles at 3 / 4.5 / 5.5 (hanging climb) / 7.5 studs end exactly on top</li><li>Vaults over 2, 2.8 and 3.4 stud walls (after adding a look-ahead: early presses had jumped over)</li><li>Wall run up the long wall (+16.6 studs) and kick-off</li></ul>0 rejections, no console errors |
| Public build regression | Original clips only: rolls, flips and mantles accepted. Transitions, vault and wall run are absent, as expected. Studio tests pass, including the new variant tests |
| Two clients | Player 2 rendered Player 1's crouch, vault, wall run, roll variant and flinch. Under 60 ms each way + 10 ms jitter: vault, roll and crouch accepted, 0 rejections, 0 motion corrections; settings verified 0 before and restored to 0. One delayed attempt produced a plain wall hop instead of a wall run; 4 of 4 repeats ran the wall correctly (cause not established). Respawn: one HUD, crouch works. 4/4 forged requests rejected (vault onto empty air, roll rate 5, bad variant suffix, non-boolean crouch). No console errors |

Test-process notes:
- Client-side teleports in test scripts can trigger the server's motion correction, so the two-client checks teleport from the server.
- Leftover multiplayer test windows from earlier runs were ended through `StudioTestService:EndTest`.
- One Studio process launched for testing hung without a window and was left running (force-closing was not permitted).

Not established: rendered FPS extremes, devices, packet loss, foot IK on slopes, arm IK on ledges, and whether it looks and feels better (the owner's call).

## v3 traversal (2026-10-29)

Mantle and wall hop, with detection adapted from Place1 (MIT; [ADR 0004](decisions/0004-place1-traversal.md)). Original clips only. [Sanitized evidence](evidence/2026-10-29-movement-v3.json), [pose sheet](evidence/movement-v3-traversal.jpg) (two-hand climb on a 5.5-stud ledge, step vault on a 3-stud ledge, wall kick).

| Check | Observed result |
| --- | --- |
| Pipelines | `python tools/verify_movement.py` passes. Clip tests in Studio also cover climb curves (0 to 1, no drop in rise) and the wall-hop clip. Converter `traversal` mode verified in Blender on the synthetic FBX: climb 0 to 1, root translation removed, no contact mode. **Not run on real Mixamo files** |
| Mantle | 1.5 and 3 studs: `MantleLow`. 4.5 and 5.5 studs: `MantleHigh`. Each ended with the root exactly 3.19 studs above the ledge top. The 7.5-stud ledge mantled mid-jump through the held-jump window |
| Wall hop | Hop off the long wall and chimney: velocity (30 away, 54 up), turned to face away, `WallHop` rendered. Chimney: hop, hop, then mantle onto the 14-stud top. Hop then Q gave an accepted backflip with the physical root upright |
| Visual review | Held frames placed on the controller's path at 1.5/3/4.5/5.5 studs, side view. Fixed: a belly-flop press frame (now more upright with legs hanging), and a two-hand overhead reach on a chest-high ledge (threshold raised to 3.2 studs, so it is a step vault). Hands meet the edge at typical heights; no arm IK |
| Server checks | Bugs found and fixed: genuine wall hops were rejected because the server had not yet seen the jump (the hop request overtook replication; it now polls up to 0.35 s and checks recent positions), and requests now validate one at a time per player. 4/4 forged single-client requests and 3/3 two-client requests rejected (mantle onto empty air, hop on open ground, bad rate/variant/target) |
| Input timing | Roblox's floor flag lags takeoff by a few frames, which dropped second presses within about 0.15 s of a jump. Fixed with a grounded check that also needs low vertical speed, plus a 0.15 s hop buffer. Presses at 0.10/0.15/0.20/0.30 s all hop |
| Two clients | Player 2 rendered Player 1's `Mantle` (MantleHigh, root reaching the ledge top) and `WallHop`. Under 60 ms each way + 10 ms jitter: mantle, wall hop and flip with 0 rejections and 0 motion corrections. Settings were verified at 0 before and restored to 0 after |
| Respawn | New character: one HUD, mantle onto the 3-stud ledge, wall hop, no rejections. No console errors on server or either client |

Not established: rendered FPS extremes, devices/touch (jump presses use `JumpRequest`, which also covers touch and gamepad, but this was not device-tested), moving or unanchored platforms (unsupported by design), arm IK on the edge, and how it feels in hand.

## v2 refinement (2026-10-28)

Original keyframed clips, clip-driven presentation and the single Q/B acrobatics control. Public build only (no private clips loaded). [Sanitized evidence](evidence/2026-10-28-movement-v2.json), [clip contact sheet](evidence/movement-v2-clips.jpg).

| Check | Observed result |
| --- | --- |
| Pipelines | `python tools/verify_movement.py` passes (foundation unchanged; format/lint; public builds contain no private clips; test scripts only in the test place). Clip tests passed in Studio: decode, sampling, loop wrap, root motion, weighted blend, every original clip present and finite |
| Retargeter | `tools/mixamo_to_r15.py` verified in portable Blender 4.5.14 LTS on a synthetic Mixamo-named FBX with known poses: T-pose arm maps to character-left, a forward arm, a 90-degree body pitch, hip lift (0.208 units) and root motion (-0.521 units) all matched. **Not yet run on real Mixamo files** |
| Visual review | Held-pose contact sheets and live run/sprint/roll/flip captures inspected. Fixed: run too upright, roll landing on the head (now a diagonal shoulder roll; measured contact moves forearm then shoulder/upper back) |
| Ground contact | Held poses: lowest posed part within 0.0001 studs of the floor for idle, run contact, land and every roll frame tested; run flight 0.12 studs as authored |
| Single client | Roll 12.1-12.6 studs (target 12) with peak about 27 studs/s; input direction selected RollForward/RollRight/RollBack; front flip and backflip rendered with physical root up = 1 and camera roll 0; buffered landing roll started on touchdown; respawn: one HUD, 15 joints; 0 server rejections; no console errors |
| Aim during flip | Body rotation 3.1 rad while camera roll 0, aim direction dot 1.0, root up 1, marker placed mid-flip; mouse lock cleared |
| Two clients | Observer saw the remote run (hip swing up to 1.4-1.6 rad, replicated velocity 24), roll (RollForward, root up 1) and backflip (3.1 rad body rotation); the other client saw a RollBack. No console errors on server or clients |
| Network trial | One client at 60 ms each way + 10 ms jitter: roll 12.6 studs, landing roll accepted, 0 rejections, 0 motion corrections; settings restored to the 0 baseline and re-read |
| Invalid requests | Unknown variant, NaN direction, out-of-range flip rate and a grounded flip: 4/4 rejected, health 100 |
| Respawn (two clients) | Replacement rig rendered with clips on both clients; one HUD; aim mouse lock cleared; roll works after respawn |

Issues caught by these tests and fixed: the Humanoid braked against roll velocity (7.8 instead of 12 studs); server rejected landing rolls because replicated ground state lagged (now a bounded settle window, still server-observed); observers cancelled flips because the interpolated body was still grounded when attributes arrived (observers now start actions on receipt and end flips only after seeing them airborne); rigs now rescan as remote characters stream in.

Test-process note: an interrupted test run left Studio's network emulation at 60 ms/10 ms in the test window. It was found by the next run's snapshot, reset to 0 and verified; the two-client script now refuses to run unless the baseline is 0.

Limits: actual rendered 30/60/144 FPS sessions, slopes/steps foot placement, gamepad/touch devices, packet loss and larger player counts were not tested. Feel and visual quality need the owner's playtest; these checks show the mechanics work, not that they feel excellent.

## v1 results

### Passed

| Check | Observed result |
| --- | --- |
| Foundation pipeline | Existing formatting/lint/types, normal/test builds, source fidelity and package boundaries pass; default project still has only three probes |
| Movement pipeline | `python tools/verify_movement.py`: formatting/lint, engine-neutral math analysis, both movement builds and private-asset/test isolation pass |
| Numerical timestep checks | Actual Studio assertions passed at 30/60/144 Hz integration steps: speed convergence, no overshoot, braking and exponential turn blending; NaN/infinity checks |
| Profile comparison | Live steady speeds: Baseline 16, Athletic 24, Precise 21 studs/s; approximate distances over a 0.9 s sample: 14.0, 19.1, 17.5 studs |
| Start/stop/reversal | Athletic cruise about 24; stopped speed below 0.001. A reversal sampled after 80 ms was about -13.1 studs/s; subjective responsiveness still needs review |
| Evasion and wall | Open-ground displacement about 6.9 studs; wall-adjacent evade stayed behind the wall, moving about 1.8 studs in the tested approach |
| Jump/flourish/aim | Actual Freefall state, visible-joint rotation measured; physical root up = 1, camera roll = 0, aim-direction dot approximately 1; harmless marker placed |
| Respawn | Controller reattached to replacement R15 rig with 15 animation joints |
| Native keyboard bindings | Studio's real input tool exercised W/Shift, Q, Space and F in the final public sandbox; moved about 19.2 studs and triggered the flourish with root up = 1 |
| Two-client movement | Both clients reached about 24 studs/s. Observer rendered the other player's run with weight 1 and hip pitch magnitude up to 0.67 radians |
| Peer flourish | Observer measured visual rotation up to 6.20 radians while the physical root remained upright |
| Real network emulation | One client: 60 ms minimum delay in each direction, 10 ms jitter. Evade moved about 6.8 studs with no rejection or motion correction in the tested run; all modified settings restored to zero |
| Invalid requests | Server rejected 32 malformed/unknown/rate-limited requests; character health stayed 100 |
| Multiplayer respawn | Reattached, one HUD, mouse lock cleared; peer saw replacement rig; both players remained present |
| Teardown | Multiplayer test ended; no emulation setting left modified |
| Asset acquisition/playback | Two official free Cinderlore downloads retained privately; no scripts in either pack. All six movement clips and GuardReaction played on an actual R15 preview rig |

The two-client output had no project-script errors. The existing platform/avatar asset-type warning for `203785492` appeared again and is recorded separately. It is not a restricted Cinderlore ID and is not referenced by prototype source.

### Visual review and issues caught

Captured running poses and the seven selected private preview clips were actually inspected. This was sample-frame inspection plus confirmed Animator playback, not a full animator-quality review of all timings, loop seams or avatar proportions. Evasion/flourish still need human visual/feel feedback.

Live tests exposed the installed rig's AnimationConstraint joints, a blend-state reset against Animator evaluation, a jump-input probe timing issue, delayed position versus velocity in airborne validation, and mouse-lock cleanup across respawn. The implementation was corrected and the relevant checks rerun. Generated rig coloration was made readable for testing; it is not a creature/art-style decision.

### Limits and manual feedback

- Actual rendered 30/60/144 FPS sessions were not forced. Numerical timestep invariants do not establish full engine/physics FPS independence.
- Only a small local two-client and one network-condition sample was tested. No packet-loss, WAN, stress, mobile/gamepad-device or competitive exploit certification is claimed.
- The aim marker demonstrates camera-space input independence, not finished weapon grip/muzzle alignment or hit validation.
- Motor6D support exists in the presentation code but the actual tested rig used 15 AnimationConstraints. R6 is not targeted.
- CCL's complete opt-in setup was not validated; classes existed but the alias probe did not complete and AuthorityMode was unavailable in the checked scene. No beta/security setting was changed.
- Built-in MCP could not call LoadLocalAsset with its available capability. Only the separately inspected animation data was reconstructed for private previews; no capability/security restriction was changed.
- Restricted clips/IDs are not integrated into the public build. Further fit/blend work and any owner-controlled publishing remain manual choices.
- Slopes/step foot contact, camera comfort, stride quality and action usefulness require the playtest in [movement.md](movement.md). Do not call these polished or final.

[Sanitized evidence](evidence/2026-10-28-movement.json) contains measured results and source hashes. Raw logs, private captures and temporary IDs remain ignored. CI validates public source/builds only; Studio evidence is local and separate.

[Public-safe sandbox capture](evidence/movement-lab.jpg) shows only the original procedural study on a native Roblox rig, not downloaded animation playback.

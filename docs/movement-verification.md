# Movement prototype verification

Date: 2026-10-28. Studio 0.745.0.7451137, Rojo 7.7.1. Experimental branch only; no Roblox experience or animation published. This records technical progress, not a claim that movement feels excellent.

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

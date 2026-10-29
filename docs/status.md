# Current status

Updated: 2026-10-29
Milestone: movement refinement (v4.4: owner feedback on the Mixamo lab: wall run with height control, wall jump, parkour mantle with a clear-the-jump rule, fewer jumps, smoother transitions) on the isolated movement prototype
Branch: `experiment/movement-sandbox` (not merged; owner review of gameplay required first)

## Confirmed authorization

The owner authorized movement/controller research and refinement, relevant verified free assets/tools, an isolated playable sandbox, runtime/multiplayer testing and pushing this experimental branch. For animation, the owner first chose Mixamo + Blender, then chose original clips for now with Mixamo as a later option. On 2026-10-29 the owner chose to build on established free systems: adapt Place1's mantle and wall hop (MIT), with Mixamo still planned. The owner then downloaded 49 Mixamo clips with their own Adobe account and asked for all of them to be used for variation. After playing v4 the owner asked for fewer jump variants, smoother transitions, a standard wall run (sloped walls deferred), better wall jumps and a faster parkour mantle; running style is next. No paid purchase, new account connection, security/elevation change, animation upload or Roblox publication is authorized. Restricted animation sources and reusable IDs stay private.

## Implemented and verified

The foundation project is preserved. v2 keeps v1's native Humanoid controller, profiles, server validation and attribute replication, and replaces the presentation and actions:

- Original keyframed clips: run, sprint, back-pedal, strafes, idle, jump, fall, land, four directional rolls, front flip and backflip.
- Clip player with directional speed-matched locomotion, physics-driven air poses, landing absorption, crossfades, lean and rig-accurate ground contact.
- Single context-sensitive Q/B control: roll on the ground, flip in the air, buffered landing roll. Rolls move by their own root motion.
- v1 remains playable as `build/SlugshotMovementLab-v1.rbxlx` via `tools/build_movement_playtest.py`.
- Private Mixamo retarget pipeline (portable Blender, verified on synthetic data only, now including climb clips) and ignored private build path.
- v3: mantle (step vault or two-hand climb) and wall hop, with detection adapted from Place1 (MIT notice in source), original clips, server geometry/order checks and a traversal course. v2 is also rebuildable for comparison.

- v4 (private lab): all 49 Mixamo downloads as 54 clips with variants. It adds 8-way jog/run/sprint, crouch, start/stop/turn/settle/fidget/flinch transitions derived from motion, jump variants, three landing tiers, roll/flip variants (landing roll, drop flip), a hanging climb, vault, wall run, and a lab hit-reaction key. The converter was fixed on real Mixamo data.

- v4.1 (private lab, owner feedback): Space now triggers traversal (`JumpRequest` was not firing); wall run is an automatic attach state with kick-off; wall jumps use the owner's kick clips; parkour mantle under 4.6 studs (0.41-0.51 s); one running and one standing jump; no crouch drop or fidget; transitions and idle blend out smoothly; restyled stride; edge-tolerant ground check; wall-run corridor.
- v4.2: crouch idle at crouch-walk height; hold Space to climb / release to slide / tap to kick on the wall; wall hand solved to meet the wall; mantle only for ledges at least 2.2 studs up that the jump would not clear; falls sway about the jump pose (no Falling Idle).
- v4.3: wall run locked on until the floor, wall end or kick; up to 8 wall jumps per airtime with a 0.35 s press buffer (climb between walls); original speed-vault parkour mantle chosen when the jump reaches within 2 studs of the top, climb otherwise; HUD shows the last rejection.
- v4.4: directional wall kicks (up toward the wall once per wall, sideways along it, out otherwise); mantle over the top from a wall run or after a kick; mantles 0.2-0.3 s keeping speed.

v4.4 implemented/verified with evidence in [results](movement-verification.md#v44-owner-feedback-pass-2026-10-29) (single client, real keys; two-client not re-run).

v4.3 implemented/verified with evidence in [results](movement-verification.md#v43-owner-feedback-pass-2026-10-29). One test session showed 5 rejections from input the script did not send (cause not established).

v4.2 implemented/verified with evidence in [results](movement-verification.md#v42-owner-feedback-pass-2026-10-29): real-key wall climb/slide/tap, staircase without mantles, 3-stud jump-on versus 4.5/5.5 mantles, hand gap, two clients 5/5 (0 rejections, 0 corrections), public build and Studio tests.

v4.1 implemented/verified with evidence in [results](movement-verification.md#v41-owner-feedback-pass-2026-10-29): real-key single-client wall run/kick/chain and mantle timings, held-pose review of kick and mantle clips, two-client wall run 6/6 (0 rejections, 0 corrections), public-build fallback and Studio tests, edge and crouch checks. Studio network emulation was found left at 60/10 ms and reset to 0.

v4 implemented/verified with evidence in [results](movement-verification.md#v4-mixamo-clips-2026-10-29): Studio held-pose visual review; single-client checks of every new move and transition; public-build regression and Studio tests; two-client replication of crouch, vault, wall run, roll variant and flinch; one 60 ms + jitter trial (0 rejections, 0 corrections, settings restored to 0; one unexplained plain hop instead of a wall run, not reproduced in 4 repeats); respawn; forged requests rejected.

v3 implemented/verified with evidence in [results](movement-verification.md#v3-traversal-2026-10-29): mantles at 1.5-7.5 studs, chimney hop-hop-mantle, hop into backflip, path-placed pose review, two-client replication, one 60 ms + jitter trial (0 rejections, settings restored to 0), forged requests rejected, respawn.

v2 implemented/verified with evidence in [results](movement-verification.md#v2-refinement-2026-10-28): local checks; Studio clip tests; held-pose and live visual review; ground contact; single-client rolls/flips/landing roll/respawn; aim stability through a flip; two-client replication of run/roll/flip/directional variants; one 60 ms + jitter trial with settings restored to 0; invalid-request rejection; two-client respawn.

## Experimental / unresolved

Whether v2/v3/v4/v4.1 feel and look substantially better is the owner's playtest call, as are whether crouch, vault and wall run stay, and which Mixamo clips to keep or replace. The owner still dislikes the running/sprinting look (next item). Wall running on sloped walls was raised and deferred by the owner. Whether mantle and wall hop stay in the move set, final move set, controls (single acrobatics button or separate), speeds, roll distance, flip lift, animation style and camera remain open. Not established: rendered 30/60/144 FPS behaviour, foot placement on slopes/steps, devices, packet loss, large player counts, weapon/muzzle alignment, mantle arm IK, foot slide at sprint speed with realistic Mixamo cadence, moving platforms.

Next gate: owner plays the private v4.4 lab (directional wall kicks, up-and-over, quicker mantles), then the running animation rework; see [the movement guide](movement.md#playtest-priorities). No combat, creatures, progression, matchmaking or permanent environment/game-design decisions were implemented.

# Current status

Updated: 2026-10-29
Milestone: movement refinement (v3: v2 plus traversal) on the isolated movement prototype
Branch: `experiment/movement-sandbox` (not merged; owner review of gameplay required first)

## Confirmed authorization

The owner authorized movement/controller research and refinement, relevant verified free assets/tools, an isolated playable sandbox, runtime/multiplayer testing and pushing this experimental branch. For animation, the owner first chose Mixamo + Blender, then chose original clips for now with Mixamo as a later option. On 2026-10-29 the owner chose to build on established free systems: adapt Place1's mantle and wall hop (MIT), with Mixamo still planned. No paid purchase, new account connection, security/elevation change, animation upload or Roblox publication is authorized. Restricted animation sources and reusable IDs stay private.

## Implemented and verified

The foundation project is preserved. v2 keeps v1's native Humanoid controller, profiles, server validation and attribute replication, and replaces the presentation and actions:

- Original keyframed clips: run, sprint, back-pedal, strafes, idle, jump, fall, land, four directional rolls, front flip and backflip.
- Clip player with directional speed-matched locomotion, physics-driven air poses, landing absorption, crossfades, lean and rig-accurate ground contact.
- Single context-sensitive Q/B control: roll on the ground, flip in the air, buffered landing roll. Rolls move by their own root motion.
- v1 remains playable as `build/SlugshotMovementLab-v1.rbxlx` via `tools/build_movement_playtest.py`.
- Private Mixamo retarget pipeline (portable Blender, verified on synthetic data only, now including climb clips) and ignored private build path.
- v3: mantle (step vault or two-hand climb) and wall hop, with detection adapted from Place1 (MIT notice in source), original clips, server geometry/order checks and a traversal course. v2 is also rebuildable for comparison.

v3 implemented/verified with evidence in [results](movement-verification.md#v3-traversal-2026-10-29): mantles at 1.5-7.5 studs, chimney hop-hop-mantle, hop into backflip, path-placed pose review, two-client replication, one 60 ms + jitter trial (0 rejections, settings restored to 0), forged requests rejected, respawn.

v2 implemented/verified with evidence in [results](movement-verification.md#v2-refinement-2026-10-28): local checks; Studio clip tests; held-pose and live visual review; ground contact; single-client rolls/flips/landing roll/respawn; aim stability through a flip; two-client replication of run/roll/flip/directional variants; one 60 ms + jitter trial with settings restored to 0; invalid-request rejection; two-client respawn.

## Experimental / unresolved

Whether v2/v3 feel and look substantially better is the owner's playtest call. Whether mantle and wall hop stay in the move set, final move set, controls (single acrobatics button or separate), speeds, roll distance, flip lift, animation style and camera remain open. Not established: rendered 30/60/144 FPS behaviour, foot placement on slopes/steps, devices, packet loss, large player counts, weapon/muzzle alignment, Mixamo quality on real files, mantle arm IK, moving platforms.

Next gate: owner compares v1, v2 and v3 using [the movement guide](movement.md#playtest-priorities). No combat, creatures, progression, matchmaking or permanent environment/game-design decisions were implemented.

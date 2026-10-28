# Current status

Updated: 2026-10-28
Milestone: movement refinement (v2) on the isolated movement prototype
Branch: `experiment/movement-sandbox` (not merged; owner review of gameplay required first)

## Confirmed authorization

The owner authorized movement/controller research and refinement, relevant verified free assets/tools, an isolated playable sandbox, runtime/multiplayer testing and pushing this experimental branch. For animation, the owner first chose Mixamo + Blender, then chose original clips for now with Mixamo as a later option. No paid purchase, new account connection, security/elevation change, animation upload or Roblox publication is authorized. Restricted animation sources and reusable IDs stay private.

## Implemented and verified

The foundation project is preserved. v2 keeps v1's native Humanoid controller, profiles, server validation and attribute replication, and replaces the presentation and actions:

- Original keyframed clips: run, sprint, back-pedal, strafes, idle, jump, fall, land, four directional rolls, front flip and backflip.
- Clip player with directional speed-matched locomotion, physics-driven air poses, landing absorption, crossfades, lean and rig-accurate ground contact.
- Single context-sensitive Q/B control: roll on the ground, flip in the air, buffered landing roll. Rolls move by their own root motion.
- v1 remains playable as `build/SlugshotMovementLab-v1.rbxlx` via `tools/build_movement_playtest.py`.
- Private Mixamo retarget pipeline (portable Blender, verified on synthetic data only) and ignored private build path.

Implemented/verified with evidence in [results](movement-verification.md#v2-refinement-2026-10-28): local checks; Studio clip tests; held-pose and live visual review; ground contact; single-client rolls/flips/landing roll/respawn; aim stability through a flip; two-client replication of run/roll/flip/directional variants; one 60 ms + jitter trial with settings restored to 0; invalid-request rejection; two-client respawn.

## Experimental / unresolved

Whether v2 feels and looks substantially better is the owner's playtest call. Final move set, controls (single acrobatics button or separate), speeds, roll distance, flip lift, animation style and camera remain open. Not established: rendered 30/60/144 FPS behaviour, foot placement on slopes/steps, devices, packet loss, large player counts, weapon/muzzle alignment, Mixamo quality on real files.

Next gate: owner compares v1 and v2 using [the movement guide](movement.md#playtest-priorities). No combat, creatures, progression, matchmaking or permanent environment/game-design decisions were implemented.

# ADR 0005: Mixamo clips with variants, motion-derived transitions and new moves

Date: 2026-10-29
Status: Accepted for the experiment only; reconsider after owner playtest
Builds on: [ADR 0003](0003-clip-presentation.md), [ADR 0004](0004-place1-traversal.md)

## Context

The owner downloaded 49 Mixamo clips with their own Adobe account and asked for all of them to be used "intelligently for variation", including several per state (idles, jumps, strafes, sprints, crouch, climbs, rolls, flips, wall runs, hit reactions, gun-ready jumps and stops). Several clips have no slot in the v3 lab: crouching, starts, stops, turns, vaults, wall runs and hit reactions. The game is intended to be a shooter, but combat remains outside the authorized scope.

## Decision

- **Private retarget, named variants.** `tools/mixamo_manifest.json` maps each file to a runtime name; `Name.2`, `Name.3` are variants of `Name` (`Clips.variants`/`Clips.pick`). The server accepts a variant suffix on any validated action name. Generated data stays in ignored `private-assets/`; public builds keep the original clips.
- **Converter changes found on real files.** Mixamo exports already face forward, so pelvis-yaw facing normalisation is removed (it turned strafes and crouch walks sideways). Travelling loops have their drift removed and are recentred, and the drift sets their natural speed. One-shot clips lose their own travel. Turn clips are rotated to end facing forward. `vault` clips keep landing crouches and expose a lift curve.
- **Locomotion.** Speed tiers: jog → run → sprint. Eight directional anchors (forward, the four diagonals, strafes and back) blend by travel angle with a shared phase. There is a crouch set, and an injured idle below 35% health.
- **Transitions are derived from replicated motion,** so every client shows them without new network traffic: start, stop (also gun-ready and back-pedal stops), 180° turn, crouch enter/exit (to standing or into a run), settle after aiming, idle fidgets, flinch on health loss. Landings have three tiers by impact.
- **Variant choice.**
  - Jumps: standing, running, sideways (left/right, both mirrored for extra variants) and aiming.
  - Rolls: forward variants, plus a landing roll.
  - Flips: front and back variants, plus a drop flip for long falls.
  - Climbs: a hanging climb for tall ledges.
- **New experimental moves:**
  - **Crouch** (C / R3, 10 studs/s; physics height unchanged).
  - **Vault:** a thin wall at most 3.6 studs high, taken at speed, with a short look-ahead so an early press still vaults. The landing point is server-checked like a mantle.
  - **Wall run:** a wall hop taken along a wall at speed runs up it for 0.42 s, then kicks away.
  - **Lab key H:** self-damage, to preview the hit reactions. This is not a combat rule.

## Alternatives

- Using one clip per state would leave most of the owner's downloads unused.
- Networking each transition explicitly would add traffic for something every client can already infer from motion.
- A rifle locomotion set needs a weapon/grip decision, which is combat, so it was not attempted. Rifle-ready jumps and stops are used only while aiming.

## Consequences

Roll playback is now fitted to a 0.7 s duration, so the original public rolls are slightly slower than in v3. Mixamo motion is realistic and Roblox speeds are not: cadence is capped at 1.6× and feet can slide at sprint speed. Strafe clips twist the hips toward travel, as authored. Evidence: [results](../movement-verification.md#v4-mixamo-clips-2026-10-29).

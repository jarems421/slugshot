# Slug recovery after a shot

Status: **Confirmed design; Floppy implemented for owner testing, 2026-11-01.** The owner explicitly approved recovery at the landing site instead of travelling back to the shooter. See [ADR 0018](../decisions/0018-local-slug-recovery.md).

## General slugs

1. Land after the shot/impact.
2. Shake themselves off with a short, readable creature animation.
3. Burrow into the ground at that location, completing their narrative return to the owner's inventory.

Species can express their own personality within this sequence. There is no required journey across the map to a gun, character or belt capsule.

## Floppy

1. Land on its belly and skid in its direction of travel, stopping for walls and falling off ledges.
2. Wriggle and roll smoothly from its belly onto its back (owner follow-up, 2026-11-01).
3. Make a little upward hop, turn head-first, then actively wriggle and dig vertically into the ground at the landing site. The ground around it swells and heaves with each digging stroke while a small, messy pile of soil clods and angular rocks builds up, settles and fades afterwards.
4. The burrow represents Floppy returning to inventory.

The exit should read as a deliberate creature action. Disappearing while stationary, shrinking out of sight or replacing the puff with a different particle effect does not satisfy this direction.

## Cooldown and readability

- Keep inventory availability governed by the existing firing cooldown (currently 1.5 seconds from firing), independently of the local recovery scene. The owner approved this abstraction in the preceding discussion.
- **Owner, 2026-11-01:** the whole animation including the belly skid fits a **1.5-second window**, read as impact to gone because flight time varies. A long fall may overrun it rather than rushing the creature. The scene still never reads ammo readiness or ends in a puff; after a long flight the slug can be back in the gun before the scene ends.
- This also works when the shooter switches slugs or hides their capsules: recovery has no visible equipment destination.
- Keep recovery local and restrained. The owner specifically raised the clutter of 16 players sending fast returning slugs or recall streaks across a 4v4v4v4 map. That is a readability example, not a separate approval of a game mode.

## Implementation status and open details

**Implemented for Floppy:** `SlugVisuals.luau` hands impact recovery to `FloppyRecovery.luau`. Target/character hits release into a short local fall; raycasts find the floor while excluding character bodies. On the floor, Floppy lies belly-down, settles, wriggles using the existing body/head/tail/antenna bones, crouches, makes a 0.65-stud hop, turns head-first and dives vertically into the ground. Ground swells, a debris pile and a fading ground mark accompany entry (see current timing below). Every duplicate skeleton, including the ink shell, is animated in its own local axes. The source model and loaded-slug idle are unchanged.

**Current timing:** 0.10-second impact, 0.18-second landing settle, 0.95-second wriggle/roll onto the back, 0.16-second crouch, 0.42-second hop and 1.0-second digging descent, plus any fall to the floor. Transitions ease between the belly/back/dive poses; repeated body/antenna motion and small descending pulses convey digging. Twenty-four soil clods (stretched sphere meshes) and rocks (mixed wedge, corner-wedge and block shapes) emerge at staggered times, tumble outward and settle into uneven clusters. Seven half-buried swells in the floor's colour heave, tilt and shift outward in time with the digging strokes and stay mounded, so the floor visibly reacts throughout entry. Their palette samples the supporting Part color or Terrain material color. The rim settles and fades after entry. The model is removed only after it has sunk below the surface. Recovery does not read `launch.readyAt`; ammo remains available at the existing cooldown. Burrowing is cosmetic and does not alter Terrain.

**Verified:** full combat offline checks pass. One native Studio shot hit a training dummy and showed every recovery phase, persistence after cooldown, a 0.649-stud hop, bone wriggle and a head-first dive followed by cleanup. [Evidence and limits](../evidence/2026-11-01-floppy-recovery.json), [four-view pose sheet](../evidence/2026-11-01-floppy-recovery-poses.png).

**Roll/dig follow-up verified:** a real Studio target shot completed the belly-to-back roll, 0.85-second digging descent and gathering 12-piece rim; rim cleanup passed. Four views and a rim close-up were inspected. [Current evidence and limits](../evidence/2026-11-01-floppy-roll-dig.json), [current pose sheet](../evidence/2026-11-01-floppy-roll-dig-poses.png). Owner smoothness/appearance approval remains pending.

**Unresolved:** owner timing/pose approval, multiplayer load, moving surfaces, water-only areas and unsupported ledges. Water is ignored when looking for a supporting floor; a fall without support has bounded silent cleanup after three seconds or below the workspace kill height. Other species' specific recovery clips remain unimplemented.

**Ground-friction follow-up verified:** one real Studio target shot showed 24 debris pieces, seven surface patches, surface heave up to 0.090 studs above the floor and tilt up to 0.279 radians, continued recovery past cooldown, and complete cleanup. Four pose views were reviewed. [Latest evidence and limits](../evidence/2026-11-01-floppy-ground-friction.json), [pose sheet](../evidence/2026-11-01-floppy-ground-friction-poses.png). The owner described the preceding animation as almost perfect; this friction/messiness refinement still awaits owner approval.

**Earth-shape correction, 2026-11-01:** the ground-friction pass above met its counts but looked wrong in close-up: near-black debris on the range floor, perfectly round clods and flat plank-like ground patches. **Implemented/verified:** lighter soil and stone, stretched clods, mixed rock shapes and soft ground swells; timings and poses unchanged. A real Studio shot passed every phase and cleanup, and four floor types were inspected. Six shots at 60 FPS spawned the effect in 16-18 ms. Terrain floors, ledges, multiplayer load and owner approval remain open. [Evidence](../evidence/2026-11-01-floppy-earth-shapes.json), [four surfaces](../evidence/2026-11-01-floppy-earth-shapes-surfaces.png).

## How this was decided (owner, 2026-11-01)

The owner disliked the puff and asked for other options. These were discussed and are **not** the chosen design:

| Option | Why it was not chosen |
| --- | --- |
| Final leap and catch into the barrel | Breaks when a different slug is loaded by the time it returns. |
| Leap into a belt capsule | Capsules may be a hideable setting, so it would need a second ending. |
| Shrink out of sight at the hip | The owner: it "would just end up feeling like the poof away animation". |
| Recall streak or faster hops | A long shot forces "speeding back at the speed of light" to beat the cooldown; with 16 players "imagine how hectic". |
| Cooldown waits for the slug's physical return | Long shots would temporarily cost access to that slug. |

Dive-and-resurface was offered as a species-specific idea and is unused. Burrowing where it lands solved all of these; the owner's words were "this is how it's gonna be" and asked for it to be documented.

## Current sequence (2026-11-01, supersedes the timings above)

Shares of 1.5 s: impact 0.06, skid 0.24, wriggle and roll 0.5, crouch 0.07, hop 0.2, burrow 0.43. Earlier passes ran about 2.7-3 s; the 1.0-second dig the owner called almost perfect is now 0.43 s, so check that it still reads.

- **Livelier:** a wave runs up the body with each part late behind the last, on all bones. The roll flops with a slight overshoot and small bounces. The dig bites down on three strokes, screwing about 38° side to side, in time with the ground's heave.
- **Rounded underside:** a dome in the body colour with soft folds straight across replaces the flat base. It sits below the ground plane, so the standing look is unchanged. The first dark version was rejected.
- **Owner verdict:** "I like the burrow animation. You've done good with that." The stain circle on first impact is removed; the owner plans a different effect.
- **Steep rock:** the slug glances off faces too steep to stand on and keeps sliding to a floor. If wedged with no floor in reach after 1.2 s it digs into the rock it is stuck on; that fallback has not been exercised in a test.
- **Ledges:** debris pieces sit on the real ground under them and skip thin air.
- **Tuning:** total time, skid length and wiggle are on the P panel.

[Evidence and limits](../evidence/2026-11-01-review-pass.json), [poses](../evidence/2026-11-01-floppy-lively-poses.png), [underside](../evidence/2026-11-01-floppy-underside.png), [in game](../evidence/2026-11-01-floppy-underside-in-game.png). New underside verdict pending.

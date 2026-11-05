# Slug design record: Frostcrawler

## Confirmed - Iceburst and Ice Wall, 2026-11-04

**Owner:** "Okay, let's do ice burst. Let's do that one", then asked for the next slug. **Iceburst is the selected main** (direct hit plus a smaller immediate ice-shard splash very close to impact) and **Ice Wall the selected passive**. Brittle and Frostguard are no longer active options. Exact numbers, production effects, final forms and native implementation remain open. Older sections below that call the main undecided are history.

## Confirmed - scope, 2026-11-04

The owner requested the next slug from the approved 14-slug bank, using the same artifact procedure: generate alternatives, then let the owner rate and refine them. The assistant picked Frostcrawler. This choice does not approve a main, passive or final visual design. Neutral small/transformed placeholders remain appropriate for this comparison.

## Confirmed - Ice Wall passive; rejected first pass, 2026-11-04

**Owner:** rejected all six initial main/passive ideas as basic, with the main direction feeling like “you get frozen.” Selected a **small jagged ice wall/shield as physical cover**, grown by shooting floors, walls or ceilings. This is Frostcrawler's confirmed passive core. Preserve the cover identity; exact size, lifetime, durability, surface orientation, placement limits and elemental rules remain open.

The current artifact shows one passive, **Ice Wall**, with incoming fire blocked from the covered direction and an alternative flanking route. The illustrative orientation grows up from floors, down from ceilings and outward from walls. These orientation details and flank timing are demonstration choices, not finalized collision/game rules. No automatic melting, reflection or contact freeze is selected.

## Confirmed - preserve Ice Wall; simpler impact direction, 2026-11-04

**Owner:** Ice Wall is “perfect.” Preserve that visual/concept baseline. Prismfang, Ice Echo and Hailbreak were all rejected: they became overly complicated without being useful kinds of uniqueness. The owner wants a good familiar ice impact ability, not an unprecedented mechanic. Arachnet already binds movement, so avoid giving Frostcrawler another ground-sticking main; judge mechanic overlap across the whole roster.

**Considering - third main comparison:**

| Candidate | One clear payoff | Response / distinction |
| --- | --- | --- |
| Iceburst | Direct hit plus smaller immediate ice-shard splash against opponents very close to impact. | Spread before the shot or separate with solid cover. No slow, freeze, knockback or delayed secondary task. Unlike Crashwave, it is a short local burst rather than a travelling line. |
| Brittle | Direct damage briefly marks the opponent; the next ordinary landed hit gains a small bonus and consumes the mark. | Break line of sight until expiry or return fire. One-hit vulnerability, no movement restriction, no special target to shoot and no assumed existing armour system. |
| Frostguard | A landed hit grants the shooter a small temporary ice armour pool that absorbs limited incoming damage. | Keep pressure to spend it or wait for expiry. Mobile personal protection differs from placed Ice Wall cover; no invulnerability or movement restriction. |

All three mains are proposed, not approved. Iceburst is the assistant's current recommendation, not the owner's selection. Exact numbers, range, duration, stacking and interaction rules remain open. These familiar combat roles are exploratory alternatives, not an assertion that they satisfy the owner yet.

The artifact exposes these three mains and the unchanged approved Ice Wall, preserving the preceding viewer/source in `checkpoints/before-simple-ice`. The Ice Wall render block is checked byte-for-byte against that checkpoint. No native combat, physics, model or Studio place is changed.

**Implemented/verified locally, 2026-11-04 - simpler mains:** `check-simple-ice.mjs` passed 432 finite samples, immediate splash/spread, one-hit vulnerability/expiry, temporary armour/absorption/expiry, no movement locks, preserved Ice Wall cover/flank, prior confirmed pairs, controls and 390-pixel layout. Report/captures: `build/slugs/inferno/ability-concepts-20261104/qa-simple-ice/`. Main/cover desktop captures inspected. The Ice Wall render block matches its approved checkpoint exactly. Authored browser demonstrations are not native gameplay/physics/Studio evidence.

## Rejected - second main comparison

| Candidate | Standalone outcome / tactical use | Response |
| --- | --- | --- |
| Prismfang | Direct damage plus a stationary one-use ice prism. Shoot it to bank a later projectile into a fixed second firing lane beside cover. No homing or required partner species. | Move out of the reflected lane or destroy the exposed prism before the follow-up. Exact reflection/compatibility rules remain proposed. |
| Ice Echo | Direct damage leaves a physical ice copy at the struck position. One later shot into the copy relays reduced damage to its owner, then breaks it. An exposed second target offers a follow-up when the opponent moves behind cover. | Shoot your copy first or break its short link by distance. This is a visibly linked physical damage relay, not an illusion or freeze. |
| Hailbreak | Direct damage sends one visible shard up and over low cover, then down onto the original impact mark after a warning. | Leave the mark or shelter under a solid roof. No tracking after impact; no freeze/slow. |

All three second-pass mains above were rejected. The owner has not selected any replacement. Optional follow-ups with confirmed other slugs are sequential examples, not fusion powers or finalized interaction rules.

The second-pass artifact opened on Ice Wall, with these three now-rejected mains in the main tab. Initial six-option source/viewer is preserved in `checkpoints/before-icewall`; prior QA remains historical. These are neutral browser scenes, not final art or native gameplay.

**Implemented/verified locally, 2026-11-04 - Ice Wall revision:** `check-icewall.mjs` passed 432 finite scene samples; stationary bank evasion, ice-copy damage relay/destruction, fixed overhead strike/dodge, covered versus flanking fire on floor/wall/ceiling, selected prior pairs, controls and a 390-pixel layout. Evidence: `build/slugs/inferno/ability-concepts-20261104/qa-icewall/`. Desktop captures inspected; key main beats show effects before consumption. This is authored browser motion, not physics, native collision or Studio verification. Ice Wall lifetime/durability/placement and all three mains remain subject to the recorded approval states.

## Rejected - initial main alternatives

| Candidate | Solo effect | Counterplay / optional chain |
| --- | --- | --- |
| Rimebite | Impact damage and brittle leg ice that briefly slows movement while retaining aim/fire. | Shoot off the coating early. A slower target could be lined up for Crashwave. Unlike Snapbind, movement continues. |
| Shattermark | Impact damage leaves a visible crystal; a delayed small burst damages the tagged target and nearby opponents. | Shoot the crystal before detonation; nearby allies can spread. Snapbind could keep another target nearby, but a lone tagged target still takes the delayed hit. |
| Skidshock | Impact damage and a short low glide along the incoming shot direction, reducing braking while retaining aim/fire. | Steer sideways or meet solid cover to end the glide early. Could slide someone toward existing Surface Fire. Collision rules require later implementation. |

## Rejected - initial surface passive alternatives

| Candidate | Floor / wall / ceiling behaviour | Counterplay / optional chain |
| --- | --- | --- |
| Blackice | Visible slick contact patch preserves momentum with weaker braking: floor slide, wall drift or continued travel after a jumping ceiling brush. | Avoid contact or approach slowly. Either team may use it. Could carry speed into Silkline; no direct damage. |
| Ice Shelf | A temporary solid foothold: floor step, wall ledge or a ceiling-supported hanging step. | Shoot the brittle foothold or use another route. Either team could exploit the new angle; detailed access/collision rules remain open. |
| Frostmine | A visible surface bud triggers on close contact, flashes a warning, then bursts with damage and brief slow in its local radius. | Shoot it before approaching or leave during the warning. Backdraft could push someone toward the trap, but it also works alone. |

All six initial options above were rejected by the owner. Partner examples are inspiration, not extra equipped powers, fusion attacks or finalized elemental rules. No automatic water/electric/fire interaction is implied. Main and passive activate automatically based on player versus environmental impact; comparison tabs are not in-game firing modes.

## Historical implementation - first concept artifact

Viewer: `build/slugs/inferno/ability-concepts-20261104/Slugshot-ability-lab.html` (earlier HTML alias preserved). It opens on Frostcrawler and retains confirmed Inferno, Aquabeek and Arachnet references. Three main and three passive buttons have playback, tactical/counterplay and surface controls. Health/timing and authored movement illustrate outcomes rather than chosen tuning or physics simulation. The pre-change viewer/source is checkpointed at `checkpoints/before-frostcrawler`.

Original faceted ice effects and neutral forms are browser geometry. No final creature mesh, Blender scene, native gameplay, private upload or Studio place is changed. Existing local concept vendor/model provenance is preserved.

**Implemented/verified locally:** `check-frost.mjs` passed 576 finite scene samples, all six solo effects/counterplay assertions, floor/wall/ceiling cases, confirmed prior pairs, controls and 390-pixel layout. Desktop scene captures were inspected. Report and images: `build/slugs/inferno/ability-concepts-20261104/qa-frostcrawler/`. Authored browser movement is not physics/Studio evidence. Earlier viewer/source checkpointed in `checkpoints/before-frostcrawler`; no native gameplay or accepted model changes.

## Unresolved

Owner ratings and main selection; passive tuning/orientation; final forms and original production name/art; damage, durations, ranges, control strength, team rules and repeat limits; elemental interactions and native/multiplayer/device validation.

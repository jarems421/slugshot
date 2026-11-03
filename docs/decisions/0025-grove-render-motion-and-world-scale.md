# 0025 ? Exhibition motion and outside-gun size

Date: 2026-11-03. Status: Implemented experimental presentation; owner review pending.

## Context

The owner reported choppy hopping and partial rock support, requested spring anticipation, exhibition-only roaming, nearby facial reactions and approximately two-stud slugs outside the gun. Fewer residents are permitted if necessary.

## Decision

Separate infrequent AI/support decisions from per-render-frame poses. Grounding requires nine footprint contacts on a gentle dry plane; align the standing model to that plane, relocate unsafe authored starts, and omit sites without full support. Destinations stay inside a bounded exhibition region and near each resident's home. Use compression, a short hold, extension, flight and landing, with delta-time turning and no redundant idle model writes.

Reuse existing facial controls with an explicit resident path so Inferno's display acrobatics do not compete with locomotion. Limit active glances to three and detailed facial animation to nearby residents. Retain 14 supported sites (nine Floppies, five Infernos); omit the narrow pond rock at site 6.

One shared `Combat.WorldSlugSize = 2` supplies world flight/recovery and grove presentation. The chamber/viewmodel keeps its independent loaded scale. Projectile speeds, damage and hit radius are not changed by this visual-size request.

## Evidence and limits

[Runtime implementation and native/offline evidence](../art/lobby-hub.md#springing-exhibition-residents--2026-11-03). Presentation is local to each client; no synchronized NPC simulation or new gameplay remote is introduced. Ground probes validate Roblox collision surfaces, not every rendered skinned vertex. Owner appearance/feel, observers and real-device performance remain separate checks.


## 2026-11-03 owner clarification

Splat is body-only squash/recovery, with no floor effect. Increase landing deformation and retain a brief takeoff tension hold. Floppy's permanent export sole now matches Inferno's flat folded support, with two sage spore patches. Source/rig review and actual private staged-model Studio evidence are linked in the lobby record.

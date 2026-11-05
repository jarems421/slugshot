# Slugshot knowledge index

Open this repository or `docs/` as an Obsidian vault. All notes use ordinary Markdown links and need no Obsidian plugins. Notes are versioned alongside source; personal workspace state is ignored.

## What are you working on

Read [status](status.md) first, then only this row. Add to it only if the task needs more.

| Task | Skill | Read |
| --- | --- | --- |
| New slug design | `slugshot-creature-production` | [Catalogue](slugs/catalog/index.md), [style guide](art/style-guide.md), [how the owner works](slugs/owner-design-language.md#how-the-owner-works) |
| Change a slug's model, face, rig or material | By [skill routing](slugs/skill-routing.md) | Slug's record, [lesson index](lessons-index.md) |
| New slug motion | `slugshot-animation-director` | [Motion library](slugs/motion-library.md), slug's record |
| Slug motion in Luau, or a fix | `slugshot-procedural-animation` | The motion script, [motion library](slugs/motion-library.md) |
| Blender clip or keyframes | `el4cteo-blender-animation` | [Rig contract](slugs/rig-specification.md) |
| Motion looks wrong | [Motion review](slugs/motion-review.md) | [Lesson index](lessons-index.md) by symptom |
| Transformation | Director or procedural | [Transformation](slugs/transformation-system.md) |
| Slug abilities | None | [Ability playbook](slugs/ability-playbook.md), [ability planning](slugs/ability-planning.md), slug's record, [ability lab](../tools/slugs/ability-lab/README.md) |
| Slug import or Roblox playback | `el4cteo-blender-export-pipelines` | [Studio import](slugs/studio-import.md) |
| Lobby or environment | None | [Lobby checkpoint](art/lobby-checkpoint.md), [style guide](art/style-guide.md) |
| Training arena or the game place | None | [Training arena](art/training-arena.md) |
| Combat, guns, first person | None | [Combat](combat.md), [loadout](loadout-controls.md) |
| Movement | `roblox-movement-experiments` | [Movement](movement.md) |
| PvP UI | None | [PvP UI](pvp-ui.md) |
| Sound | None | [Sound plan](audio/sound-plan.md) |
| Foundation, multiplayer, assets | `roblox-foundation`, `roblox-multiplayer-validation`, `roblox-asset-pipeline` | [Architecture](architecture.md), [testing](testing.md) |
| Why was this decided? | None | Search [status history](status-history.md), [memory](memory.md), [decisions](decisions/) |

## All notes

- [Vision and decision states](vision.md)
- [Architecture](architecture.md)
- [Development and memory workflow](development.md)
- [Coding conventions](conventions.md)
- [Tests and Studio verification](testing.md)
- [Integrations and approval-dependent setup](integrations.md)
- [Technical research and specialist tooling](research/tooling.md)
- [Skill evaluation](research/skills.md)
- [Rocklock cavern map](rocklock.md), [layout](diagrams/rocklock-layout.svg) and [validation](rocklock-verification.md)
- [Rocklock V2 redesign and destruction](rocklock-v2.md), [routes](diagrams/rocklock-v2-routes.svg), [interactions](diagrams/rocklock-v2-interactions.svg) and [ADR 0011](decisions/0011-rocklock-v2-destruction.md)
- [Movement lab and playtest plan](movement.md)
- [Movement research](research/movement.md), [asset provenance](movement-assets.md) and [results](movement-verification.md)
- [Loadout selection and inspect](loadout-controls.md), [ADR 0021](decisions/0021-loadout-controls-and-inspect.md)
- [Sound event audit, proposed direction and five-sound approval batch](audio/sound-plan.md)
- [PvP UI: HUD, inventory, settings, keybinds and goo](pvp-ui.md), [ADR 0020](decisions/0020-ui-goo-and-keybinds.md)
- [Combat / temporary target range](combat.md), [shot consistency](combat.md#shot-consistency-and-distinct-floppy-powers-2026-11-02-current), [ADR 0022](decisions/0022-shot-frame-and-flight-consistency.md), [first-person camera research and comparison](research/first-person-acrobatics.md) and [reversible camera experiment](decisions/0014-acrobatic-camera-comparison.md)
- [First-person owner wording and recurring regression fixes](combat.md#owner-language-contextual-interpretations-to-carry-forward)
- [Combat charge art direction and lobby references](research/charge-art-direction.md)
- [Asset register and conventions](assets.md)
- [Complete local environment preview](art/environment-preview/README.md)
- [General shop concept](art/general-shop.md), [shop reference research](research/slugterra-shops.md) and [reusable curled cave fern](art/curled-cave-fern.md)
- [Slug asset pipeline](slugs/pipeline.md), [rig contract](slugs/rig-specification.md), [species guide](slugs/species-guide.md), [transformation API](slugs/transformation-system.md), [Studio import](slugs/studio-import.md) and [evidence](slugs/verification.md)
- [Slug design catalogue and records](slugs/catalog/index.md)
- [Ability playbook](slugs/ability-playbook.md): what has worked when proposing abilities.
- [Slug roster and ability planning](slugs/ability-planning.md): confirmed 14-slug bank, Inferno decisions and [Aquabeek's final abilities](slugs/catalog/aquabeek.md); [Arachnet’s confirmed Snapbind/Silkline](slugs/catalog/arachnet.md) and current [Frostcrawler studies](slugs/catalog/frostcrawler.md), sequential combinations and provisional examples.
- [Inferno inspect: approved Playful Flame and native evidence](slugs/inferno-inspect-studies.md), [ADR 0025](decisions/0029-inferno-inspect-surface.md)
- [Confirmed slug recovery and Floppy burrow sequence](slugs/recovery.md), [ADR 0018](decisions/0018-local-slug-recovery.md)
- [One-handed ADS](decisions/0019-one-handed-ads.md)
- [Gun, flip, burrow and first-person review with proposals (2026-11-01)](reviews/2026-11-01-combat-feel-review.md)
- [Lobby checkpoint, 2026-11-03](art/lobby-checkpoint.md): start here for lobby work.
- [Visual style guide](art/style-guide.md), [lobby roadmap](art/lobby-roadmap.md), [lobby asset plan](art/lobby-assets.md) [Slugterra environment research](research/slugterra-environment.md), [art lessons](art/lessons.md), [look pack](art/look-pack.md) and the [asset library](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr)
- [Owner design language](slugs/owner-design-language.md): what feedback phrases have meant, working style, animation/runtime lessons
- [Blender modelling lessons](slugs/blender-lessons.md)
- [Slug skill routing](slugs/skill-routing.md), [full skill audit](slugs/skill-audit.md) and [installation audit](slugs/install-audit.md)
- [Lesson index](lessons-index.md), [motion library](slugs/motion-library.md) and [motion review](slugs/motion-review.md)
- [Blender tooling decision](decisions/0017-blender-tool-routing.md)
- [Creature proposal template](templates/creature.md)
- [ADR template](templates/adr.md), [foundation ADR](decisions/0001-foundation.md), [movement ADR](decisions/0002-movement-experiment.md), [clip presentation ADR](decisions/0003-clip-presentation.md), [Place1 traversal ADR](decisions/0004-place1-traversal.md), [Mixamo variants ADR](decisions/0005-mixamo-variants-transitions.md), [wall run / v4 feedback ADR](decisions/0006-wall-run-and-v4-feedback.md), [block limbs ADR](decisions/0007-block-limbs-and-original-run.md), [R6 rig ADR](decisions/0008-r6-rig.md) and [cleanup / type check ADR](decisions/0009-cleanup-type-check-and-trusted-physics.md)
- [Roadmap](roadmap.md)
- [Open questions](questions.md)
- [Training arena](art/training-arena.md)
- [Current status](status.md) and [status history](status-history.md)
- [Dated memory](memory.md)
- [Verification evidence](verification.md)

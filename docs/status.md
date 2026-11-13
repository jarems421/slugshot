# Current status

Last reviewed 2026-11-04. The short, current truth: **replace lines here when they change** rather than adding to the top. Put dated evidence in [status history](status-history.md) and [memory](memory.md).

## The game

**Implemented/verified in Studio (2026-11-04):** one game place, `python tools/training/build_game.py` builds `build/SlugshotLobbyTraining.rbxlx`: the full lobby, the training arena through its portal, guns, slugs, inspections, settings and the loading screen. Other places (`build_hub.py`, combat range, inspect reviews) are for testing only. Approved work is merged to `main` and belongs in this place. Nothing is published; publishing needs the owner.

## Approved by the owner

| Area | Decision | Record |
| --- | --- | --- |
| Floppy | Final design; never transforms, so it has no abilities | [Catalogue](slugs/catalog/flopper-inspired.md) |
| Inferno | Final design, both forms | [Catalogue](slugs/catalog/inferno.md) |
| Inferno inspect | Playful Flame | [Studies](slugs/inferno-inspect-studies.md) |
| Inspection | Flip the gun up, the slug's act, flip to catch it down | [Briefs](slugs/catalog/inspect-profiles.md) |
| Slug roster | 14 slugs (12 acceptable at launch) | [Planning](slugs/ability-planning.md) |
| Abilities | A main (Q) and a passive (E) per slug, armed for the next shot, skill-based and intertwining, with an [element chart](slugs/ability-specs.md#element-chart---confirmed-2026-11-05). [Specs](slugs/ability-specs.md). Inferno: Dragon's Breath and Fire Curtain. Aquabeek: Crashwave and Mistbank. Arachnet: Snapbind and Silkline. Frostcrawler: Iceburst and Ice Wall. Tazerling: Chain Lightning and Livewire. Rammstone: Shove Punch and a rock cover and map-breaking passive. Boon Doc: Mending Shot and Healing Spring. Tormato: Tornado and Updraft. Vinedrill: Tangle and Bramble. Phosphoro: Flash and Lantern. Flatulorhinkus: Nausea and Stink Cloud. Hop Rock: Sticky Bomb and Mine. Frightgeist: Jump Scare and Decoy. None built in the game yet | [Catalogue](slugs/catalog/index.md) |
| Lobby | Slug Grove complete; slow lava gloop approved | [Checkpoint](art/lobby-checkpoint.md) |
| Art direction | Living Comic-Book Fantasy | [Style guide](art/style-guide.md) |

## Open with the owner

- **Lobby rounds 3 to 12** (in main and the game place): lit cavern, far side, plain mountain, revamped pit; owner's verdict, hand tests and phone cost pending. [Lobby hub](art/lobby-hub.md).
- **Tazerling look** (2026-11-12, branch): base-form concept; owner verdict pending. [Record](slugs/catalog/tazerling.md).
- **Rammstone:** the passive's name, and rock cover's lifetime and height. [Spec](slugs/ability-specs.md#rammstone---confirmed-spec-2026-11-06).
- **Ability system** (2026-11-06, in main): shared system plus Aquabeek built and checked in Studio; Q/E arming, Inventory on F, themed name tags. Movement v7.40: straight wall runs with a hop up, smoother kicks; owner feel pending. [Built so far](slugs/ability-specs.md#built-so-far---2026-11-06).
- **Inspection and shot size** (2026-11-07, in main): R in third person shows the act in first person, with the canister held nearer so the slug reads about 1.4 times bigger; Inferno's flame inspection now in the game place; fired slugs 1.3 studs, lobby slugs stay 2. Owner verdict pending. [Inspect note](loadout-controls.md#current-first-person-inspect-view-2026-11-07).
- **Canister HUD** (2026-11-07, in main): the slug bar is five separate canisters like the blaster's, with the health bar 1.3 times bigger on top and the Q/E chips either side; revised for the owner's notes (no inner outline, smaller still slugs, cap the size of the base). Checked in Studio with real keys; owner verdict pending. [PvP UI](pvp-ui.md#what-the-owner-chose).
- **Inspections** (2026-11-07, in main): livelier Burpy (deeper inhale, strain, resting breath), Floppy loaded as tall as Burpy, Floppy looks up from the waist so his under-eyes stop smearing; fired slugs 1.3 studs. Burpy's mesh memory: the grove's display Infernos filled it; fixed, ready in both views; the act needs the owner's look. [Inspect studies](slugs/inferno-inspect-studies.md).
- **Aim and wall runs** (2026-11-07, in main): Floppy flies flatter (120/145/170, gravity 35, drag 0.2) and empty space aims 100 studs out, so shots stop lobbing over the crosshair; wall runs hold their height (v7.41). Owner feel pending; wall runs not yet tried by hand. [Combat](combat.md#flatter-floppy-and-a-farther-empty-space-aim-2026-11-07-current), [movement](movement.md#what-changed-in-v741-wall-runs-hold-their-height).
- **Ability specs:** every slug's main and passive defined and confirmed (2026-11-06), with the element chart, Q/E arming, cooldowns and caps. Next: classes and rarities. [Specs](slugs/ability-specs.md).
- **Remaining kits:** none; every other slug has a main and a passive. Floppy has no abilities. Read the [ability playbook](slugs/ability-playbook.md) first.
- **Ability planning rule:** base concepts first with numbers later; maps get built around the abilities; Rocklock V2 was only a test.
- **Shared transformation:** the glow, twirl and reveal are in; the owner's verdict on feel is pending. [Transformation](slugs/transformation-system.md).
- **Animation tooling** (2026-11-04): director and procedural skills, motion preview and motion review are new and unproven on a real slug task. [Library](slugs/motion-library.md).

## Known problems

- The first portal trip after joining can show the loading screen before its picture has loaded; it is fine from the second trip.
- No multiplayer or device coverage yet for most slug motion and effects.
- Abilities are designed but not implemented beyond the existing shots.

## Before you start

Other worktrees hold in-progress branches (`git worktree list`); preserve them. Every branch was merged into `main` on 2026-11-07, with nothing left uncommitted. Check `git status` first and do not discard what you did not make.

# Current status

Last reviewed 2026-11-04. The short, current truth: **replace lines here when they change** rather than adding to the top. Put dated evidence in [status history](status-history.md) and [memory](memory.md).

## The game

**Implemented/verified in Studio (2026-11-04):** one game place, `python tools/training/build_game.py` builds `build/SlugshotLobbyTraining.rbxlx`: the full lobby, the training arena through its portal, guns, slugs, inspections, settings and the loading screen. Other places (`build_hub.py`, combat range, inspect reviews) are for testing only. Approved work is merged to `main` and belongs in this place. Nothing is published; publishing needs the owner.

## Approved by the owner

| Area | Decision | Record |
| --- | --- | --- |
| Floppy | Final design; never transforms, so it has no abilities | [Catalogue](slugs/catalog/flopper-inspired.md) |
| Inferno | Final design, both forms; in flight, a smooth body of fire off each wing tip on Rammstone's recipe, scaled down for two (2026-11-14, owner verdict pending) | [Catalogue](slugs/catalog/inferno.md) |
| Aquabeek | Final design, both forms (2026-11-14) | [Catalogue](slugs/catalog/aquabeek.md) |
| Inferno inspect | Playful Flame | [Studies](slugs/inferno-inspect-studies.md) |
| Inspection | Flip the gun up, the slug's act, flip to catch it down | [Briefs](slugs/catalog/inspect-profiles.md) |
| Slug roster | 14 slugs (12 acceptable at launch) | [Planning](slugs/ability-planning.md) |
| Abilities | A main (Q) and a passive (E) per slug, armed for the next shot, skill-based and intertwining, with an [element chart](slugs/ability-specs.md#element-chart---confirmed-2026-11-05). [Specs](slugs/ability-specs.md). Inferno: Dragon's Breath and Fire Curtain. Aquabeek: Crashwave and Mistbank. Arachnet: Snapbind and Silkline. Frostcrawler: Iceburst and Ice Wall. Tazerling: Chain Lightning and Livewire. Rammstone: Shove Punch and a rock cover and map-breaking passive. Boon Doc: Mending Shot and Healing Spring. Tormato: Tornado and Updraft. Vinedrill: Tangle and Bramble. Phosphoro: Flash and Lantern. Flatulorhinkus: Nausea and Stink Cloud. Hop Rock: Sticky Bomb and Mine. Frightgeist: Jump Scare and Decoy. None built in the game yet | [Catalogue](slugs/catalog/index.md) |
| Boon Doc | Final base and transformed designs (2026-11-14) | [Catalogue](slugs/catalog/boon-doc.md) |
| Tormato | Final base and transformed designs (2026-11-15) | [Catalogue](slugs/catalog/tormato.md) |
| Lobby | Slug Grove complete; slow lava gloop approved | [Checkpoint](art/lobby-checkpoint.md) |
| Art direction | Living Comic-Book Fantasy | [Style guide](art/style-guide.md) |

## Open with the owner

Full wording of these items, as of 2026-11-16, is in [status history](status-history.md#status-open-items-moved-2026-11-16).

- **Slug idles and faces** (2026-11-16): reusable `SlugIdle` performances, HUD canister flipbooks, Aquabeek's eyes, mouth bones on Aquabeek, Rammstone, Tormato and Boon Doc, Tormato's spinning eyes, every slug in the Slug Grove; verdict pending. [PvP UI](pvp-ui.md), [lobby hub](art/lobby-hub.md).
- **HUD and UI** (2026-11-14 to 16): satchel, health bar, canisters and gaps; inventory loadout swap (six slugs, five slots); verdict pending. [PvP UI](pvp-ui.md).
- **Flight trails** (2026-11-14): Rammstone's confirmed as the ideal; Inferno's and Aquabeek's on his recipe, scaled down; verdict pending.
- **Tazerling:** final base design; transformed form concept 4 pending. [Record](slugs/catalog/tazerling.md).
- **Tormato, Boon Doc, Aquabeek, Rammstone:** designs final and in the game place; a shot's transformation and flight not yet seen for Tormato and Boon Doc. [Catalogue](slugs/catalog/index.md).
- **Lobby rounds 3 to 12:** verdict, hand tests and phone cost pending. [Lobby hub](art/lobby-hub.md).
- **Earlier, verdict pending:** ability system and Aquabeek's kit, inspection and shot size, canister HUD, livelier inspections, flatter Floppy aim and wall runs (2026-11-06 to 07); shared transformation feel. [Ability specs](slugs/ability-specs.md), [inspect note](loadout-controls.md).
- **Next design steps:** classes and rarities; abilities first, maps after, numbers later. [Playbook](slugs/ability-playbook.md).

## Known problems

- The first portal trip after joining can show the loading screen before its picture has loaded; it is fine from the second trip.
- No multiplayer or device coverage yet for most slug motion and effects.
- Abilities are designed but not implemented beyond the existing shots.

## Before you start

Other worktrees hold in-progress branches (`git worktree list`); preserve them. All work to 2026-11-16 is committed on `integration/lobby-all`. Check `git status` first and do not discard what you did not make.

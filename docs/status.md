# Current status

Last reviewed 2026-11-04. The short, current truth: **replace lines here when they change** rather than adding to the top. Put dated evidence in [status history](status-history.md) and [memory](memory.md).

## The game

**Implemented/verified in Studio (2026-11-04):** one game place, `python tools/training/build_game.py` builds `build/SlugshotLobbyTraining.rbxlx`: the full lobby, the training arena through its portal, guns, slugs, inspections, settings and the loading screen. Other places (`build_hub.py`, combat range, inspect reviews) are for testing only. Approved work is merged to `main` and belongs in this place. Nothing is published; publishing needs the owner.

## Approved by the owner

| Area | Decision | Record |
| --- | --- | --- |
| Floppy | Final design; never transforms | [Catalogue](slugs/catalog/flopper-inspired.md) |
| Inferno | Final design, both forms | [Catalogue](slugs/catalog/inferno.md) |
| Inferno inspect | Playful Flame | [Studies](slugs/inferno-inspect-studies.md) |
| Inspection | Flip the gun up, the slug's act, flip to catch it down | [Briefs](slugs/catalog/inspect-profiles.md) |
| Slug roster | 14 slugs (12 acceptable at launch) | [Planning](slugs/ability-planning.md) |
| Abilities | Player-hit effect plus a surface passive. Inferno: Backdraft and surface fire. Aquabeek: Crashwave and Mistbank. Arachnet: Snapbind and Silkline. Frostcrawler: Ice Wall passive | [Catalogue](slugs/catalog/index.md) |
| Lobby | Slug Grove complete; slow lava gloop approved | [Checkpoint](art/lobby-checkpoint.md) |
| Art direction | Living Comic-Book Fantasy | [Style guide](art/style-guide.md) |

## Open with the owner

- **Far side cave and cavern wall** (library studies on `integration/lobby-all`, uncommitted): option C (mushroom depths) chosen; verdict on the wall and spires pending; no Roblox build yet. [Lobby hub](art/lobby-hub.md#far-side-cave-and-the-cavern-wall-owner-2026-11-04).
- **Frostcrawler main ability:** Iceburst, Brittle or Frostguard, none chosen. [Record](slugs/catalog/frostcrawler.md).
- **Shared transformation:** the glow, twirl and reveal are in; the owner's verdict on feel is pending. [Transformation](slugs/transformation-system.md).
- **Animation tooling** (2026-11-04): director and procedural skills, motion preview and motion review are new and unproven on a real slug task. [Library](slugs/motion-library.md).

## Known problems

- The first portal trip after joining can show the loading screen before its picture has loaded; it is fine from the second trip.
- No multiplayer or device coverage yet for most slug motion and effects.
- Abilities are designed but not implemented beyond the existing shots.

## Before you start

Other worktrees hold in-progress branches (`git worktree list`); preserve them. This tree currently has uncommitted lobby and ability work. Check `git status` first and do not discard what you did not make.

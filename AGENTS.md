# Slugshot agent instructions

Slugshot is an original Roblox multiplayer creature-combat game. Approved work merges to `main` and appears in one game place; other places are for testing.

## What to read

1. [Current status](docs/status.md): what is built, approved and open.
2. The row for your task in the [task router](docs/index.md#what-are-you-working-on). Read what it names.
3. Before trying a fix, search the [lesson index](docs/lessons-index.md) by symptom. Follow a link only if the row is not enough.

History is evidence, not instructions. [Status history](docs/status-history.md), [memory](docs/memory.md), full lessons and older sections of feature notes get searched narrowly when investigating, and are not read through.

## Which decision wins

Latest explicit owner decision, then the current accepted implementation, then the current technical contract, then historical lessons, then unapproved proposals. The newer item must concern the same decision: a new technical test does not override an artistic approval. "Accepted" means stop: preserve it and change only what is asked. When a decision changes, update the current record and keep the old entry as history.

## Scope and authority

The owner decides art, gameplay and scope. Proposed ideas stay proposed until approved. Use original or appropriately licensed IP, and record each slug's facts in the [catalogue](docs/slugs/catalog/index.md). Visual work follows the [style guide](docs/art/style-guide.md). Movement behaviours, controls, camera settings and combat numbers are still prototypes; final environments, matchmaking and progression need further instruction. The PvP UI's rules are in [its note](docs/pvp-ui.md); lobby phases follow the [roadmap](docs/art/lobby-roadmap.md).

Reviewing and merging committed workstreams into `main`, and relevant verified free movement resources, are authorized. **Ask first** for: paid purchases, new external accounts, elevated permissions or security changes, destructive operations, publishing a Roblox experience, and anything sent to an outside service that was not requested. Never push restricted animation source or reusable IDs. Keep secrets out of shared code, and restricted assets and IDs in ignored private storage. Review third-party source and licences before installing or running them.

## Working procedure

Inspect files and Git status first; other worktrees and uncommitted changes may be someone else's, so preserve them. Follow the [coding conventions](docs/conventions.md).

| Code | Lives in | Check |
| --- | --- | --- |
| Foundation | `src/client`, `src/server`, `src/shared` | `python tools/verify.py` |
| Movement | `experiments/movement` and its own Rojo projects | `python tools/verify_movement.py` |
| Combat | `experiments/combat` | `python tools/verify_combat.py` |
| Creatures | `experiments/creatures` and its own Rojo projects | `python tools/verify_slugs.py` (`--blender` for source and export) |
| Lobby and training | `experiments/lobby`, `experiments/training`, `tools/lobby`, `tools/training` | The relevant check in `tools/` |

These checks do not run Roblox. Use the relevant Studio checklist, drive controls with real input, and record actual evidence and limits. Keep tests out of normal builds. Generated files stay under ignored `build/`.

Keep skills identical in `.agents/skills` (Codex) and `.claude/skills` (Claude), and run `python tools/slugs/check_skill_routing.py` after changing skills or routing.

Subagents suit reference research, large logs and independent critique. Never put two agents on one live Blender scene or on the same files; parallel creative drafts each get their own copy and output folder, and the main session coordinates.

## Recording

After meaningful work:

- Update the current record: replace the relevant line in [status](docs/status.md), the catalogue or the feature note.
- Add a dated line to [memory](docs/memory.md), and evidence to [status history](docs/status-history.md) if it is long.
- Add a row to the [lesson index](docs/lessons-index.md) if a fix would save the next attempt. Separate a principle from a slug-specific number.
- Label facts Confirmed, Considering, Unresolved or Implemented/verified, with evidence. Capture architectural changes in an ADR. A passing check is not art approval.

Do not store credentials or private account data in notes. See [development workflow](docs/development.md).

# Slugshot agent instructions

Read [docs/index.md](docs/index.md), [vision](docs/vision.md), and [current status](docs/status.md) before changing scope. Follow [coding conventions](docs/conventions.md).

## Scope and authority
The foundation baseline is preserved. Movement research/prototype on `experiment/movement-sandbox` remains isolated; see `docs/movement.md` and ADR 0002. The owner authorized the technical slug asset pipeline and placeholder on `feature/slug-asset-pipeline`, then explicitly requested the first original Flopper-inspired design draft and a catalogue for future slugs. See `docs/slugs/pipeline.md`, `docs/slugs/catalog/index.md` and ADR 0011. Creature runtime stays in `experiments/creatures` and its own Rojo projects. Do not edit concurrent Rocklock, map generation, destruction or movement work, merge into main or publish assets. Movement behaviors, controls, profiles and camera settings remain experimental. Full combat, final creatures/environments, matchmaking, progression and exploration require further instructions. Record each slug's facts and design ideas in the catalogue. Use original or appropriately licensed IP.

## Working procedure
Inspect existing files and Git status first; preserve unrelated changes. Foundation code stays in `src/client`, `src/server` and `src/shared`. Movement experiment code stays in `experiments/movement` and its dedicated Rojo projects; never sync it into the foundation place. Shared code cannot contain secrets. Keep tests out of normal builds and restricted assets/IDs under ignored private storage.

Run `python tools/verify.py` for foundation changes and `python tools/verify_movement.py` for the movement experiment (it also runs foundation checks). These do not execute Roblox. Use the relevant Studio checklist and record actual runtime evidence, warnings and subjective limits.

For creature infrastructure use `python tools/verify_slugs.py --blender` with an existing Blender executable selected by `BLENDER` if necessary. Generated source/export/preview files stay under ignored `build/slugs`; authored source is separate. Follow `docs/slugs/studio-import.md`; native fixtures and offline FBX reimport do not prove imported Roblox playback.

During slug modelling, update `docs/slugs/blender-lessons.md` after meaningful problems or fixes, preserving owner feedback and relevant render references. Distinguish offline checks from subjective art approval and Studio evidence; accumulate lessons without rebuilding the pipeline unless the owner requests it.

For each creature task, start with `.agents/skills/slugshot-creature-production/SKILL.md` (procedure; `slugshot-blender-orchestrator` is its routing summary) and `docs/slugs/skill-routing.md`. Classify the actual problem, discover and read only the selected installed domain skill(s), and check their Blender version, MCP tool schema and dependencies against `docs/slugs/install-audit.md`. Use a checkpoint or variant before edits; render relevant views, run technical checks, record verified fixes in `docs/slugs/blender-lessons.md`, and seek owner art approval where needed. Keep the first creature baseline intact during tooling tests.

Use the relevant procedure skill in `.agents/skills` (Codex) or `.claude/skills` (Claude), keeping copies identical. Review third-party source/licences before execution or installation. Follow the current task's existing authorization: relevant verified free movement resources and pushing this experimental branch are approved. Ask before paid purchases, new external accounts, elevated permissions/security changes, destructive operations or publishing an experience. Never push restricted animation source or reusable IDs.

## Memory
Update the relevant note and `docs/status.md` after meaningful work. Label facts as Confirmed, Considering, Unresolved or Implemented/verified, and include evidence for verification. Capture architectural changes in an ADR; proposed gameplay ideas stay proposed until the user approves them. Add a dated entry to `docs/memory.md`. Do not store credentials or private account data in notes. See [development workflow](docs/development.md).

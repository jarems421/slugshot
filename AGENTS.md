# Slugshot agent instructions

Read [docs/index.md](docs/index.md), [vision](docs/vision.md), and [current status](docs/status.md) before changing scope. Follow [coding conventions](docs/conventions.md).

## Scope and authority
The foundation baseline is preserved. The current authorized milestone is the isolated movement research/prototype on `experiment/movement-sandbox`; see `docs/movement.md` and ADR 0002. Movement behaviors, controls, profiles and camera settings in that sandbox are experimental, not permanent design decisions. Combat, creatures, final environments, matchmaking, progression and exploration remain outside scope. Research examples are background, not requirements. Use original or appropriately licensed IP.

## Working procedure
Inspect existing files and Git status first; preserve unrelated changes. Foundation code stays in `src/client`, `src/server` and `src/shared`. Movement experiment code stays in `experiments/movement` and its dedicated Rojo projects; never sync it into the foundation place. Shared code cannot contain secrets. Keep tests out of normal builds and restricted assets/IDs under ignored private storage.

Run `python tools/verify.py` for foundation changes and `python tools/verify_movement.py` for the movement experiment (it also runs foundation checks). These do not execute Roblox. Use the relevant Studio checklist and record actual runtime evidence, warnings and subjective limits.

Use the relevant procedure skill in `.agents/skills` (Codex) or `.claude/skills` (Claude), keeping copies identical. Review third-party source/licences before execution or installation. Follow the current task's existing authorization: relevant verified free movement resources and pushing this experimental branch are approved. Ask before paid purchases, new external accounts, elevated permissions/security changes, destructive operations or publishing an experience. Never push restricted animation source or reusable IDs.

## Memory
Update the relevant note and `docs/status.md` after meaningful work. Label facts as Confirmed, Considering, Unresolved or Implemented/verified, and include evidence for verification. Capture architectural changes in an ADR; proposed gameplay ideas stay proposed until the user approves them. Add a dated entry to `docs/memory.md`. Do not store credentials or private account data in notes. See [development workflow](docs/development.md).

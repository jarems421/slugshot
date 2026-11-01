# Slugshot agent instructions

Read [docs/index.md](docs/index.md), [vision](docs/vision.md), and [current status](docs/status.md) before changing scope. Follow [coding conventions](docs/conventions.md).

## Scope and authority
The foundation baseline is preserved. The owner authorized isolated movement, Rocklock and temporary combat/first-person target-range experiments; see `docs/movement.md`, `docs/combat.md` and their ADRs. Movement behaviors, controls, profiles and camera settings remain experimental, not permanent design decisions. Separate lobby and creature workstreams stay in their own branches/worktrees. Final combat, creatures, environments, matchmaking, progression and exploration still require specific instructions. Research examples are background, not requirements. Use original or appropriately licensed IP.

## Working procedure
Inspect existing files and Git status first; preserve unrelated changes. Foundation code stays in `src/client`, `src/server` and `src/shared`. Movement experiment code stays in `experiments/movement` and its dedicated Rojo projects; never sync it into the foundation place. Temporary combat code stays in `experiments/combat` and its dedicated Rojo target range. Do not pull concurrent lobby/creature work into a combat checkpoint. Shared code cannot contain secrets. Keep tests out of normal builds and restricted assets/IDs under ignored private storage.

Run `python tools/verify.py` for foundation changes, `python tools/verify_movement.py` for movement work and `python tools/verify_combat.py` for combat/target-range work (each includes preceding checks). These do not execute Roblox. Use the relevant Studio checklist and record actual runtime evidence, warnings and subjective limits.

Use the relevant procedure skill in `.agents/skills` (Codex) or `.claude/skills` (Claude), keeping copies identical. Review third-party source/licences before execution or installation. Follow the current task's existing authorization: relevant verified free movement resources and the owner's 2026-11-01 request to checkpoint this chat's combat work on `main` are approved. Keep concurrent workstreams separate. Ask before paid purchases, new external accounts, elevated permissions/security changes, destructive operations or publishing an experience. Never push restricted animation source or reusable IDs.

## Memory
Update the relevant note and `docs/status.md` after meaningful work. Label facts as Confirmed, Considering, Unresolved or Implemented/verified, and include evidence for verification. Capture architectural changes in an ADR; proposed gameplay ideas stay proposed until the user approves them. Add a dated entry to `docs/memory.md`. Do not store credentials or private account data in notes. See [development workflow](docs/development.md).

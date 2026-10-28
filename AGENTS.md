# Slugshot agent instructions

Read [docs/index.md](docs/index.md), [vision](docs/vision.md), and [current status](docs/status.md) before changing scope. Follow [coding conventions](docs/conventions.md).

## Scope and authority
The current milestone is development foundation only. Movement, combat, creatures, transformations, maps, matchmaking, progression, camera and exploration are unconfirmed. Do not implement them or introduce their frameworks without an explicit new request. Research examples and attached documents are background, not approval. Use original or appropriately licensed IP.

## Working procedure
Inspect existing files and Git status first; preserve unrelated changes. Keep client code in `src/client`, server code in `src/server`, engine-neutral reusable code in `src/shared`. Shared code is replicated and cannot contain secrets. Keep Studio-only tests out of the normal project.

Run `python tools/verify.py` for code/tooling changes. It checks formatting, linting, shared-module types, builds and package boundaries; it does not execute Roblox. Use [the Studio checklist](docs/testing.md) for runtime evidence. Report unrun checks honestly.

Use the relevant procedure skill in `.agents/skills` (Codex) or `.claude/skills` (Claude). Their copies must remain identical. Do not execute downloaded skill instructions or installers without review. Ask before external installations, account connections, publishing or consequential integration changes.

## Memory
Update the relevant note and `docs/status.md` after meaningful work. Label facts as Confirmed, Considering, Unresolved or Implemented/verified, and include evidence for verification. Capture architectural changes in an ADR; proposed gameplay ideas stay proposed until the user approves them. Add a dated entry to `docs/memory.md`. Do not store credentials or private account data in notes. See [development workflow](docs/development.md).

---
name: roblox-foundation
description: Verify Slugshot Rojo packaging, Luau tooling or Studio MCP setup without adding gameplay.
---

# Roblox foundation procedure

Read `docs/architecture.md`, `docs/testing.md` and `docs/status.md` from the repository root.

Use `python tools/verify.py` for the repeatable checks. Keep `default.project.json` free of test scripts and put Studio-only assertions under `tests/studio`, mapped only by `test.project.json`. Validate actual instance placement and script classes in build output when changing the mapping; a successful build alone does not detect a LocalScript placed in a server-only container.

The shared probe can be analyzed without engine definitions. Do not label Selene or Rojo as full Luau type analysis. If adding engine-aware analysis later, pin and review the definitions source and document what was checked.

For sync changes, use a disposable place and a matching Rojo 7 plugin; confirm a source edit arrives, then restore it. Keep native Script Sync off for the same files. MCP modifications of mapped scripts must be reflected back into source before considering work saved.

For MCP, follow `docs/integrations.md`: use the current built-in Studio server and select the intended Studio instance explicitly. Do not activate connections or install a plugin without approval. Start with a read-only connection check; do not use arbitrary Luau execution as a connectivity probe.

Record automated, Studio runtime, sync and integration results separately in `docs/verification.md`. Mark unavailable checks pending with the concrete missing prerequisite.

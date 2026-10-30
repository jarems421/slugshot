# Development workflow

## Local setup

On the inspected machine, Studio, VS Code and relevant editor extensions already exist. Rokit 1.2.0 and all four pinned tools are cached. Project `rokit.toml` makes the existing Rokit shims resolve those versions; no new installation was needed.

From the repository root:

```powershell
python tools/verify.py
stylua src tests/studio
rojo serve default.project.json
```

Formatting modifies source; verification does not. Rojo binds to loopback port 34872. Stop it with Ctrl+C. Builds are in `build/`; regenerate them after changing source.

On another machine, obtain approval before external installations. Review [Rokit](https://github.com/rojo-rbx/rokit) and [Rojo installation](https://rojo.space/docs/v7/getting-started/installation/) first. After an approved Rokit installation, review `rokit.toml`, then run `rokit install`. Install a matching Rojo 7 Studio plugin separately; `rojo plugin install` modifies Studio's plugin directory and requires approval. Python is used only for lightweight stdlib verification; no pip dependencies are required.

VS Code recommendations and tasks are checked in. The Luau extension can provide Roblox-aware editor diagnostics. The foundation's engine-independent shared module is type-checked without Roblox definitions. The movement experiment is fully type-checked in strict mode by `tools/verify_movement.py` (also run by CI): luau-lsp analyzes every movement script against the Roblox API, using definitions pinned to the luau-lsp release in `rokit.toml` (downloaded with a SHA-256 check into ignored `.tools/luau/`) and a Rojo sourcemap. Type checks do not execute anything: actual behaviour must still be reviewed in Studio. `tools/r6pose/` previews original clip poses on the R6 rig (numpy and matplotlib; development only).

## Change loop

1. Read current status, inspect Git changes and find the approved task.
2. Update source and the smallest useful test/check within the approved task. Keep the foundation probe-only; authorized movement work belongs in its dedicated experiment project.
3. Run `python tools/verify.py`. For runtime changes, also use [the Studio checklist](testing.md).
4. Update relevant notes, status and dated memory with actual evidence and unverified items.
5. Review `git diff --check`, then stage and commit intentional files. Keep builds, secrets and personal configuration out of Git.

## Memory updates

Each knowledge statement belongs to one state: Confirmed, Considering, Unresolved, or Implemented/verified. Approval can move an idea to Confirmed; test evidence can move an implementation to verified. Neither happens automatically. Record who approved a change and link the user request/issue when available. Use [an ADR](templates/adr.md) for architecture changes; do not write a gameplay ADR as accepted without approval. Append concise outcomes and pending checks to [memory](memory.md); keep [status](status.md) current rather than appending stale claims forever.

Codex reads `.agents/skills/`; Claude reads `.claude/skills/`. Update canonical skill files first, copy to Claude, then run verification to check parity. See [official Codex skills](https://developers.openai.com/codex/skills/) and [Claude skills](https://code.claude.com/docs/en/skills).

## GitHub handoff

The owner approved publishing to the public repository https://github.com/jarems421/slugshot on 2026-10-28. `origin` points to that repository. Push reviewed commits to `main` and inspect the Actions result. CI installs the pinned tools on its temporary runner and runs the same verification command, then retains place artifacts. Workflow actions are pinned to reviewed commit SHAs. Update pins deliberately; do not use automatic remote installers during local setup.

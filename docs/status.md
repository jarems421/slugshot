# Current status

Updated: 2026-10-28
Milestone: development foundation only

## Confirmed

Roblox Studio / Luau / VS Code / Git-GitHub / Rojo foundation, client/server/shared separation, lightweight checks and Markdown memory. The owner approved the matching Rojo plugin, Studio MCP for Claude Code/Codex, integration/runtime/two-client verification and pushing results. No gameplay or final game design selected.

## Implemented/verified

Minimal source, isolated tests and pinned tooling pass formatting, linting, shared-module types, builds, sourcemap, packaging and skill checks. The public repo is [jarems421/slugshot](https://github.com/jarems421/slugshot); hosted [Linux CI for the integration setup](https://github.com/jarems421/slugshot/actions/runs/40724542365) passed.

Rojo 7.7.1's matching plugin is installed. A filesystem edit synchronized into Studio; original source was restored and matched exactly. Studio 0.745.0.7451137's built-in MCP is enabled. Claude's native health check reports Connected; native Codex discovered tools and made live calls. Host config is local/private.

Single-client smoke and isolated two-client tests passed. The server saw two distinct players; each client logged once, loaded the shared probe and could not see the server bootstrap. The normal place has no test folder. Multiplayer ended and the parent returned to Edit mode.

[Verification](verification.md) and [captured evidence](evidence/2026-10-28-studio.json) detail checks and built-in/avatar warnings. No gameplay, maps, creatures, custom remotes or game-design decisions were added.

## Considering

Gameplay directions in [vision](vision.md) and tools in [research](research/tooling.md) remain ideas/research, not implementation requirements.

## Unresolved / outside this milestone

Blender, full engine-aware CLI types, interactive editor diagnostics, new-session skill discovery and later gameplay/device/network tests are unverified. The bundled skill validator lacks PyYAML; project metadata/parity checks pass. Existing IDE chats may need a new session to expose the new MCP tools.

No requested integration/runtime test remains pending. Next work should be an explicitly chosen design or implementation task.

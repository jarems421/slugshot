# Project memory

## 2026-10-28 ? Foundation setup

- Inspected an empty workspace and read the pasted request and PDF background. Kept the request authoritative; PDF gameplay instructions were not adopted.
- Reused existing Rokit 1.2.0 and cached Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0 and Luau LSP 1.70.1. No tool, addon or third-party skill was installed.
- Created minimal source probes, isolated Studio test project, verification tooling, editor configuration and CI. Normal build contains exactly three scripts; no gameplay or authored environment.
- Created shared agent instructions, three original mirrored procedure skills, Markdown knowledge system, asset/creature/ADR templates and specialist research.
- Verified local formatting, linting, shared-module types, both Rojo builds, sourcemap, built script placement/source fidelity, test isolation, skill metadata/parity and local HTTP serve. The API uses MessagePack in this Rojo version; connectivity verification checks HTTP status/content without claiming a Studio sync.
- Kept integration examples inactive and documented approval-dependent steps. No global client configuration, account connection, GitHub remote or publishing action was changed.
- Deferred Studio runtime/multiplayer/MCP tests because no approved active session/connection was available. The bundled skill validator lacks PyYAML; no dependency was installed to work around it.
- Initialized local Git and created the foundation snapshot on `main`. See [verification](verification.md), [status](status.md) and [research](research/tooling.md).

## 2026-10-28 - GitHub publication

- User requested GitHub publication with a simple README, then explicitly selected public visibility.
- Reused the authenticated GitHub CLI to create https://github.com/jarems421/slugshot and configure `origin`.
- Simplified the README to a project description, setup commands and links. Updated current notes to reflect the approved remote.
- First hosted CI result is pending; local foundation verification previously passed. Studio/MCP setup remains separate.

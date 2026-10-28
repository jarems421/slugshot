# Foundation verification report

Date: 2026-10-28 (Europe/London)
Workspace: local Windows repository, initially empty
Scope: development infrastructure only

## Reused, installed and created

Reused existing Git 2.55.0, Python 3.13, Rokit 1.2.0 and cached Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0 and Luau LSP 1.70.1. Existing Studio, VS Code and relevant editor extensions were detected. Claude Code and Codex executables were detected, but no authentication flow was started. Blender was not on PATH.

No external tool, package manager dependency, gameplay library, Studio plugin, Blender addon or third-party skill was installed. An upstream Rokit Linux archive was fetched into memory to compute the CI bootstrap checksum; it was not extracted or executed on this machine.

Created client/server/shared setup probes, two Rojo manifests, test source, local verification tool, formatting/lint configuration, GitHub Actions, editor recommendations/tasks, Git conventions, agent instructions, three original project skills with Claude copies, inactive MCP templates and the Markdown knowledge base. Initialized local Git with a foundation snapshot on `main`. No remote account/repository, map, creature, combat, movement, remotes, matchmaking or progression implementation was created.

## Passed locally

| Check | Command / evidence | Result |
| --- | --- | --- |
| Tool resolution | `rojo --version`, `stylua --version`, `selene --version`, `luau-lsp --version` from project root | Exact manifest versions above resolve using existing cache |
| Full repeatable verification | `python tools/verify.py` | Passed |
| Formatting / parse | `stylua --check src tests/studio` | Passed |
| Roblox-aware lint | `selene src tests/studio` | 0 errors, 0 warnings, 0 parse errors |
| Shared module types | `luau-lsp analyze --platform=standard src/shared/Foundation.luau` | Passed; reports no engine definitions loaded, as expected for this module |
| Normal build | `rojo build default.project.json --output build/Slugshot.rbxlx` | Passed |
| Isolated test build | `rojo build test.project.json --output build/SlugshotTests.rbxlx` | Passed |
| Sourcemap | `rojo sourcemap default.project.json --output build/sourcemap.json` | Passed |
| Package semantics | `tools/verify.py` parses both XML outputs | Correct script classes/containers and exact source text; normal has only three probes, test build includes assertion script |
| Skills | Repository metadata checks and byte comparison | Three canonical skills, valid restricted plain-scalar metadata, matching Claude copies |
| Repository consistency | Local Markdown link audit, JSON/TOML parsing, `git diff --cached --check` | 51 local links resolve; configuration parses; no whitespace errors |
| Local serve | Temporary existing Rojo executable, `default.project.json`, HTTP requests to root and `/api/rojo` | HTTP 200; landing page identifies Rojo; API `application/msgpack`, 211 bytes; stopped afterward and port confirmed closed |

Build outputs are intentionally ignored and reproducible. A local HTTP server response proves CLI serving, not Studio plugin synchronization.

## Not verified / intentionally pending

- Studio execution of the client/server probes and Luau assertion script. Source is parsed/linted and packaged but has not run in the engine.
- Multi-client behavior, GUI Rojo plugin sync and editor interactive diagnostics. No running Studio process was observed; no plugin file appeared in the inspected local Plugins directory. Cloud-installed inventory was not inspected.
- Studio MCP connection and tools. `mcp.bat` and Studio installation exist; examples are inactive. Approval and an intended open Studio session are needed.
- Claude/Codex skill auto-discovery in a new session and behavioral evaluations. Files/metadata match; actual discovery is not claimed.
- Bundled `skill-creator/scripts/quick_validate.py` was attempted for all three skills and failed at import because PyYAML is absent. Dependency-free project checks cover the two metadata fields and parity; they are not a general YAML validator.
- Full engine-aware CLI type analysis. Only the engine-neutral shared module is analyzed; startup and test scripts need Studio diagnostics/runtime or reviewed engine definitions.

- Blender execution, addon/export roundtrip, asset service accounts, uploads and publishing. None is required for the present foundation.

Follow [testing](testing.md) and [integrations](integrations.md) to close pending items. Do not mark them passed until evidence exists.

## GitHub publication follow-up

The owner approved public visibility and publication to [jarems421/slugshot](https://github.com/jarems421/slugshot). Source and the simplified README were pushed to `main`, with `origin/main` configured as the upstream.

The [first hosted Foundation run](https://github.com/jarems421/slugshot/actions/runs/40719697932) passed on Linux for commit `3cfbd63`: tool installation, formatting, linting, shared-module analysis, both builds, package checks and artifact upload. Studio runtime/MCP checks remain pending.

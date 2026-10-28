# Foundation verification report

Verified: 2026-10-28 (Europe/London)
Scope: development infrastructure only; no gameplay implemented
Source under test: `4593d9d`, with a temporary sync comment added and restored byte-for-byte

All requested integration/runtime tests completed. [Sanitized machine-readable evidence](evidence/2026-10-28-studio.json) records observed results. Raw logs, generated schemas and scratch automation remain in ignored `build/`.

## Installed and configured

- Installed Studio's matching plugin with cached Rojo 7.7.1 using `rojo plugin install`. RojoManagedPlugin.rbxm: 504236 bytes; SHA-256 `9412c5ce010e18342a4470a48f516772127649216aa3fbf55b8fe1369ca5db7f`.
- Studio automatically updated at launch from 0.743.0.7431133 to 0.745.0.7451137. Its built-in MCP setting was already enabled; live calls verified it remained enabled.
- Configured Claude Code 2.1.302 with a private per-project entry in `~/.claude.json`. Native health checks repeatedly reported Connected.
- Configured Codex CLI 0.164.0-alpha.11.1 in project `.codex/config.toml` and trusted only this workspace. Its native app-server discovered 31 tools, listed instances and read the normal place's shared ModuleScript. No model turn started.
- Reused Git 2.55.0, Python 3.13, Rokit 1.2.0, StyLua 2.6.0, Selene 0.32.0 and Luau LSP 1.70.1. No unrelated plugin, Python package, Blender addon or gameplay library was installed.

Host-specific configuration and credentials are not committed. Portable examples and reproduction instructions are tracked. See [integrations](integrations.md).

## Runtime and integration results

| Check | Observed evidence | Result |
| --- | --- | --- |
| Claude MCP | Native CLI health check, private local scope | Connected |
| Codex MCP | Native app-server inventory and live list/read calls | Passed |
| Single-client smoke | Server/client probes once each; shared-module contract PASS | Passed |
| Single-client isolation | Client-context expected message, frozen module, server bootstrap absent | Passed |
| Two-client server | Native StudioTestService test; server observed Player1/Player2; server probe and contract once | Passed |
| Player1 | Independently checked shared probe, both players visible, server bootstrap absent, client log once | Passed |
| Player2 | Same assertions checked in the other client's actual Client datamodel | Passed |
| Multiplayer teardown | EndTest returned success; parent returned to Edit mode | Passed |
| Real Rojo sync | Filesystem comment appeared in normal Studio ModuleScript | Passed |
| Source restoration | Comment removed; subsequent Studio read exactly matched original file | Passed |
| Normal project isolation | Actual Studio assertion: no FoundationTests folder | Passed |

Tests used generated local places without uploading or publishing a Roblox experience. No inspection commands or scene changes were adopted as gameplay/design.

All simulated sessions ended. Disposable test windows were closed without saving their incidental Studio changes. Temporary Rojo/MCP verification processes were stopped. The normal foundation place remains open in Edit mode; run `rojo serve default.project.json` to reconnect for development.

## Automated checks

`python tools/verify.py` passes: StyLua, Selene (0 errors/warnings/parse errors), shared-module analysis, both builds, sourcemap, built script placement/classes/source fidelity, test isolation and skill checks. This is not full engine-aware type analysis.

Local JSON/TOML configurations parse, documentation links resolve, and `git diff --check` passes. The initial hosted [Foundation run](https://github.com/jarems421/slugshot/actions/runs/40719697932) passed on Linux. Follow-up hosted results apply to the pushed setup revision; CI does not perform Studio runtime checks.

## Studio warnings and remaining limits

Project scripts/assertions passed without project-script errors. The Studio session was not completely warning-free:

- Runtime sessions reported `rbxassetid://203785492` with "Asset type does not match requested type". The repo contains no reference to this ID or authored assets; each simulated client reported it. No avatar/asset/design change was made to suppress it.
- The normal editor reported a `debug.profileEnd()` / "No active profile annotation" stack inside Studio's built-in MaterialManager/React packages. No project script appears in that stack. No built-in/unrelated plugin was modified.
- Opening a generated place triggered Studio's legacy default-lighting migration notice. It was dismissed in the disposable place; no authored lighting/map decision was committed.

No requested Rojo/MCP/runtime/two-client test remains uncompleted. Outside-task checks remain unverified: full engine-aware CLI types, interactive VS Code diagnostics, a model-driven tool call from an interactive Claude chat, new-session skill discovery, device/stress/network-impairment tests and Blender exports. The bundled skill validator still lacks PyYAML; dependency-free project metadata/parity checks pass instead. Existing IDE chats may need a reload/new session to expose new tools; native Codex connectivity is verified.

See [testing](testing.md) to reproduce. Source was restored before the final automated build and commit.

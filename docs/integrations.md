# Integration setup and status

Verified 2026-10-28. The owner approved the compatible Rojo plugin, Studio MCP for Claude Code and Codex, runtime/two-client tests, and committing/pushing results. No gameplay or unrelated plugins were added.

| Integration | Installed/configured | Verification |
| --- | --- | --- |
| Rojo | CLI and matching Studio plugin 7.7.1 | Filesystem edit and restoration observed in Studio; normal place has no tests |
| Studio | Auto-updated at launch to 0.745.0.7451137; built-in MCP enabled | Single-client smoke and isolated two-client test passed |
| Claude Code | Existing 2.1.302; private project-local MCP entry | Native health check reports Connected |
| Codex | Existing CLI 0.164.0-alpha.11.1; project config active; this workspace trusted | Native app-server discovered 31 tools and made live list/read calls without a model turn |
| VS Code | Existing recommended extensions | Interactive editor diagnostics not exercised |
| GitHub | Public [jarems421/slugshot](https://github.com/jarems421/slugshot) | Initial hosted CI passed; see [verification](verification.md) |
| Blender | No executable on PATH or addon installed | Deferred; not required for the foundation |

[Sanitized evidence](evidence/2026-10-28-studio.json) records versions, assertions, source restoration and plugin checksum. Host configuration, auth material, raw logs and scratch automation remain untracked.

## Rojo setup and sync

The approved `rojo plugin install` installed the plugin bundled with the pinned CLI into Studio's local Plugins folder. Restart Studio after installation if necessary. Run `python tools/verify.py`, open `build/Slugshot.rbxlx`, then run `rojo serve default.project.json`. Connect the plugin to `127.0.0.1:34872` using its notification or panel. Review initial changes before accepting them; use a disposable foundation place.

Filesystem source is authoritative. To verify sync, append a unique temporary comment to the shared source, read the actual Studio ModuleScript through MCP, restore the original file and wait for another read to match exactly. This roundtrip passed. Keep native Script Sync off for the same tree. MCP edits to mapped scripts are not automatically saved to Git.

## Built-in Studio MCP

Use the [official built-in server](https://create.roblox.com/docs/studio/mcp), not the older standalone Agent Plugin. In Studio: Assistant > ... > Manage MCP Servers > Enable Studio as MCP server. It was already enabled and was verified live. The existing `%LOCALAPPDATA%\Roblox\mcp.bat` launcher updated its version path with Studio.

Both clients use `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`. The [Claude JSON](../tools/integrations/claude.mcp.example.json) and [Codex TOML](../tools/integrations/codex.config.example.toml) remain portable references. Activation is approved and complete on this machine:

- Claude Code: `claude mcp add --scope local Roblox_Studio -- cmd.exe /c '%LOCALAPPDATA%\Roblox\mcp.bat'` was run in the repository. The private per-project entry lives in `~/.claude.json`. Native `claude mcp get Roblox_Studio` checks report Connected. A duplicate project MCP entry was removed; unrelated entries were preserved.
- Codex: the table was added to ignored project `.codex/config.toml`; only this repository was added as trusted in the existing user config. `codex mcp get` confirms configuration. Its native app-server loaded the project context, discovered tools and made live calls. No model turn or additional coding agent was started.

See [official OpenAI MCP configuration](https://developers.openai.com/codex/mcp/) and [Claude MCP](https://code.claude.com/docs/en/mcp). An existing IDE chat may need a new session/reload to expose new tools; native connectivity is verified.

Use `list_roblox_studios` and explicitly select the intended instance ID before further calls. Multiple test windows have different IDs. Keep a verification connection alive: a newly started proxy can briefly list no instances while Studio reconnects. Require a live tool call, not merely cached inventory, as evidence.

## Runtime and rollback

The test place passed its contract assertion and both startup probes. StudioTestService launched a separate server and two clients. The server saw two players; each client logged once and passed shared-module/server-source isolation assertions. EndTest returned success and the parent returned to Edit mode. See [testing](testing.md) and [verification](verification.md).

To roll back only these integrations: `rojo plugin uninstall`, `claude mcp remove Roblox_Studio -s local`, and remove the named server table from the project Codex config. Studio's toggle controls its MCP server. Preserve other servers and trust entries. Pre-edit backups were retained in ignored `build/integration-backups/` where applicable.

GitHub publication and these integrations are approved. Blender, extra plugins, gameplay dependencies, asset uploads and publishing a Roblox experience remain outside scope. Repeating the authorized foundation checks does not need fresh approval.

# Integration setup and status

Reviewed 2026-10-28. No account connection, MCP activation or external installation was performed.

| Integration | Observed locally | Verification / next step |
| --- | --- | --- |
| Rojo CLI | 7.7.1 cached and resolves from project manifest | Build/sourcemap verified; local serve checked separately in verification report |
| Studio | Executable and `mcp.bat` exist | No running Studio session observed; runtime tests pending |
| Rojo Studio plugin | No plugin found in inspected local Plugins folder | Installation approval and GUI sync test needed; cloud-installed plugin inventory not verified |
| VS Code | Installed; Rojo, Luau LSP, StyLua, Selene and Actions extensions listed | Recommendations/tasks created; interactive editor diagnostics not exercised |
| Claude Code | Existing executable | Project instructions/skills and inactive MCP example prepared; authentication and MCP calls not tested |
| Codex | Existing VS Code-bundled executable | `.agents/skills` prepared; inactive project MCP template; new-session discovery not tested |
| Git/GitHub | Git 2.55.0 and `gh` installed; GitHub connector tools exposed in this chat | Public `jarems421/slugshot` created with owner approval; first hosted Linux CI run passed |
| Blender | No `blender` executable on PATH | Not proof it is absent elsewhere; installation/optional MCP deferred |

## Official Studio MCP (approval-dependent)

Current [Roblox documentation](https://create.roblox.com/docs/studio/mcp) recommends the built-in server. Avoid the obsolete standalone Studio Agent Plugin route mentioned in the PDF.

After approval, open the intended foundation place, then Assistant > ... > Manage MCP Servers > Enable Studio as MCP server. Quick connect supports Codex CLI and Claude Code. Prefer Studio's generated settings over guessing version-specific paths.

Inactive reviewed alternatives are in [Claude JSON](../tools/integrations/claude.mcp.example.json) and [Codex TOML](../tools/integrations/codex.config.example.toml). After approval, merge the Claude entry into a project `.mcp.json` or the Codex table into `.codex/config.toml`, preserving existing entries. These active local files are ignored. Windows uses `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`; the batch file already exists on this machine and resolves to the installed StudioMCP binary. No global configuration was edited.

See [Codex MCP configuration](https://developers.openai.com/codex/mcp/) and [Claude MCP](https://code.claude.com/docs/en/mcp). Codex project configuration also requires trusting the project. Restart the client after changes if needed.

Verify the green connected-client indicator in Studio. Call the exposed read-only Studio-list tool (currently documented as `list_roblox_studios`), select the intended instance ID, and inspect the tree or read the probe script. Tool names can vary by installed version: inspect the actual exposed schema. Record instance/place, client version and read result. A configuration file or existing executable is not proof of a successful MCP connection. Do not execute generated Luau, import models or publish as a connectivity test.

## GitHub

Prefer the existing GitHub connector or `gh` when authenticated rather than installing another MCP server. The owner approved public publication on 2026-10-28. The existing authenticated GitHub CLI created https://github.com/jarems421/slugshot and configured `origin`. No new account connection or MCP installation was needed. Inspect hosted CI after each push. Do not publish private research by default. The official [GitHub MCP server](https://github.com/github/github-mcp-server) is an optional alternative, not a current dependency.

## Blender

Native Blender editing/export or headless CLI may be enough. [MCP for Blender](https://github.com/ahujasid/mcp-for-blender), formerly blender-mcp, is third-party and MIT-licensed, not an official Blender Foundation server. It exposes code execution and can integrate asset services. No addon, Python dependency, cloud service or MCP configuration is installed. Before any future approval request, review a specific pinned version, transport, telemetry, optional services, license and a rollback/uninstall plan. Avoid piping remote installers directly into PowerShell.

## Approval queue

The user's pasted request explicitly says: "Request approval before account connections, external installations or other consequential changes." This is why external setup remains pending. Prepared files are reviewable locally; activation is a separate step.

1. Approve a matching Rojo Studio plugin installation if missing and run Studio checks.
2. Approve which Studio MCP clients may connect; activate only those.
3. Completed approval: public `jarems421/slugshot`; inspect hosted CI after publication.

Blender and gameplay packages are deferred until needed; they are not prerequisites for this foundation.

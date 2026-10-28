# Slugshot

Roblox development foundation. No gameplay systems or assets have been implemented.

## Quick start

Requirements: Roblox Studio, VS Code, Git, Python 3.11+ and the tool versions in [rokit.toml](rokit.toml). See [setup](docs/development.md) before installing or connecting anything.

```powershell
python tools/verify.py
rojo serve default.project.json
```

Open `build/Slugshot.rbxlx` in Studio, then connect a compatible Rojo 7 plugin to `127.0.0.1:34872` for live sync. The plugin needs separate installation approval if absent. Play should log `[Slugshot] server foundation ready` and `[Slugshot] client foundation ready`. The empty place deliberately has no map or spawn; default avatar behavior is Roblox engine behavior.

For the isolated smoke test, open `build/SlugshotTests.rbxlx` and follow [testing](docs/testing.md). Do not connect the normal Rojo project while inspecting the test build.

## Repository

| Path | Purpose |
| --- | --- |
| `src/client` | One client bootstrap |
| `src/server` | One server bootstrap |
| `src/shared` | Replicated setup probe |
| `assets` | Future source/export conventions; no assets |
| `tests/studio` | Isolated Luau smoke test |
| `tools` | Local and CI verification |
| `docs` | Obsidian-compatible project memory and research |
| `.agents/skills`, `.claude/skills` | Reviewed project procedures |
| `.github` | CI and review template |

Start with [the knowledge index](docs/index.md) and [verification report](docs/verification.md). Local Git is initialized; no remote has been created or connected. The project has no open-source license grant: choosing a project license remains an owner decision.

# Slugshot

A Roblox multiplayer creature-combat project, currently at the development foundation stage.

Built with Luau, Roblox Studio and Rojo. Includes client/server/shared code, development checks, GitHub Actions and project documentation. Gameplay is still to be designed and implemented.

## Getting started

Install the tools listed in [rokit.toml](rokit.toml) using Rokit, plus Python 3.11+ and Roblox Studio.

```sh
rokit install
python tools/verify.py
rojo serve default.project.json
```

Open `build/Slugshot.rbxlx` in Studio. For live sync, connect the Rojo 7 plugin to `127.0.0.1:34872`.

See [development setup](docs/development.md), [testing](docs/testing.md) and [project notes](docs/index.md).

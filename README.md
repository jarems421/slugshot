# Slugshot

A Roblox multiplayer creature-combat project with a verified development foundation and an isolated experimental movement lab.

Built with Luau, Roblox Studio and Rojo. Final gameplay and movement decisions remain open.

## Getting started

Install the tools listed in [rokit.toml](rokit.toml) using Rokit, plus Python 3.11+ and Roblox Studio.

```sh
rokit install
python tools/verify.py
rojo serve default.project.json
```

Open `build/Slugshot.rbxlx` in Studio. For live sync, connect the Rojo 7 plugin to `127.0.0.1:34872`.

See [development setup](docs/development.md), [testing](docs/testing.md) and [project notes](docs/index.md).

## Movement experiment

Run `python tools/verify_movement.py`, then open `build/SlugshotMovementLab.rbxlx` and press Play. Use WASD, double-tap W (sprint), Shift (slide), Ctrl (shift lock), C (crouch), Space (jump; again in the air for a double-jump flip; into ledges to mantle or vault; onto walls to wall run; beside walls to wall jump), P (compare profiles) and R (reset); the in-game HUD lists them. `python tools/build_movement_playtest.py` also builds the previous v1 and v2 labs for comparison. See [controls and playtest notes](docs/movement.md), [research](docs/research/movement.md) and [results](docs/movement-verification.md). Restricted third-party animation files are excluded from this public repository.

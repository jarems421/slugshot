# Verification workflow

## Automated

Run `python tools/verify.py` from the root (Python 3.11+). It fails on tool errors and checks:

- StyLua formatting and Luau parsing across source and Studio tests.
- Selene Roblox-aware linting across the same files.
- Luau LSP type analysis of the engine-independent shared module.
- Rojo normal/test builds and normal sourcemap generation.
- Actual built instance names, script classes and source contents.
- Exactly three setup scripts in the normal build; test script present in the test build.
- Identical Codex and Claude procedure skills.

No external test framework is installed. These checks test packaging and validity; they do not run the Roblox engine or prove replication behavior.

## Studio smoke test (pending)

1. Open regenerated `build/SlugshotTests.rbxlx` in Studio. Keep Rojo disconnected to preserve the test-only tree.
2. Inspect Explorer: shared module in ReplicatedStorage, server bootstrap and FoundationTests in ServerScriptService, client bootstrap in StarterPlayerScripts.
3. Play and review both server and client Output. Expect `[Slugshot] server foundation ready`, `[Slugshot] client foundation ready`, and `[Slugshot tests] PASS: shared module contract` with no script errors.
4. Stop; open `build/Slugshot.rbxlx`. Confirm the test folder is absent. Optionally connect approved Rojo 7 plugin to `127.0.0.1:34872`, modify a probe message, confirm sync, then restore source.
5. Record Studio version, project/commit, modes, logs and result in [verification](verification.md). A falling avatar is expected in an empty place; do not add a map to fix it.

## Multiplayer foundation check (pending)

Use Studio's Server & Clients mode with two clients. Confirm each prints its client probe once and the server prints its own probe without require errors. Verify the server script is absent from client-visible replicated containers. No custom networking or movement is being tested. Stop all sessions afterward.

Future network features need latency/jitter/loss and client join/leave tests when authorized. Use [official testing modes](https://create.roblox.com/docs/studio/testing-modes) and [Network Simulator](https://create.roblox.com/docs/studio/network-simulator); check current Studio availability before depending on beta controls.

## CI

[The workflow](../.github/workflows/ci.yml) uses read-only repository permissions and no Roblox credentials. It builds and packages but never publishes. Its first hosted run is pending remote setup. Local Windows success does not establish Linux runner success.

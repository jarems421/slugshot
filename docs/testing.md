# Verification workflow

The single-client smoke, two-client check and real Rojo sync passed on Studio 0.745.0.7451137 on 2026-10-28. See [verification](verification.md) and [captured evidence](evidence/2026-10-28-studio.json). These are foundation checks only.

## Automated checks

Run `python tools/verify.py` from the root (Python 3.11+). It checks formatting/parsing, Roblox-aware linting, engine-independent shared-module types, both builds, sourcemap, built script placement/source fidelity, test isolation and skill metadata/parity. It does not run Roblox. No external test framework is installed.

## Single-client Studio smoke

1. Regenerate builds and open `build/SlugshotTests.rbxlx`. Keep Rojo disconnected to preserve the test-only tree.
2. Confirm the shared ModuleScript, server Script, client LocalScript and server-only FoundationTests folder occupy their expected containers.
3. Start Play through Studio or `start_stop_play`. Require exactly one server probe, one client probe and `[Slugshot tests] PASS: shared module contract` in Output.
4. In the actual Client datamodel, assert the shared module returns the expected client message and is frozen, and `ServerScriptService:FindFirstChild("Server") == nil`. A server-side require does not prove client execution.
5. Stop and confirm Edit mode. Record version, source revision, logs and engine/plugin warnings separately from project failures.

A falling avatar is expected in the empty place. Do not add a map or change avatar/game design to make the setup check look different.

## Two-client test

Use Studio's Server & Clients mode with two players, or the verified built-in API through `execute_luau` in Edit mode. The API is plugin-secured; invoke it through the authorized Studio integration, not game code. Launch without blocking the MCP call until the test ends:

```lua
local service = game:GetService("StudioTestService")
task.spawn(function()
    local result = service:ExecuteMultiplayerTestAsync(2, "SlugshotFoundation")
    print("[Slugshot integration] multiplayer test returned", result)
end)
```

This is an inspection command, not a project script. Refresh the Studio instance list and identify the launched server and clients by state; do not use guessed instance IDs.

- In the server datamodel, require the probe and assert `#Players:GetPlayers() == 2`. Confirm the server probe and test-contract log each occur once.
- In each client's actual Client datamodel, record LocalPlayer.Name, assert two players are visible, require the shared module, check its message/immutability and assert the server bootstrap is not visible. Require exactly one client bootstrap line in each client's Output.
- Confirm the clients represent distinct Player1/Player2 sessions.
- End from the test server with `StudioTestService:EndTest("Slugshot two-client foundation checks passed")`. Confirm the result reaches the parent and it returns to Edit mode. Stop all simulated sessions afterward.

No custom remotes, controller, combat or authority framework is needed. Future authorized networking work should add device, latency/jitter/loss and join/leave scenarios; these are not claimed here. References: [testing modes](https://create.roblox.com/docs/studio/testing-modes), [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService), [Network Simulator](https://create.roblox.com/docs/studio/network-simulator).

## Real Rojo synchronization

Open `build/Slugshot.rbxlx` separately. Start `rojo serve default.project.json` and connect the plugin to `127.0.0.1:34872`. Verify the normal place has no FoundationTests folder. Append a unique temporary comment to the shared source, wait for synchronization, and read the Studio ModuleScript through MCP to confirm arrival. Restore the original bytes and wait for a second read to match exactly. Keep the comment out of Git. A local HTTP response/build is insufficient evidence.

## MCP clients and CI

`claude mcp get Roblox_Studio` must report Connected, not Pending approval. Codex `mcp get` confirms configuration only: the live test also used its native app-server to discover tools and call list/read tools. No model turn was requested. See [integration setup](integrations.md) for scopes and reconnection behavior.

[CI](../.github/workflows/ci.yml) runs automated Linux checks and packages artifacts; it uses no Roblox credentials and never publishes. Studio runtime tests are local. Record built-in warnings honestly even when project assertions pass; do not relabel an entire session as error-free.

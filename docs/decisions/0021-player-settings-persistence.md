# ADR 0021: Player settings persistence

**Confirmed:** owner requested saving every setting between sessions on 2026-11-02, safe handling of missing/old/invalid saves, and recording actual Roblox tests. Owner subsequently allowed skipping the real rejoin test if Studio MCP could not connect. `docs/MVP-UI.md` does not exist; the governing UI note is [PvP UI](../pvp-ui.md).

## Decision

**Implemented:** keep preferences separate from gameplay state in a server-owned `SlugshotSettings` DataStore keyed by player UserId. Studio uses `SlugshotSettings_Studio` to avoid touching live preferences. Both combat projects map the service; foundation builds do not.

`Combat.SettingsSchema` defines version 1, the twelve menu preferences and a whitelist of keyboard/mouse inputs. Shared action definitions keep input defaults and save validation aligned. Custom colours serialize as six hex digits. Both slots serialize explicitly, with `false` meaning deliberately unbound. Unknown fields are discarded, invalid fields use defaults, and duplicate inputs have one deterministic owner. Unversioned data is migrated; data with a newer version is left untouched and changes remain local.

The client continues using player attributes and the existing input/camera APIs. It loads asynchronously, preserving preferences changed while loading, and sends a complete sanitized snapshot at most every 0.75 seconds. No menus, combat flags, debug tuning or current input states are persisted. Reset uses the same save path as edits. The menu displays loading/saving/saved/failure state.

The server rate-limits requests, bounds encoded payloads, validates every value independently, batches pending saves every five seconds, and refreshes unchanged sessions every thirty seconds. `UpdateAsync` acquires a 120-second session lease with a unique token. A concurrent rejoin waits for release/expiry; an old server cannot overwrite a newer session. Failed loads retry without writing defaults over existing data. Failed writes remain pending. Leave and shutdown serialize final writes/release, with up to three attempts and a 25-second shutdown wait.

## Evidence and limits

**Implemented/verified offline:** foundation/movement/combat formatting, lint, strict types and builds. **Implemented/verified in Roblox Studio:** real schema/store regressions with JSON-roundtripping injected storage; real client/server loading, early edits, keybinds, colour, flip camera, save acknowledgement, reset and production PlayerRemoving flush/release. See [settings evidence](../evidence/2026-11-02-settings-persistence.json).

**Unresolved:** a real cloud-backed leave/rejoin, full BindToClose runtime coverage, multi-client/latency/device coverage and crash recovery. Studio MCP returned an empty instance list; isolated Studio Play tests used the existing window/log automation. These tests do not establish Roblox cloud persistence. Publishing or enabling Studio API access was not performed. Sudden process loss may lose changes since the last successful save; disconnecting before the client sends its pending snapshot can lose that final edit. Wait for “Settings saved” before leaving during acceptance testing.

Primary guidance: [Roblox Data stores](https://create.roblox.com/docs/cloud-services/data-stores), [player data and session locking](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing), [best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices).

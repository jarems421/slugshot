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


## 2026-11-03 repair and explicit cloud gate

**Confirmed:** owner reports settings-load failure and corrupted close glyph, and requires real persistence plus final shooting/hopping/notice verification before main delivery.

**Implemented/verified locally:** encode close/checkmark through `utf8.char`, retain unavailable-storage status while editing, and show an explicit session-only explanation for unpublished Studio previews. `Store.connect` does not attempt cloud access when Studio has no universe; API-access/publishing errors in Studio receive the same transparent state. No defaults are saved over a failed load. This explains the preview limitation; it does not add local disk persistence or establish cloud saving.

Reset the open status on every `UpdateAsync` transform retry and verify the returned lease token. A conflicting retry must not inherit the first attempt's Loaded result and admit a foreign lease. Added native account isolation/conflict regression and unavailable/recovery UI coverage. Fixed an old test input that assigned WheelUp to two actions while expecting both to persist.

**Implemented/verified:** real client/server schema/store/UI tests pass all preferences, cleared bindings, early edits, recovery, save acknowledgement and production leave flush with injected JSON storage. [Current evidence](../evidence/2026-11-03-settings-and-final-review.json).

**Prepared, not performed:** `python tools/build_settings_cloud_check.py` builds a small production-storage acceptance place without private assets or animation IDs. First visit confirms a cloud save; after stopping/leaving normally, the next visit checks restoration. It is intentionally separate from live preferences in Studio. Roblox requires a published experience and Studio API access; [official documentation](https://create.roblox.com/docs/cloud-services/data-stores). Publishing/enabling access requires owner approval under AGENTS.md. Real cloud rejoin remains unresolved until that approval and test.


## 2026-11-03 real cloud acceptance - gate satisfied

**Confirmed:** owner located the error in the local Studio preview and explicitly approved publishing only the prepared private settings test and enabling Studio API access there.

**Implemented/verified with Roblox cloud storage:** published `Slugshot Settings Storage Test` with owner-only audience, Team Create/data sharing off; enabled only Studio API access. HTTP/third-party sales/teleports stay off. The test contains no private game models or animation IDs. Its actual universe/place identity stays ignored under `private-assets/settings-cloud`. No main-game publication.

The real production Store/SettingsPersistence/SettingsSync saved all twelve settings and both binding slots through `DataStoreService`. After a normal Stop/flush/release and a fresh server/client Play session, every target preference and action binding matched, including colour, false/unbound and a custom second slot. The cloud check passed, superseding the unresolved cloud gate above. [Sanitized evidence](../evidence/2026-11-03-settings-cloud.json).

The first minimal test exposed a fixture parent-layout defect and client replication ordering. The cloud builder now asserts the production Folder/Script/module sibling contract; schema/keybind/sync requires wait for children. Cloud fixture formatting/lint/strict analysis and full combat verification pass.

**Limits:** one owner account in native Studio using real cloud storage; no second device/account login or standalone-player acceptance. Studio deliberately uses `SlugshotSettings_Studio`, with live runtime using `SlugshotSettings`. Unpublished local files still cannot retain preferences through Roblox storage; use a published private development experience for that acceptance flow.

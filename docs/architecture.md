# Architecture

Status: Confirmed foundation layout; gameplay architecture remains unresolved.

```text
src/shared  -> ReplicatedStorage.Shared
src/server  -> ServerScriptService.Server (Script)
src/client  -> StarterPlayer.StarterPlayerScripts.Client (LocalScript)
```

The two bootstraps require `Shared.Foundation` and print a setup message. That module is immutable and engine-independent so basic type checks need no downloaded Roblox definitions. No remotes, controllers, service framework, persistence layer, package manager or gameplay abstractions are present.

`default.project.json` defines the normal place. `test.project.json` adds `ServerScriptService.FoundationTests` for the Studio smoke test. Build outputs and sourcemaps live in ignored `build/`. Assets and documentation are not mapped into Roblox. The built place intentionally contains no authored map or spawn.

Local source is authoritative for mapped scripts. Rojo may replace mapped instances; sync only into a new disposable foundation place until existing Studio content has been backed up. Do not run native Script Sync and Rojo against the same script tree. Export approved Studio edits back into source before ending a session; do not let MCP edits drift from Git.

Shared code is readable by clients. Future authority and networking choices need a separate design task and ADR. Plain directories allow modules to grow when real requirements arrive.

See [ADR 0001](decisions/0001-foundation.md).

The authorized movement study has separate `movement.project.json` / `movement.test.project.json` mappings under `experiments/movement`; neither is referenced by the foundation projects. See [ADR 0002](decisions/0002-movement-experiment.md). Private downloaded clips are excluded from every tracked mapping. The experimental server creates its functional arena/R15 avatars at runtime; native PlayerModule/Humanoid remain the input/physics substrate.

The isolated [Rocklock map](rocklock.md) has dedicated public/private projects on port 34874. Blender art and simple Roblox collision share one seeded layout. Its generated server copy adapts only initial spawn selection; the controller and camera remain unchanged. See [ADR 0010](decisions/0010-rocklock-map.md).

# Project memory

## 2026-10-28 ? Foundation setup

- Inspected an empty workspace and read the pasted request and PDF background. Kept the request authoritative; PDF gameplay instructions were not adopted.
- Reused existing Rokit 1.2.0 and cached Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0 and Luau LSP 1.70.1. No tool, addon or third-party skill was installed.
- Created minimal source probes, isolated Studio test project, verification tooling, editor configuration and CI. Normal build contains exactly three scripts; no gameplay or authored environment.
- Created shared agent instructions, three original mirrored procedure skills, Markdown knowledge system, asset/creature/ADR templates and specialist research.
- Verified local formatting, linting, shared-module types, both Rojo builds, sourcemap, built script placement/source fidelity, test isolation, skill metadata/parity and local HTTP serve. The API uses MessagePack in this Rojo version; connectivity verification checks HTTP status/content without claiming a Studio sync.
- Kept integration examples inactive and documented approval-dependent steps. No global client configuration, account connection, GitHub remote or publishing action was changed.
- Deferred Studio runtime/multiplayer/MCP tests because no approved active session/connection was available. The bundled skill validator lacks PyYAML; no dependency was installed to work around it.
- Initialized local Git and created the foundation snapshot on `main`. See [verification](verification.md), [status](status.md) and [research](research/tooling.md).

## 2026-10-28 - GitHub publication

- User requested GitHub publication with a simple README, then explicitly selected public visibility.
- Reused the authenticated GitHub CLI to create https://github.com/jarems421/slugshot and configure `origin`.
- Simplified the README to a project description, setup commands and links. Updated current notes to reflect the approved remote.
- First hosted Linux CI passed: https://github.com/jarems421/slugshot/actions/runs/40719697932. Local foundation checks also passed previously. Studio/MCP setup remains separate.

## 2026-10-28 - Approved Studio integrations verified

- The owner approved the matching Rojo plugin, Studio MCP for Claude Code/Codex, runtime/two-client verification and pushing results.
- Installed the plugin bundled with Rojo 7.7.1. Studio auto-updated to 0.745.0.7451137 during launch; its built-in MCP setting was already enabled and was verified live.
- Claude's private project-local entry reports Connected. Codex's project config is active; native app-server discovered 31 tools and made live list/read calls without a model turn. Only this workspace's trust was added.
- Single-client and separate server/two-client tests passed. Each client logged once, saw both players, loaded the shared module and could not see the server bootstrap. EndTest returned success and the parent returned to Edit mode.
- Verified filesystem-to-Studio sync with a temporary source comment, then restored and verified exact original source. The normal place has no test folder.
- Captured sanitized evidence in [the Studio record](evidence/2026-10-28-studio.json). Documented avatar asset-type and built-in MaterialManager warnings without changing design/assets. Host config, tokens, raw logs and scratch helpers remain untracked.
- No requested integration/runtime test remains pending. No gameplay or unrelated plugin was added. See [verification](verification.md) and [reproduction](testing.md).
- Final local checks and the hosted [integration setup CI](https://github.com/jarems421/slugshot/actions/runs/40724542365) passed for `407102e`; runtime evidence remains separate from hosted checks.

## 2026-10-28 - Movement research and isolated prototype

- Owner authorized movement research, relevant verified free assets/tools and an isolated playable study; subsequently explicitly requested pushing the work. Used `experiment/movement-sandbox`, preserving foundation source/projects.
- Inspected actual controller source/licences and extra leads. Movement Base had no implementation. Selected a small native Humanoid layer experimentally; full CCL opt-in remained unvalidated. No third-party controller/runtime/editor plugin installed.
- Downloaded both Cinderlore starter packs to ignored private storage, audited zero scripts and confirmed seven relevant clips playing on R15. Inspected private captured samples. No source clips, converted poses, screenshots of private clips or reusable IDs enter Git/public builds.
- Built an arena, comparison profiles, smoothed running, compact directional evade, visual aerial flourish, original procedural R15 poses, aim pose and harmless marker. No combat or final game-design decisions added.
- Actual tests caught AnimationConstraint compatibility, blend-state overwrites, jump-probe timing, server position/velocity lag and respawn mouse cleanup. Corrected these and reran relevant checks.
- Single-client tests, native W/Shift/Q/Space/F input and two-client movement/presentation passed. One 60 ms/direction plus 10 ms jitter trial completed and settings were restored. Server rejected 32 invalid/rate-limited requests. Broad FPS/device/security claims remain unverified.
- Added movement skill and mirrored Claude copies, public-safe evidence and CI coverage. Human playtesting is the next gate; see [movement guide](movement.md), [research](research/movement.md) and [results](movement-verification.md).

## 2026-10-28 - Movement refinement (v2)

- v1 playtest feedback (owner): evade read as a dash, flourish as a procedural spin, running/jumping lacked expression; target is fast, light, athletic and fluid without floatiness.
- Owner first chose Mixamo + Blender. Built and verified (on synthetic data) an original retargeter with portable Blender 4.5.14 LTS in ignored `.tools/`. Owner did not download clips and, after a trade-off discussion, chose original clips for now with Mixamo as a later upgrade.
- An intermediate build only changed controls because visuals depended on missing clips; the owner noticed. Lesson: never gate the visible improvement on an asset the owner has not yet supplied.
- Implemented original keyframed clips, clip player, rig-accurate ground contact, single Q/B acrobatics control, root-motion rolls, airtime-fitted flips, landing-roll buffer and a v1 comparison build. Removed the v1 procedural presentation from the working tree (kept in `e2b5688`).
- Studio tests caught and fixed: Humanoid braking against roll velocity, server rejecting landing rolls (replication lag), roll contact on the head (now a diagonal shoulder roll), observers cancelling flips (interpolation lag), remote rig streaming. A suspected "remote velocity is zero" turned out to be test timing; the workaround was removed.
- An interrupted test run left Studio network emulation at 60 ms/10 ms in the test window; detected, reset to 0 and verified; the two-client script now requires a 0 baseline. Never cut test output with `head` while a script holds temporary settings.
- See [movement guide](movement.md), [results](movement-verification.md#v2-refinement-2026-10-28) and [ADR 0003](decisions/0003-clip-presentation.md). Next gate: owner playtest of v2 versus v1.

## 2026-10-29 - Traversal from Place1 (v3)

- The owner asked why the lab was not adapting established free movement systems. Answer given: the mechanics already sit on Roblox's native Humanoid, and the reviewed frameworks bring first-person/gravity/stamina baggage and no roll/flip animation; the gap is animation. The owner chose Mixamo (later, own download) plus parts of Place1, and picked mantle and wall hop over slide and bunny-hop.
- Adapted Place1's MIT detection (pinned `87da75e`) into `client/Traversal.luau` with the full notice. Added `MantleLow`/`MantleHigh`/`WallHop` original clips, a clip `climb` curve (also produced by the Mixamo converter's new `traversal` mode), server geometry checks and a traversal course. v2 comparison build added. See [ADR 0004](decisions/0004-place1-traversal.md).
- Studio tests caught: server rejecting genuine wall hops because the hop request overtook replication of the jump (fixed by polling and recent positions); possible out-of-order validation (now one action at a time per player); FloorMaterial lagging takeoff and dropping early second presses (grounded check now needs low vertical speed, plus a 0.15 s hop buffer); a belly-flop press pose and an overhead reach on chest-high ledges (retuned, threshold 3.2 studs).
- Lesson: a test that keeps moving after an action can falsely fail (the character ran off the far side of the ledge). Sample during the action, not only at the end.
- See [results](movement-verification.md#v3-traversal-2026-10-29). Next gate: owner playtest of v3 against v2/v1; Mixamo needs the owner's downloads.

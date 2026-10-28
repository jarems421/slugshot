# Specialist tooling research

Reviewed 2026-10-28. These are candidates for later approved work, not dependencies or gameplay requirements. No candidate gameplay library, Blender addon or test framework was installed. Maintenance dates below are GitHub API `pushed_at` snapshots, not proof of recent releases, support quality or correctness. Licenses describe repository code; embedded assets can have separate terms.

## Foundation choices

| Tool | License / review | Trade-off and disposition |
| --- | --- | --- |
| [Rojo](https://github.com/rojo-rbx/rojo) 7.7.1 | MPL-2.0; not archived; pushed 2026-10-06; release tag verified | Existing cached CLI reused. Source/build/sourcemap verified; separate Studio plugin and sync test pending |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) 2.6.0 | MPL-2.0; not archived; pushed 2026-10-12; release tag verified | Existing formatter reused; parses Luau, does not prove runtime correctness |
| [Selene](https://github.com/Kampfkarren/selene) 0.32.0 | MPL-2.0; not archived; pushed 2026-10-01; release tag verified | Existing Roblox-aware linter reused; not a full type checker |
| [Luau LSP](https://github.com/JohnnyMorganz/luau-lsp) 1.70.1 | MIT upstream; release tag verified; executable already cached | Shared module analyzed in standard platform mode; engine script type analysis needs Roblox definitions/Studio |
| [Rokit](https://github.com/rojo-rbx/rokit) 1.2.0 | MIT; not archived; pushed 2026-09-27 | Existing tool manager reused; pins reviewed tool versions. CI bootstraps official 1.2.0 archive with SHA-256, avoiding another setup action |

No Wally packages are needed. Existing Wally in the host cache was not added to this project. CI uses pinned first-party checkout/setup-python/upload-artifact actions. Third-party setup-rokit candidates were investigated but not used; the inspected alternative did not expose a repository license through GitHub metadata, and direct official bootstrap is smaller to audit.

The CI Rokit archive is `rokit-1.2.0-linux-x86_64.zip` from the upstream release. SHA-256: `951a7f3ec3d2a5e021fd1867d32f69f010ee4c2927f644b759578afc59c65fc0`. Bytes were downloaded into memory and hashed for verification, not extracted or installed locally. This pins observed bytes; it is not an independent publisher signature. Remaining tool downloads use exact Rokit manifest versions.

## Movement, physics and multiplayer networking

| Candidate | License / maintenance snapshot | Evaluation and next gate |
| --- | --- | --- |
| [Native Roblox network ownership](https://create.roblox.com/docs/physics/network-ownership), [server authority](https://create.roblox.com/docs/projects/server-authority) and [Character Controller Library](https://create.roblox.com/docs/characters/character-controller-library) | Platform features, governed by Roblox terms; current official docs | Compare native capabilities before choosing a custom controller. Authority features have version/availability constraints and simulation rules; confirm in installed Studio. No authority settings or movement design selected |
| [Place1 Movement System](https://github.com/alexkkork/place1-movement-system) | MIT; not archived; pushed 2026-08-31 | Useful movement reference, but bundles camera/first-person, gravity, stamina and traversal choices. README states client-driven behavior and no built-in anti-cheat. Those assumptions conflict with keeping design open. Study only if a movement experiment is approved; do not import the package |
| [Chickynoid](https://github.com/easy-games/chickynoid) | MIT; not archived; pushed 2024-05-27 | Reference for server-authoritative movement, prediction and correction. Invasive replacement for Humanoid behavior, with custom collision limitations described by upstream. Older activity and substantial integration cost; compare native authority first. Not selected |
| [Blink](https://github.com/1Axen/blink) | MIT; not archived; pushed 2026-09-23; README notes separate icon attribution | Typed generated networking may reduce payload overhead; adds schema/code-generation workflow. Compression does not replace server semantic validation. Benchmark real message needs before choosing it; no networking package installed |
| [FastCast2](https://github.com/weenachuangkud/FastCast2) | Unofficial FastCast continuation; not archived; pushed 2026-10-28; GitHub identifies license as Other/NOASSERTION | Projectile casts and parallel support are future research only. License obligations and exact version remain unresolved; root LICENSE URL did not resolve. Do not assume MIT or import until license/source audit and an approved projectile requirement |
| [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) | Apache-2.0; not archived; pushed 2025-07-31 | Future persistence candidate with lifecycle/session-locking considerations. Requires real data schema and failure/recovery tests; no persistence needed now. It is a community library, not evidence for the PDF's claimed native ProfileService APIs |

Do not choose skiing, sliding, bunny hopping, combat hit rules or a rollback architecture merely because a reference implements them. Future prototypes should measure responsiveness, correctness under latency/loss, CPU cost and device behavior against explicitly approved criteria.

## Animation, VFX and cinematics

| Candidate | License / maintenance | Evaluation and next gate |
| --- | --- | --- |
| [Roblox Animation Editor](https://create.roblox.com/docs/animation/editor) | Native Studio tool; Roblox platform terms | Rig-based animation authoring without another package; validate real rig/import and animation ownership when assets are authorized |
| [ParticleEmitter](https://create.roblox.com/docs/effects/particle-emitters), [Beam](https://create.roblox.com/docs/reference/engine/classes/Beam), [Trail](https://create.roblox.com/docs/reference/engine/classes/Trail), [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService) | Native engine APIs | Candidate building blocks for future transformation presentation and camera work. Low dependency cost, but timing, cleanup, mobile quality and performance still require prototypes. No effects or camera systems created |
| [RbxCameraShaker](https://github.com/Sleitnick/RbxCameraShaker) | MIT; not archived; pushed 2023-07-06 | Small optional shake utility, not a cinematic editor. Older activity; code/API review and need comparison required. No camera dependency selected |
| Moonlite lead | The attempted `evaera/moonlite` repository returned 404 | Identity, license and maintenance unverified; do not recommend or install this guessed repository |

Transformations may require mesh/rig swaps, animation, effects or another presentation approach; no method is confirmed. Do not design the asset pipeline around a speculative transformation rule.

## Blender, original environments and assets

[Blender](https://www.blender.org/about/license/) is a GPL-licensed creation tool; review exact version and any addon licenses separately. Tool licensing does not supply rights to imported third-party artwork. Native Blender modeling/rigging plus Studio import is the first workflow to evaluate after art work is approved. No Blender executable was found on PATH; no installation was performed.

[Roblox 3D Importer](https://create.roblox.com/docs/art/modeling/3d-importer) and [Terrain Editor](https://create.roblox.com/docs/studio/terrain-editor) are native options for later original environment work, not a commitment to underground maps or procedural caves. Export axis/scale, collision, texture and animation checks belong to an isolated roundtrip before committing to asset conventions.

[MCP for Blender](https://github.com/ahujasid/mcp-for-blender) is MIT, not archived, pushed 2026-10-28 and explicitly third-party. Upstream renamed blender-mcp in September 2026. It can execute Python and integrate remote asset providers; optional services have their own licenses/terms. A pinned source/dependency review and approval must precede addon installation or connection. No automatic installer was run. Native CLI/export may make MCP unnecessary.

## Multiplayer testing

[Studio testing modes](https://create.roblox.com/docs/studio/testing-modes) cover single-client and multiple clients. [Network Simulator](https://create.roblox.com/docs/studio/network-simulator) provides latency, jitter and loss controls with version/beta availability to verify locally. Start here rather than installing an external multiplayer harness.

[TestEZ](https://github.com/Roblox/testez) is Apache-2.0 but archived, last pushed 2024-03-05. It remains a reference, not a selected new dependency. A dependency-free Studio assertion script is enough for the foundation. A later growing suite can justify reviewing a maintained framework and an execution runner; CLI package tests cannot emulate Roblox replication by themselves.

## Adoption procedure

For any later candidate: pin a revision, review license and bundled asset rights, inspect source and dependencies, assess maintenance and engine compatibility, compare the smallest native alternative, then obtain any required installation/account approval. Prototype in an isolated place, measure the approved hypothesis, record evidence and trade-offs, and only then propose an ADR. Current research is not authorization to install.

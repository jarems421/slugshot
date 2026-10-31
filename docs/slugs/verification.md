# Creature pipeline verification

Date: 2026-10-31 (Europe/London). Work began under the owner's 2026-10-30 technical pipeline request.

## Implemented/verified — offline

`python tools/verify_slugs.py --blender` passed with the existing Blender 4.5.14 LTS and pinned project tools. The raw local log is `build/verify-slugs.log`; source hashes, mesh counts, settings and measured animation roundtrips are preserved in [the export evidence](evidence/2026-10-31-export.json).

| Check | Observed result |
| --- | --- |
| Foundation verification | Passed normal/test build placement, source fidelity, strict shared-module analysis and skill parity |
| Python configuration contracts | 20 tests passed, including invalid/missing fields, paths, rigs, sockets, actions, source dependencies, proportions, palettes and no-transform exception |
| Generated species data | JSON-to-Luau output matches checked-in formatted module |
| Creature Luau | StyLua check, Selene (0 errors/warnings) and full strict luau-lsp Roblox analysis passed |
| Rojo packaging | Separate preview/test places built; test script excluded from preview; no movement, foundation startup or private data mapped into either |
| Blender generation | Six-bone protoform and independent five-bone transformed fixture saved as editable `.blend` files |
| Anatomy variation | One-eye, no-horn variant with changed body/head proportions and two-material bands generated and validated; removed feature meshes absent |
| Geometry/weights | Protoform 1,134 triangles; transformed 274 triangles; all checked mesh budgets and normalized skin weights passed |
| Model exports | Two FBX models reimported; bone sets/hierarchy/rest placement, mesh counts, normalized weights and dimensions matched tolerance |
| Animation exports | Six individual clips reimported: Idle, Launch, Spin, Prepare, Reveal, Attack; nonzero evaluated motion and one-second durations verified; loop endpoint matrices matched for Idle/Spin |
| Previews | Four stills (front/side/three-quarter/rig) and 24 frames each of turntable, idle and transformation; local browser player with scrubbing |
| Integrity | Source/config/rig/tool fingerprints, individual source/export SHA-256 values, required paths and preview source matching verified |
| Corruption probes | Nine failures correctly rejected: missing bone, wrong rotation, unapplied scale, reversed bone roll, displaced anatomy vertex, excessive triangles, missing action, unweighted vertex and stale source configuration |
| Protected source | Git diff against `913f9e6` empty for foundation/movement source, their Rojo projects, existing animation converter and existing verification scripts |

The corruption test exposed stale Blender bounding-box caching; anatomy validation now measures actual vertices. A source palette change is also explicitly rejected until regeneration, preventing a fresh report from blessing an old `.blend`.

The strict analyzer prints its existing non-error notices about missing standalone foundation definitions and disabled automatic sourcemap file watching in CLI mode. No new Luau lint/type errors remained. Offline timing measures the exported action duration, not rendered Roblox frame behavior.

Reviewed inspection images: [front](evidence/2026-10-31-front.png), [side](evidence/2026-10-31-side.png), [bone hierarchy](evidence/2026-10-31-rig.png), [larger replacement](evidence/2026-10-31-transformed.png). The intentionally crude fixtures are original technical geometry and are not approved character art. The complete interactive preview remains under `build/slugs/placeholder/previews/index.html`.

## Unresolved — Studio runtime and import

Studio MCP repeatedly returned `{"studios":[]}` during this session. A separate local creature-test place launch was attempted; no connected creature instance became available through MCP. Existing Rocklock Studio sessions were not changed, stopped or closed. No native fixture runtime, Studio assertion execution, imported mesh deformation, asset ownership, uploaded animation permission or real Roblox clip playback is claimed.

The test place contains server timeline assertions for stage ordering, zero/short/long flight, early impact, no-transform, invalid times and monotonic progress when estimates change. Client fixture assertions cover idle, rig swaps, animation-slot requests, impact, collision isolation and twenty cleanup cycles. These were type-checked and packaged, **not executed in Roblox**. Follow the [native and import checklists](studio-import.md) and record actual Output, screenshots, warnings and cleanup observations before marking runtime verified.

Nonuniform bone-scale channels, skinned-mesh materials/UVs, animation permissions, imported model origins, socket placement after import, actual close-range visibility and rendered loop seams remain target-engine gates. The native lab is an upload-free Parts/Motor6D proxy with rough feature shapes; it cannot establish FBX skin fidelity. Imported rigs use AnimationController/Animator plus private approved bindings, and an explicit deformation hook when required.

## Confirmed boundaries and limits

No final ProtoformBase design, finished species, production particle library, abilities, blaster/projectile implementation, damage/collision system, networking, inventory persistence or full combat was added. No addon/software installation, external account, asset upload, experience publication, main merge or push occurred. No reusable private IDs or restricted movement clips are in the public data/builds.

Real authored sources, sophisticated material baking, arbitrary retargeting, literal mesh morphing and production device/performance quality need future approved work. Authored-source loading/export is implemented, but this evidence run uses generated original placeholders; it is not a blanket certification of future artist files. The procedure requires a minimal real Studio roundtrip before a species set is produced.

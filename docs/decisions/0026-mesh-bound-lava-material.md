# 0026 - Animate the lava's own material

Date: 2026-11-03. Status: Implemented locally; owner review pending.

## Decision

Owner rejected the waterfall-style ribbons sitting above the lava. Remove all lava Beam overlays. Clone the original SurfaceAppearance inputs into 256-square EditableImages and animate only colour. Preserve original paint, alpha, shading inputs and material properties. Source assets remain untouched.

Read original triangles and UVs once to associate texels with world height. A broad irregular colour wave travels downhill at approximately 1.5 studs/second (18-stud wavelength, twelve-second cycle), with at most 24 image updates/second. Mesh, UVs, transform, size and collision stay fixed. Destroy the temporary read-only EditableMesh after setup; release images when lava leaves the scene.

Wait for lobby readiness and its named material. Keep the static original on setup/allocation failure and emit a sanitized warning. CreateSurfaceAppearanceAsync currently requires EditableImage inputs, so all present maps are cloned although only colour changes.

## Evidence and limits

[Native evidence](../evidence/2026-11-03-integrated-lava-material.json): actual pixel changes, fixed mesh, zero overlay beams, orange paint in corrected close-ups, slower storm cadence. Vertex tint did not visibly affect the original material. Incorrect image pivot placement initially copied only a quarter of the maps; centered placement plus painted-coverage assertion fix that failure.

Desktop Studio evidence does not prove mobile performance, memory capacity or published acceptance. Published use requires Mesh/Image APIs enabled and appropriate asset permissions; no setting changed or experience published. API failure retains static lava. Owner verdict remains open.

Primary references: [EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage), [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh), [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService).

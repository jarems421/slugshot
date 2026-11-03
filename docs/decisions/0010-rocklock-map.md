# ADR 0010: isolated procedural Rocklock movement-map place

Date: 2026-10-30. Status: **Confirmed implementation approach** under the owner's Rocklock request; map dimensions/art direction remain experimental. Branch: `experiment/rocklock-greybox`. No merge to `main` or Roblox publication.

## Context

The owner requested an actual playable cavern arena with the current movement system, reproducible headless Blender assets, runtime validation and preserved foundation/lab. During implementation the owner rejected the dense first layout and asked for more room for gunplay and larger transformed slugs. This supersedes the initial 100 × 90 starting-size proposal, not the preservation of movement behavior.

## Decision

- A separate pair of Rocklock Rojo projects uses port 34874 and baked Edit-visible geometry. Foundation and movement-lab mappings are untouched; map source lives under `experiments/movement/rocklock` and `tools/rocklock`.
- Share one Python layout between Blender art generation, collision specs and coordinate metadata. v2 is 160 × 140 with fewer structures, wide ordinary routes, two main floor heights and a short sunken passage.
- Preserve every existing controller, camera, profile and clip source. A generated server copy changes exactly one expression: initial character placement calls the map's stable spawn allocator before the existing authority history initializes. The original map factory is replaced only in the Rocklock mapping. Verification checks the exact source difference.
- Use native anchored triangles reconstructed from Blender meshes for the upload-free greybox, with simple gameplay collision proxies. Keep FBX and editable Blender source for a later owner-approved MeshPart import. Decorative geometry never participates in collision or traversal queries.
- Keep private animation clips in the existing ignored private mapping only. Normal builds exclude runtime QA fixtures. Multiplayer QA is an explicit temporary injection into the disposable map, followed by cleanup/reopening.
- Store this small original source `.blend` (about 2 MB), FBX (under 0.3 MB), metadata and original preview PNGs in ordinary Git. No LFS dependency or large asset library is introduced. Generated places, intermediate models, logs and third-party reference images stay ignored.

## Consequences

The map runs immediately without cloud asset permissions. Native facets increase instance count relative to uploaded meshes; current resource counts and observed frame timing are reported with their device limits in [validation](../rocklock-verification.md). Later MeshPart import can reduce that count without changing movement collision.

The broad v2 layout changes spawn distance and sightlines; combat balance and future slug-body fit remain owner playtest questions. Interactive markers are disabled metadata, not a combat/round framework. Destruction must retain permanent route connectivity when that future system is authorized.

## Addendum: v3 horizontal scale

**Confirmed, 2026-10-30:** the owner asked for another roughly 33% size increase. The existing v2 geometry is scaled 1.33 in X and Z, giving 212.8 ? 186.2 studs, while Y heights and movement configuration remain unchanged. Separately named `-v3` place outputs protect an active v2 Studio session. Balance, timing and user judgment remain open.

# Asset management and register

**Confirmed, slug tooling (2026-10-30):** original procedural technical placeholders are authorized in a separate worktree. Their text sources are [species JSON](../assets/source/slugs/species/placeholder.json), [rig JSON](../assets/source/slugs/rigs/protoform-v1.json) and [native Blender generator](../tools/slugs/blender_pipeline.py). Generated editable sources are `build/slugs/placeholder/source/{protoform,transformed}.blend`; model/clip exports are in `build/slugs/placeholder/exports/`; exact SHA-256 hashes, Blender 4.5.14 LTS version, axes, units and settings are in `build/slugs/placeholder/export-report.json` and the [captured evidence](slugs/evidence/2026-10-31-export.json). Creator: original Slugshot code/geometry, owner's pipeline request; no third-party art or texture obligations. No asset IDs/owners or uploads exist. **Implemented/verified:** offline roundtrip only; see [checks and runtime gates](slugs/verification.md). Real authored binaries still require a storage decision; build outputs are disposable and ignored.

Status: Confirmed procedure. The movement experiment has original procedural poses and privately acquired animation candidates; see [movement provenance](movement-assets.md). No third-party animation sources or reusable IDs are included in public builds, and no animation/experience was published.

Use `assets/source/<category>/<asset-name>/` for editable originals and `assets/exports/<category>/<asset-name>/` for reviewed exports when assets are authorized. Names use lowercase kebab-case and meaningful versions. Keep export settings beside source. Do not infer creature names, rig shape or art style from the folder scheme.

For every asset record creator/source URL, explicit license and obligations, permission evidence, edit history, source/export paths, content hash, tool version, import scale/orientation and Roblox asset ID/owner after approved upload. A publicly viewable model is not automatically licensed for reuse. Code licenses do not establish rights to bundled textures or characters.

Keep original references distinct from deliverable art. Check topology, dimensions, collision, skeleton/bone mapping, texture rights and animation roundtrip against current Roblox limits before import. Choose binary storage/LFS when real assets arrive; none is configured yet.

| Asset | State | Creator/source | License/permission | Source/export | Roblox ID/owner | Verification |
| --- | --- | --- | --- | --- | --- | --- |

Creature proposals use [this template](templates/creature.md). Approval of a proposal is separate from approval to upload an asset.

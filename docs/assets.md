# Asset management and register

Status: Confirmed procedure. The movement experiment has original procedural poses and privately acquired animation candidates; see [movement provenance](movement-assets.md). No third-party animation sources or reusable IDs are included in public builds, and no animation/experience was published.

Use `assets/source/<category>/<asset-name>/` for editable originals and `assets/exports/<category>/<asset-name>/` for reviewed exports when assets are authorized. Names use lowercase kebab-case and meaningful versions. Keep export settings beside source. Do not infer creature names, rig shape or art style from the folder scheme.

For every asset record creator/source URL, explicit license and obligations, permission evidence, edit history, source/export paths, content hash, tool version, import scale/orientation and Roblox asset ID/owner after approved upload. A publicly viewable model is not automatically licensed for reuse. Code licenses do not establish rights to bundled textures or characters.

Keep original references distinct from deliverable art. Check topology, dimensions, collision, skeleton/bone mapping, texture rights and animation roundtrip against current Roblox limits before import. Choose binary storage/LFS when real assets arrive; none is configured yet.

| Asset | State | Creator/source | License/permission | Source/export | Roblox ID/owner | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| Rocklock cavern v3 | Implemented; native integration and offline FBX roundtrip checked; Studio importer unverified | Original Slugshot seeded Python/Blender geometry; owner task 2026-10-30 | Original project art; no copied franchise meshes, textures or reference images | `assets/source/environment/rocklock/rocklock.blend`; `assets/exports/environment/rocklock/rocklock-rocks.fbx`; hashes/settings in `export.json` | None; no upload | Blender 4.5.14 LTS; [map workflow](rocklock.md) and [runtime limits](rocklock-verification.md) |
| Rocklock crystals | Implemented; offline FBX roundtrip checked; Studio importer unverified | Original Slugshot procedural Blender geometry; owner task 2026-10-30 | Original project art; reference images not reused | `assets/source/environment/rocklock-crystals/rocklock-crystals.blend`; `assets/exports/environment/rocklock-crystals/rocklock-crystals.fbx`; hashes in `export.json` | None; no upload | Blender 4.5.14 LTS; [research and workflow](research/rocklock-crystals.md) |
| Rocklock cavern art pass and crystals | Implemented; native parts and offline FBX roundtrips checked; Studio importer unverified | Original Slugshot procedural Blender geometry, 2026-10-30 | Original project art; no copied franchise assets | `assets/source/environment/rocklock-cavern/`, `assets/exports/environment/rocklock-cavern/`, `assets/source/environment/rocklock-crystals-cavern/`, `assets/exports/environment/rocklock-crystals-cavern/`; hashes in respective `export.json` | None; no upload | Blender 4.5.14 LTS; [map workflow](rocklock.md), [test limits](rocklock-verification.md) |

Creature proposals use [this template](templates/creature.md). Approval of a proposal is separate from approval to upload an asset.

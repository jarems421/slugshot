# Slug asset pipeline

**Confirmed — 2026-10-30:** the owner authorized reusable creature tooling and a deliberately temporary proof of concept. On 2026-10-31 they additionally requested the first original Flopper-inspired creature draft and a [catalogue for all slug descriptions](catalog/index.md). The model awaits review; no final species, combat system or artistic style is approved. [Architecture decision](../decisions/0011-slug-asset-pipeline.md).

**Implemented:** native Blender Python generation, authored-source loading, custom skeletal rigs, modular anatomy, baked actions, FBX model/clip exports, offline reimport checks, inspection renders, a browser sequence viewer, JSON validation and an isolated strict Luau preview lab. [Actual checks and remaining gates](verification.md).

## Isolation and layout

Worktree: `C:/Users/runni/slugshot-slug-pipeline`, branch `feature/slug-asset-pipeline`, based on `913f9e6`. The original checkout remains on `experiment/rocklock-greybox` with Claude's uncommitted work. No Rocklock, movement, destruction or foundation code is changed or synced. No merge, push, asset upload or experience publication is performed by the tools.

| Path | Purpose |
| --- | --- |
| `assets/source/slugs/rigs/*.json` | Versioned rest skeletons and sockets |
| `assets/source/slugs/species/*.json` | Species anatomy, proportions, palette, action references and transformation profiles |
| `assets/source/slugs/models/<species>/` | Future reviewed authored `.blend` inputs, owned by that species |
| `tools/slugs/common.py` | Configuration contract and deterministic Luau compiler |
| `tools/slugs/cli.py` | System Python entry point |
| `tools/slugs/blender_pipeline.py` | Native `bpy` implementation; no addons |
| `experiments/creatures/` | Independent species data, playback, visual handles and native preview fixture |
| `tests/slugs/` | Python configuration tests and in-memory Blender corruption tests |
| `build/slugs/<species>/source/` | Generated editable `.blend` files, ignored |
| `build/slugs/<species>/exports/<form>/` | Model and individual animation FBXs, ignored |
| `build/slugs/<species>/previews/` | PNG views/sequences and `index.html`, ignored |
| `build/slugs/<species>/export-report.json` | Provenance, hashes, budgets, axes, exporter settings and roundtrip results |

The source JSON and scripts reproduce disposable placeholder binaries. Do not make irreplaceable manual edits under `build/`; regeneration overwrites those files. Preserve authored work under `assets/source/slugs/models/<species>/` after reviewing provenance and deciding binary storage with the owner. No LFS installation is necessary for this text-first setup. Private references and IDs remain in ignored `private-assets/`; shared configuration and public builds contain none.

## Run the complete proof of concept

Use Python 3.11+ and the already pinned Rojo, StyLua, Selene and luau-lsp. Set `BLENDER` to an existing executable when it is outside this worktree; nothing is downloaded or installed by the creature CLI.

```powershell
Set-Location C:/Users/runni/slugshot-slug-pipeline
$env:BLENDER = 'C:/Users/runni/slugshot/.tools/blender-4.5.14-windows-x64/blender.exe'
python tools/slugs/cli.py compile
python tools/verify_slugs.py --blender
Start-Process build/slugs/placeholder/previews/index.html
```

`verify_slugs.py --blender` runs the foundation checks, configuration tests, generated JSON/Luau parity, formatting, linting, full Roblox strict type analysis, Rojo builds, packaging isolation, Blender generation for all registered species, FBX export/reimport, previews, output validation, deliberate asset-corruption checks, a second anatomical variant and the first draft's motion checks. The placeholder and first slug are original project geometry. Type definitions use the existing hash-pinned verification helper; no new package is installed.

Individual steps:

```powershell
python tools/slugs/cli.py validate-config --species placeholder
python tools/slugs/cli.py generate --species placeholder
python tools/slugs/cli.py export --species placeholder
python tools/slugs/cli.py render --species placeholder --frames 24
python tools/slugs/cli.py validate --species placeholder
python tools/verify_slugs.py
```

`all` runs generate, export, render and validate. Source files record the configuration, rig and tooling fingerprints. Export/render reject stale generated sources. Validation verifies all source/export hashes and rejects previews from another source build. FBX file hashes are evidence for the observed build; Blender metadata means binary-identical rebuilds are not promised.

## Authoring and review

Start with the [species guide](species-guide.md) and [rig specification](rig-specification.md). Geometry generation is intentionally limited to two placeholder generators. Real art uses `generator: "authored"` and a `.blend` source; the pipeline validates and exports it rather than pretending to design it. Each authored form must contain one armature and its skinned meshes, applied object transforms, the declared rest skeleton, palette/materials and declared actions at 24 FPS. Constraints/modifiers beyond a single armature modifier must be baked into an export copy first. This v1 rejects unsupported modifier stacks instead of silently exporting different geometry.

Front, side and three-quarter renders use Blender Workbench and diffuse material colors. The turntable, idle and configured blink/hop/launch/impact previews each contain 24 PNG frames by default. The placeholder transformation preview demonstrates a spinning, squashing small rig replaced by a distinct larger rig. The browser viewer has playback, sequence selection and frame scrubbing; authored action durations are respected. The bone-only view visualizes rest bones and parent links. Bone names/positions are in the rig JSON and export report. These are inspection tools, not Roblox lighting evidence.

## Export contract and tooling review

Observed executable: **Blender 4.5.14 LTS**, build `62c1db4208e8`. Reuses the existing portable installation read-only. Source coordinates are X right, +Y forward, Z up; one Blender unit is one intended stud. Export uses scale 1, applied units, Y up / -Z forward, selected armature/meshes, no leaf bones, no NLA/all-actions mixing, one baked action per FBX, one-frame samples and zero curve simplification. The report preserves exact settings and source hashes.

The current [Roblox general specifications](https://create.roblox.com/docs/art/modeling/specifications) list 20,000 triangles per mesh; our test budget is stricter at 10,000. Other v1 budgets (25,000 total triangles, 64 bones and four influences per vertex) are project guardrails, not claims about universal engine limits. The [Importer](https://create.roblox.com/docs/studio/importer) supports FBX/glTF rigs and animation data. FBX is the tested interchange path here; glTF remains an alternative requiring its own roundtrip. [Roblox rigging guidance](https://create.roblox.com/docs/art/modeling/rigging) explains imported Bone instances and visual-only skeletal deformation.

Blender's [FBX documentation](https://docs.blender.org/manual/en/4.4/addons/import_export/scene_fbx.html) describes action-association and bone-axis caveats. Installed 4.5.14 behavior was tested directly rather than inferred from exporter defaults. Native animation/armature features suffice. No third-party animation addon or Blender MCP was installed; the existing [tooling review](../research/tooling.md) records why its arbitrary Python/remote-asset capabilities require a separate source and dependency review. The private Mixamo-to-R6 tooling is not used by creatures.

Continue with the [Studio import checklist](studio-import.md), [transformation API](transformation-system.md) and [evidence](verification.md).

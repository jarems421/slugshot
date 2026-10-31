# Roblox import and creature preview lab

**Implemented:** two isolated Rojo builds on loopback port **34875**. They do not include foundation startup, player movement, Rocklock geometry, destruction, private animation data or uploaded asset IDs.

```powershell
python tools/verify_slugs.py
# Playable fixture; no tests in this build:
Start-Process build/SlugshotCreaturePreview.rbxlx
# Separate assertions and fixture:
Start-Process build/SlugshotCreatureTests.rbxlx
# Optional live sync, only into the dedicated creature place:
rojo serve creatures.project.json
```

Preserve existing Studio windows and unsaved work. Connect Rojo only to a disposable creature place. Do not point this project at the movement or Rocklock place. The native fixture needs no uploads. The test place runs the timeline assertion script on the server; expect `PASS: creature timeline ...` in Output. The public preview build excludes assertions. Check [verification](verification.md) before claiming those assertions executed.

## Native fixture checklist

- Play: see a small labeled test proxy and HUD, no player avatar or movement systems.
- Idle: head moves and body subtly deforms; reset remains idle beyond a second.
- `2`: small proxy spins/squashes and changes to the five-joint larger proxy; energy Highlight follows the envelope.
- `1`: compressed 0.06-second transition completes promptly; no artificial travel delay.
- `I` during a long transition: the transformed proxy is visible immediately at impact.
- `A` after reveal: the crest performs the one-second attack motion; pressing it before transformation is harmless.
- `R`, repeat 20 times, stop/restart: only one active form is parented, no leftover models/tracks/connections or new Output errors.
- Run the separate test place: all timeline assertions pass, including no-transform and zero-distance cases.
- In the same test place, expect a second client Output line `PASS: native creature visual lifecycle ...`; this checks idle, independent-rig swaps, an updated flight estimate, early impact, collision isolation and twenty create/transition/destroy cycles.

These checks exercise native Motor6D proxies. They do not validate imported skinned meshes or Roblox animation permissions.

## Manual FBX import gate

Current [Roblox Importer](https://create.roblox.com/docs/studio/importer) accepts rigged FBX/glTF and animation data; [rigging documentation](https://create.roblox.com/docs/art/modeling/rigging) describes the resulting Bones. Use a **new local creature place**, never Claude's map. Import may create persistent mesh/animation assets; obtaining any required upload authorization is a separate step. This task did not upload anything.

1. Generate/export the placeholder. Inspect `build/slugs/placeholder/export-report.json`: exact hashes, 24 FPS clips, bone names, source dimensions, settings and provenance are recorded.
2. Open File → Import and choose `exports/protoform/model.fbx`. Preview warnings before committing any import. Select a general custom rig/model workflow; do not use Avatar Setup, R6/R15 conversion, humanoid auto-rigging or Marketplace avatar assumptions.
3. Confirm the intended scale in studs and forward direction (Roblox -Z); compare the reported rest bounds. Do not silently compensate with a 100x scale. Retain the custom hierarchy. Inspect applied rotation, skin, normals, material colors, face modules and jaw placement. Save warnings verbatim in sanitized evidence.
4. Repeat for `exports/transformed/model.fbx`; verify its independent five-bone hierarchy and larger rest dimensions. Name the templates clearly. Set `RigId` to the corresponding JSON rig ID. Set each Model's pivot/PrimaryPart at its authored floor origin and anchor the root. Arrange any additional rigid parts/welds so gravity cannot separate the template; disable collision/query/touch for visual parts. Review each mesh's skin modifier and hierarchy in the imported model.
5. In the Animation Editor, select each custom rig and import the matching individual clip FBX using the current editor's import workflow. Check that tracks bind to the intended Bones, not a duplicate rig. Preview Idle/Launch/Spin/Prepare and Reveal/Attack, recording actual timing, loop seams and deformation. In particular, check Blender scale channels: CFrame-only Bone transforms do not establish support for animated bone scaling. Supply a tested `onDeform` strategy or retain model-swap presentation where needed.
6. If clip publication is authorized later, upload under the experience's intended owner/group, confirm permission in that experience, and record verified references **only under ignored `private-assets/`**. [Animator](https://create.roblox.com/docs/reference/engine/classes/Animator) is the playback API; a non-humanoid uses an AnimationController with an Animator. Do not copy sample IDs from documentation.
7. Supply local templates via `Visual.Options.resolveModel` and verified private clip bindings via `animationIds`. The current preview selects native fixtures by default, so an FBX sitting in Workspace is not automatically a verified integration.
8. Run stationary playback, rotation, compressed/long transformation, early impact, model swapping, attack and cleanup. Inspect material/UV appearance, bone motion, socket positions and transformed scale. Record results, screenshots, warnings and device/frame-rate limits in the [verification note](verification.md).

No imported Roblox animation, ownership permission, mesh scale or runtime skin deformation is verified by Blender reimport, luau-lsp or a successful Rojo build. If Studio MCP has no connected instance, complete the checklist manually rather than modifying global MCP/security settings or another agent's place.

## Floppy import (owner step)

Run `blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/export_floppy_roblox.py` with Blender 4.5. It writes `build/slugs/floppy/roblox/`:
- `model.fbx`: skinned body (8,000 triangles) and two eyes (400 each), 8 bones, textures embedded;
- `idle.fbx`: 12 s looping idle with no bone scale;
- `textures/`: `floppy-body-color.png`, `floppy-body-normal.png` (1024) and `floppy-eye-left/right.png`;
- `export-report.json`: hashes, bounds and offline reimport checks.

Importing uploads the mesh and texture assets to the importing account, so the owner performs it. Agents have no Studio connection.

1. Open a new, empty local place, not the game or Rocklock places. Choose File > Import 3D and select `model.fbx`. Leave the rig as a custom rig, not R15/avatar. Keep the scale at 1 stud per unit. Floppy is about 2.5 studs tall and should face the place's -Z (LookVector). Record any importer warnings.
2. Check the result: one Model with `FloppyBody`, `EyeL` and `EyeR` MeshParts, and Bones `root > body_lower > body_upper > head > antenna_L/R, eye_L/R`. Anchor the root part, and turn off CanCollide, CanQuery and CanTouch on the visual parts.
3. Appearance: if the importer didn't create one, add a SurfaceAppearance to `FloppyBody` with ColorMap `floppy-body-color.png` and NormalMap `floppy-body-normal.png`. Each eye gets its own ring texture as ColorMap. Compare with `docs/slugs/catalog/evidence/floppy/blender/game-*.png`.
4. Animation: add an AnimationController with an Animator to the Model. In the Animation Editor, import `idle.fbx` onto this rig and check that the tracks bind to its Bones and that it loops with no hitch at 12 s. Publishing the clip is a separate, owner-authorised step; record any IDs only under ignored `private-assets/`.
5. Device check: use Studio's device emulator (phone and tablet) and look at frame rate, texture sharpness of the drool and lip line, and the eye-ring spin. Record the results in [verification](verification.md).

### Floppy uploaded test place (2026-10-31)

With the owner's approval, `model.glb` was uploaded through Open Cloud as a private Model asset on the owner's account. The ID is only in ignored `private-assets/floppy/` (`roblox_assets.json`, `FloppyAsset.luau`). The uploader is `private-assets/floppy/upload_open_cloud.py`, adapted from the blaster upload. Build and open the test place:

```powershell
rojo build floppy.private.project.json -o build/SlugshotFloppyTest.rbxlx
Start-Process build/SlugshotFloppyTest.rbxlx
```

Press Play. The server script loads the asset, anchors it on the floor facing -Z and prints a `Floppy: loaded ...` line (parts, bones, size, SurfaceAppearance). The client script plays the 12 s idle on the Bones, because Bone transforms set on the server don't replicate. The avatar spawns 10 studs in front, facing Floppy. Per the [Studio handoff rule](../development.md), rebuild and reopen this place after each change. **Unresolved:** the actual load, appearance and idle in Studio (pending the owner's Play test or a Studio MCP session).

### Repaired Floppy and explicit image maps (2026-10-31)

The exporter now reads the repaired source variant, with the approved `floppy.blend` preserved. The game model is about 0.924 studs tall. See [repair evidence](floppy-chamber-repair.md). After the owner reported both copies lost colour, Studio logs confirmed unavailable generated texture packs. `python tools/slugs/upload_floppy_images.py` uploads/caches explicit Image maps and writes private `FloppyAsset.luau` and `materials.rbxmx`. The private Rojo project maps those three preconfigured PBR templates under ServerStorage; `FloppyAppearance` clones them rather than assigning plugin-only texture properties during Play. Do not commit the mapping, templates or upload receipts.

The latest test place is `build/SlugshotFloppyTest-ColoursFixed.rbxlx`; it includes the belly-down chamber pose, shortened grip, 0.88 gun scale and real inward neutral light. Confirm both pedestal and loaded colours, then equip hotbar 1 and judge fit/light/idle. A complete GLB or an upload receipt does not establish imported material availability.

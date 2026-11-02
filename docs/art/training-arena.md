# Training arena asset

## Current scope (2026-11-02)

**Confirmed:** owner requested a training arena based on the floating spawn island, enlarged to about two or three times its present scale. Remove the roots, cracked top and lower spiral; add more rubble beneath it. Empty space surrounds it, with the existing rock-wall language enclosing all directions and the ceiling. Include a small movement area, dummies and eventually training-only access to every implemented slug, independent of ownership.

**Confirmed, later instruction:** build an inspectable 3D asset first. The owner is drained and wants the agent to make design decisions, then leave only final tweaks for review. This asset review precedes gameplay integration. No further design questionnaire is needed.

## Implemented draft

Isolated branch `feature/training-arena`, based on `cb8b432`; the active lobby, Inferno, inspect and audio worktrees are untouched. Uses a private local snapshot of six original Slugshot assets: `hub-rock`, `hub-rock-debris` and `rock-wall-4` through `rock-wall-7`. Source hashes are recorded in [evidence](../evidence/2026-11-02-training-asset.json). No new Roblox uploads.

- The island art is scaled 2.25 times its exported dimensions, giving approximately 180 studs across (about 2.6 times the lobby's stated 70-stud spawn). Original Upper/Lower rock and their ink shells remain. The cracked Top and Cracks groups are replaced with a closed, unbroken painted-stone cap; no roots, flora dress, Maelstrom or spiral are included.
- Eight transformed rubble groups create a denser, irregular cloud beneath the island. The walkable island remains still. All motion is static at this design stage.
- The firing side has six marked target distances, 20?120 studs, plus raised and strafe-track target examples. The other side has vaults, a slide gate, four stepping blocks and two long wall-run surfaces. A five-socket console marks the future slug-selection station.
- A 310-stud room radius leaves about 220 studs of empty space beyond the island edge. Sixteen overlapping rock-wall sections and nine ceiling sections enclose the space; simple backing meshes close irregular gaps. Ceiling nominally 205 studs above the island. The draft omits giant wall flora/crystals to keep the room quiet.
- The source mesh GLBs intentionally contain no materials: the builder restores painted color, normal and emissive maps from each source export report, plus charcoal inverse ink shells. Textures are packed into both deliverable formats.

## Inspect it

Local preview: <http://127.0.0.1:8879/> while the loopback server is running. Orbit, zoom and pan; choose Island, Above, Underside, On the island or Room cutaway. The cutaway temporarily hides the near walls and ceiling for inspection; the downloadable asset contains the full enclosure. Auto rotate and Reset work. Rendered views remain available if WebGL fails.

Generated files, all under ignored `build/training/`:

- `SlugshotTrainingArena.blend`: editable source scene with packed textures and named ISLAND/DEBRIS/TRAINING/ROOM collections; room hidden initially in the viewport for easy island inspection.
- `slugshot-training-arena.glb`: complete 3D assembly, Y-up, 1 unit = 1 Roblox stud.
- `island.png`, `above.png`, `underside.png`, `inside.png`: actual Blender renders.
- `qa.json`, `qa-random.png`, `qa-wire.png`, `roundtrip.json`, `browser-review/`: detailed evidence.

Rebuild with the preserved local source snapshot:

```powershell
& C:/Users/runni/slugshot/.tools/blender-5.2.3-windows-x64/blender.exe --background --factory-startup --python-exit-code 1 --python tools/training/build_asset.py -- --source build/training/source --renders
& C:/Users/runni/slugshot/.tools/blender-5.2.3-windows-x64/blender.exe --background --factory-startup build/training/SlugshotTrainingArena.blend --python-exit-code 1 --python tools/training/verify_asset.py
python tools/training/prepare_preview.py
python -m http.server 8879 --bind 127.0.0.1 --directory build/training
```

The six-source snapshot is local; a fresh clone must supply those original exports and painted textures. The preview uses pinned, hash-verified three.js r158 from its MIT-licensed upstream, served locally; [vendor provenance](../../assets/source/environments/training/preview-vendor.json).

## Verification and limits

**Implemented/verified offline:** Blender 5.2.3; all 136 newly authored components pass the installed asset-QA checks, with intentional tiling UV and arena-relative ground-offset warnings recorded. Four actual material renders plus random-color and thin-wire contact sheets were inspected. GLB reimport preserves 247 mesh objects, 808,204 triangles, all materials, 68 enclosure parts and exact aggregate bounds. Desktop WebGL review passes all five view buttons, room visibility, auto rotation and reset; 390-pixel layout has no horizontal overflow or JavaScript exceptions.

**Considering/unresolved:** owner art/scale approval; real Roblox appearance, collision, memory and frame cost. This is a full-detail review asset (approximately 40 MB GLB), not a measured shipping budget. Static props do not yet implement damage, motion, movement scoring, fall recovery or the all-slug selector. Only Floppy currently has a main-branch combat implementation; future training access must use actual implemented species and remain separate from owned inventory. No merge to main or experience publication in this task.

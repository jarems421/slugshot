# Training arena asset

## Revision 2 - rock, runes, rubble and Studio (2026-11-02, current)

**Confirmed:** owner liked the first design and requested plain rock flooring without plants, a running-figure movement rune and target range rune instead of floor lettering, no training wording, adjustable/stationary moving dummies, and more/smaller debris spread around the rim, with a few pieces high enough to see from first person. Most rubble should remain low. Owner requested seeing the distant enclosure in Studio.

**Implemented:** 66 shallow, closed natural-stone surfaces replace the flat green-grey floor. Painted blue-grey rock, chips and restrained stone boundaries; no fungi, roots or glowing fissures. Running and target symbols sit on original standing runestones. All floor text, including distance labels, is removed. Eight original lower rubble groups spread farther out and slightly higher; 16 medium and 32 small additional rocks surround the entire rim, with most below floor level and a few peeking above it. The rest of the layout stays.

The browser review now animates the designated moving target, with a 0-20 studs/s slider and **Keep stationary**. The separate Studio review uses the same motion rule, server-owned speed, a bounded/rate-limited remote, and replicated configuration. **F** opens/closes the controls: slower/faster, Stationary and Reset to 7. Other dummies remain fixed. Zero holds the current position; resume keeps phase. Values describe peak speed along a sinusoidal 10-stud half-width track.

**Studio:** `build/SlugshotTrainingReview.rbxlx` (normal review); `build/SlugshotTrainingReviewCheck.rbxlx` (disposable assertions and camera tour). `python tools/training/build_studio.py` generates an isolated movement-spawn adapter and maps only training art/control scripts. No movement, lobby, combat or foundation source is changed. Existing island/wall/rubble private assets are reused; the new authored model and one paint texture were imported privately for this requested Studio review. IDs stay under ignored `private-assets/training`; the experience is not published. The native review includes the full distant 360-degree walls and ceiling, with restrained wall fills and a shadow-free art-review key so the sealed roof does not black out the island.

Reproduce after building the asset above:

```powershell
python tools/training/import_draft.py
python tools/training/build_studio.py --check
powershell -NoProfile -File tools/training/studio_review.ps1 -Check
python tools/training/build_studio.py
powershell -NoProfile -File tools/training/studio_review.ps1
```

**Implemented/verified:** all 267 authored component QA checks pass; GLB reimport preserves 369 mesh objects, 784,786 triangles, materials and exact bounds. WebGL view/rotate/reset/mobile-width checks pass, including stationary, speed change and button behavior. Training Luau formatting, lint and strict analysis pass. Full movement/foundation verification passes. Real one-client Studio server checks pass 30/120 Hz equivalence, pause/resume continuity and malformed speeds; client tests confirm replicated 0/4/16 changes, actual target motion, stopping, controls presence and rejection of forged 99. Six native camera views were captured after mesh/texture preload and inspected. [Sanitized evidence](../evidence/2026-11-02-training-asset.json), [ADR 0023](../decisions/0023-training-review-and-target-motion.md).

**Unresolved:** owner's final tweaks/lighting verdict; multi-client and mobile performance; fine collision/parkour route validation. This is an art/movement/target-motion review, with full shooting damage and the all-species training selector still to integrate. Earlier draft metrics/choices below are historical. Preview lighting differs between Blender/browser and Roblox, and no final parity approval is implied.

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

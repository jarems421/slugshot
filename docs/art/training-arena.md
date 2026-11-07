# Training arena

## Plain island, organised halves and knockdowns (2026-11-03, current)

**Confirmed (owner):** the lobby must not be visible from the arena, only black; remove the three-wall climb tower and every crystal and mushroom (a plain island for practice); organise the place and improve movement and slug-shooting practice, bigger if needed; dummies flip back on a knockout and stand up again; runes like the slug grove's entrance stones, with small, non-neon symbols (the runner was rejected; wings suggested); a station that matches, nearer the targets; the same glow level as the spawn island; sharper floor with more moss.

**Implemented:**
- A sealed, unlit black shell 520 studs out (black Neon, no shadow, no collision or queries) hides the lobby. Island scale 3.375 to 4.0; every layout item has at least 7.6 studs to the rim.
- Movement on the west: slide lane between low kerbs, vault row (2.6/3.0/3.4), mantle steps (3/4.5/5.5), four jump platforms, a 19-stud wall-run corridor (two 20-stud walls, 56 long) and one solid 16-stud climb block. The three-wall tower is gone.
- Range on the east: a low firing-line kerb, waist-high cover, six still targets at 20-110 studs, two moving tracks (28 and 60), and raised targets on 6- and 10-stud plinths in place of the tower. The station stands on the right of the firing line.
- No rock dressing, crystals or mushrooms; the rubble keeps only its bare rocks.
- Runestones: two cut stones at each half's entrance (tapered, slanted top, one sliced corner), with a small painted, emissive symbol (wings for movement, target for the range) and a fine dark edge, using the lobby's emissive-mask material at strength 0.9. The station is a low stone in the same style.
- Knockdown: the dummy tips back about its base's back edge (0.3 s), bounces, lies, then springs up (1.3 s in all) at full health; a moving dummy holds its place on the track while down.
- Floor and block paint darkened to the spawn island's level (the old paint crossed the lobby bloom threshold); the floor is a 48-stud seamless tile (about 21 px/stud, was about 3) with moss drifts.

**Verified:** Blender build (82 meshes) and private re-import (no publication); authored fit error 0.00. StyLua, Selene and luau-lsp pass. One-client Studio check runs: all checks pass, including the new knockdown checks (falls to an up-vector of 0.10, backwards, back exactly upright at full health), on the first two runs. The final run, started with 1.4 GB free RAM, failed only "moving dummy moves" (the moving-dummy code was unchanged from the passing runs); not re-run, to avoid memory pressure. Captures of the void, runes, station, course and knockdown were inspected.

**Unresolved:** owner verdict on wings, symbol colour/strength, layout and moss; jump gaps and climb height not playtested by hand; multi-client and phone cost.

## Loading screen and touch portal (2026-11-03)

**Confirmed (owner):** touching the portal is enough, even if you stop inside it. A short (about 1.3-1.5 s) Slugterra-style loading screen makes the move noticeable, and becomes the game's loading screen everywhere. The training screen uses a small, petite side-on Floppy hopping along the bar and landing on the goo's front each hop. PvP uses Inferno (the Burpy-inspired slug); Veylume gets no slug until there is a purple one. Every crystal's glow is diffused into the panel with sparkles, in all menus.

**Implemented:** portal triggers on touching the juice (within 3 studs of its middle); you come out 8 studs clear of the far portal and must step away before it can trigger again. Playable design preview: https://claude.ai/artifact/3JUUQvQepbCRhkYNtVKJ8F (private). `Fx.crystalLight` (wide wash plus soft core) now lights the settings menu's and dummy panel's crystals, the dummy panel has twinkles, and the settings menu's halo glow behind the whole panel is gone. One-client Studio check passes all three crossings.

**Implemented (owner approved the comic preview, 2026-11-03):** `experiments/combat/client/LoadingScreen.luau`, a shared module for every future loading screen: `show(place)` returns `covered()` and `finish()`. Places: Training (Floppy), Lobby (Floppy, teal), PvP (Inferno), Veylume (no slug). It is built and its images preloaded when the game starts, and only recoloured when shown. The portal uses it in both directions. The comic slugs are flat-shaded renders of the game models with a silhouette ink outline (`tools/ui/loading/`), uploaded privately with the UI art (`slug-floppy`, `slug-inferno`).

**Verified, one client in Studio:** shown 1.42-1.45 s on every crossing; setup 0.6 ms; captures inspected for Training and Lobby. **Open:** a 0.3-1 s frame from the world move or the arena's first render, sometimes after the screen has lifted on the first entry; Inferno's image was still in Roblox review at upload.

**2026-11-07 (owner: the loading bar's slime very pixelated):** its surface was drawn in columns 6 design px wide, 9 screen px at 1080p, each raised or lowered as a block, and every frame of filling kicked a hit's ripple at its front, so neighbouring columns stood far apart. **Implemented/verified in the training check** (`build/training/check-r11/loading-enter-again.png` against `check/`): `GooBar`'s `fine` option draws the surface in columns about 3 screen px wide (2 to 6 design px by screen size) while the liquid moves as before, and the bar fills with the sliders' steady slosh (`dragged`); the health bar and sliders are unchanged. **Unresolved:** in that check run the first crossings failed before any loading screen showed: the arena was not built in time while the lobby's solid art took 123 s.

**Considering:** background ideas for the loading screen and settings menu (cavern depths, stalactites, glow-cap grove, slug burrows): https://claude.ai/artifact/Uu9gCSbdLQsTSVe1vYEwtH (private).

## Revision 4: void, bigger rock, station (2026-11-03)

**Confirmed (owner):** juice must not spill out of the frame; the portal spiral must start almost at once, and must show on the arena's portal; no walls, only a floating rock in a completely black void; arena 50% bigger, with a bigger movement area; the dummy settings become a physical thing on the map opened with F, almost identical to the settings tab; the settings tab's random balls of glow go; minimal look with no orange and blue lines; less text above dummies.

**Implemented:**

- **Scale and void:** island 3.375x (about 270 studs across). Walls, fills and backing removed.
- **Portal:** juice is six sheets within the pillars' depth, each slightly smaller, so nothing passes the arch. `HubMotion` now emits the spiral on its beat and starts each one with a particle already at peak fading out plus one fading in, so it is whole from its first frame. It restarts on arrival. The arena portal now has its own spiral. Its glow is 0.8 instead of 2.4, with a 1.3x stronger spiral, because it faces the sun, and the training portal's embers are quieter.
- **Station:** stone lectern by the firing line with a `ProximityPrompt` on F (also tap and gamepad). The panel reuses the menu's slime band, drips, `GooBar` sliders, chunky buttons and crystal. It has no glow balls, knob glow, halo or twinkles.
- **Settings tab:** the two wandering pools of light and the panel-wide twinkles are gone; twinkles remain only beside the crystals. Fixed the mojibake on its close button and sprint tick.
- **Dummies:** `DummyBars.client.luau` replaces the old range readout: nothing until hit, then a thin bar and a brief damage number.
- **Layout (`floor.json`):** dummies in one tidy diagonal at 20-115 studs, 2 moving rows, a tower, 2 cover stones. All floor marks, arrows, lines and crystal posts removed; only the two runes glow. Course: 3 vaults, 3 mantles, 4 jump pads, a 19-stud wall-run corridor with 50-stud walls, and a 32-stud wall-jump shaft with a mantle at the top.

**Implemented/verified, one client in Studio:** real W at 35 degrees through both portals, worst frame 26 ms, 18 to 11.7 studs/s; real F opens and closes the panel; forged and valid dummy values; captures of void, juice, panel, settings tab, course and range inspected.

**Not verified:** how quickly the spiral appears on the very first join (the check starts after the arena builds); a real slug hitting these dummies, so the hit bar has not been seen; slider dragging with a mouse; whether the movement stations play well; multi-client; phones.

## Revision 3: organised floor, void, portal (2026-11-03)

**Confirmed (owner):** normal rock and moss floor, no perimeter boulders, more debris visible from the edge, far more black ink, 2-3x the spawn rock, nothing around it, distant cavern walls fading into a black void (owner chose the combination). The floor should look organised and actually help practise movement and shooting, then look Slugterra-esque. Movement and target areas are marked by glowing runestones (running figure, target). Still and moving dummies with adjustable HP and speed. Walk through the lobby portal with a smooth transition, no freeze.

**Implemented:**

- **One place:** `SlugshotLobbyTraining` is the lobby plus the arena 6000 studs away (ADR 0024). A real Roblox teleport needs a published experience and shows a loading screen.
- **Portal:** in `TrainingPortal.client.luau`, a green wash and blur close over 0.32 s, the server moves the player, then it opens over 0.55 s. The way back is a clone of the portal. Falling off returns you to the arrival pad under the same wash.
- **Guns:** the blaster and combat HUD exist only inside the arena. The lobby stays gunless.
- **Layout (`experiments/training/shared/floor.json`):** a spine from the portal, runestones either side.
  - *Shooting (east):* a firing line, 6 still dummies at 15-96 studs each with a crystal distance marker, 2 moving dummies on grooves at 22 and 52 studs, a raised tower dummy at 50, and 2 cover stones to peek from.
  - *Movement (west), following floor arrows:* slide strip, 3 vaults (2.6/3.0/3.4), 3 mantles (3/4.5/5.5), 4 jump pads with widening gaps, 2 wall-run walls, and a 30-stud wall-jump climb. Heights come from the movement limits (vault max 3.6, mantle max 5.7).
- **Controls:** N opens dummy HP (25-500) and moving speed (0-24), with Stop, Sprint and Reset. The server checks values. Readouts show within 70 studs.
- **Art:** `tools/training/build_floor.py` authors the painted floor, mossy stone tile, stations, runestones and dummy, with an ink shell on every piece. Island sides, rubble, side crystals and portal are clones of lobby art at 2.25x. Twelve rubble clusters spread past the rim. Walls are 14 lobby wall sections at radius 820 with their crystals and fungi, fading into near-black fog on the client.

**Portal revision (owner, 2026-11-03: "just a thin sheet ... feels a bit buggy", wants thicker juice and a slight slowdown):** the portal is now a body of juice. Eight fainter sheets make a bulge inside the arch. Within 7 studs of the middle, depth sets both the green and the walking speed (down 35% at the middle). The move happens under full colour at the middle at any angle, and you come out 3.5 studs inside the far portal's juice, keeping heading, speed and position across the opening. The motion check follows the body for 1.5 s after a move: under lag it had thrown a player back to the arena without a gun. Slides and other moves that set velocity directly get the green but not the drag. Verified with a real W key at 35 degrees in one client: 18 to 11.7 studs/s, largest one-frame view change 0.15-0.30. Feel is unverified.

**Implemented/verified, one client in Studio (`tools/training/check.ps1`, disposable):** arena builds in 31-40 s; no gun or HUD in the lobby; both crossings work; worst frame 26-33 ms with a quiet machine, up to 167 ms with another Studio session running; view fully covered about 0.2 s. The trigger detects crossing the portal plane, so a slow frame cannot step over it. Under heavy load the test's own jump to the portal can be undone by the motion check (a test limit; players walk there); the motion check keeps the player in place; gun granted and removed; dummy moves, stops, HP applies, forged speed refused; exit camera faces away from the portal. Selene clean. Captures inspected.

**Not verified:** a real slug hitting these dummies; real input through the portal (the check moves the body directly) and how smooth it feels; whether the slide, vault, mantle, jump and wall-run stations play well; multi-client; phones. The arena adds about 980 parts and the distant walls are unoptimised, so mobile cost is the main risk. Pale shapes at the bottom of first-person captures in both areas are unexplained.

**Reproduce:** build Blender floor, `python tools/training/import_draft.py`, `python tools/training/build_game.py --check`, `powershell -File tools/training/check.ps1`.

Earlier revisions below are historical; their scripts were removed.

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

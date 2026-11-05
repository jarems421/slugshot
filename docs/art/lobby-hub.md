# Lobby hub in Roblox

**Current lava state, 2026-11-03:** owner rejected the material animation's jagged, low-quality appearance. The final full-resolution attempt also failed acceptance and was discarded. Original authored lava colour/normal/glow maps and geometry are restored, with no runtime texture replacement or floating flow ribbons. **Lava is static; the requested waterfall-like animation is not achieved.** Slower diffuse storm changes remain. [Evidence and handoff](../evidence/2026-11-03-lava-quality-rollback.json), [rejected ADR 0026](../decisions/0026-mesh-bound-lava-material.md). Supersedes historical lava success claims below.

The final hub designs built for the game, on top of the approved block-out, whose simple colliders still carry the player. Everything here is look-only. Status: **Implemented, in owner review, 2026-11-01.** Not published. Runtime performance on a real phone is **Unresolved**.

## How it's built

- **Place:** `python tools/lobby/build_hub.py` writes `build/SlugshotLobbyHub.rbxlx` from `lobby-hub.private.project.json`. `--check` adds a short camera check.
- **Models:** `python tools/lobby/hub_mesh.py all <key>` samples each piece from the asset library's own shader, builds a budgeted game mesh in Blender (`blender_hub_piece.py`), and paints every texel from the shader. `python tools/lobby/hub_mesh.py list` shows budgets.
- **Uploads:** `python tools/lobby/upload_hub_assets.py`, private, into ignored `private-assets/lobby`.
- **Ground shape:** `python tools/lobby/hub_mesh.py shape` measures the rock outline, pit edge, lip and fall positions from the art into `experiments/lobby/scale/shared/rim_shape.json`. Re-run it after changing those shapes.
- **Place scripts:** `experiments/lobby/hub`. `HubArt.server` places the art and effects and hides the block-out it replaces. `HubMotion.client` runs all motion and the Detail button.

## Decisions from owner review (Confirmed, 2026-11-01)

- Bridges rest still. Standing on one dips it under your weight with no wobble; only moving on it makes it sway and the boards rock. This replaces the earlier "slight sway at all times".
- Crack mushrooms are really tiny, about 1 to 2 studs, with caps under a stud across. The concept's `tiny = 2` setting holds this.
- The Sky Well's eye and perimeter must look clearly separate from the cavern ceiling: a crown of pale carved stone with runes and a glowing ring, then a dark moat that nothing crosses, then the natural cave ceiling with spires, multicoloured crystals and veins. Moss and hanging vines spread across the whole cave and a little over the crown and the rocks round the eye, with only the moat left bare. `tools/lobby/ceiling_sites.py` generates it at fixed coordinates.
- Every crack is a real V-shaped hole through the top, sharp at both ends: a touch of lit stone at the lip, black walls and glowing azure welling up from the bottom, with mini copies of the standard cyan crystal cluster rooted into the crack walls, alternating cyan and azure, all glowing with a twinkle. `rock_sites.py` only uses a site whose cluster clears the opposite wall and its neighbours. Six spaced cracks at fixed coordinates, with no clumps. No puffs of mist. The dark paint is game-only (`GAME_PAINT` in `hub_mesh.py`), so the library's cracks still glow teal.
- Each fall starts from a round stone basin in one shallow hole in the cliff, full to the brim. Water spills over its whole front edge, covers the stone and falls as one curtain, built from strips that stay flat to the basin rather than turning to the camera. No side streams. The rock columns in its path are left out. Fall angles are fixed constants (`fallAngle` in the shader and `falls` in `hub_mesh.py`). The land reaches out to meet each bridge. Rim bushes have their own detail.
- Waterfalls must read as flowing liquid in the whirlpool's colours, with a visible connection where they land. They are now scrolling sheets with ripples and foam, not a mesh.
- The gun-side symbol is the game's blaster in its own colours, with sharp edges: orange prongs, cyan canister, dark body with the white swirl. The entrance symbol is a jagged stone arch with stalactites, a path and light inside.
- Falls only come from their mouths and melt into the juice at its surface. Lanterns are solid and only move with the bridge. The ground matches the rock and rim you can see. No floating rocks in a bridge's path.
- A Detail button in the place switches between High and Low. A game can't change Roblox's own graphics level.

## Portal side (Confirmed, owner 2026-11-01)

- **Titan's Arch:** the owner picked option D of the [portal plaza options](https://claude.ai/artifact/FwAA7bQqKwejZmXg2PTisg). Its opening was widened so the crater stays framed inside it from the spawn rock.
- **Volcano:** Codex's Ember Crown, study 05 (`docs/art/remaining-concepts.md` and `site-volcano` in the `slugshot-lobby-concepts` worktree, uncommitted there), ported into the shader at 115% (150 studs tall), without the ferns, mushrooms, crystals and moss at its foot. Its centre moves to 268 studs from the hub, backing into the cavern wall.
- **Eruption:** rebuilt because the owner found the old one under-animated: a build-up of spits, then six falling waves of heavy blobs in wide arcs, with a flash and underlit smoke, every 9 to 15 seconds. `HubMotion.client` fires it.
- **Round 2 (owner 2026-11-02):** the arch is now two broken stumps on big fluted pillars with rune bands and a molten slot, so the whole volcano shows and nothing crosses into the neighbouring zones. The arch's lava falls are gone. Rivers are raised, thick and pillowed on their own smooth surface, with rounded lobes and drips, and the crater uses the same lava paint.
- **Round 3 (owner 2026-11-02):** the arch's breaks are blocky masonry, the volcano has more steam in light and dark, and the eruption is switched off in `HubMotion.client` (`ERUPTIONS`).
- **Solid art (Confirmed, owner 2026-11-02):** players should be able to wall-run the mountains, volcano and pillars, with collision skin-tight to the art and no overfitting barriers. Rock, stone, ground, volcano and lava flows now collide on their own meshes (`SOLID` in `HubArt.server`), and the camera stops at them. Hidden stand-ins are removed once this builds, about 6 s after start. Bridges keep their steady hidden planks for footing; decks only stop the camera. Ceiling, debris, foliage, glow and water stay passable.
- **Round 4 (owner 2026-11-02):** the lava pulses slowly, with soft halos brightening in a wave downhill. Portals are one hand-built flat sheet in a solid colour, with a real light on the stones and floor, a faint swirl over the whole surface turning slowly, and sparks drifting off. The volcano's steam is light grey only; the dark smoke was removed (owner). All four gateway symbols are one glowing shape in one colour; the gun was redrawn to read small. Expanding rings were tried and removed (the owner read them as little explosions).
- **Round 5 (owner 2026-11-02):** the crater pool sits just under the rim and is solid to walk on. The streams pour out of it through notches in the rim, sharing one paint across the join, with glints crossing the pool to each spill at the streams' pace. The gun symbol is traced from the real blaster by `tools/lobby/blaster_rune.py`.
- **Ceiling and rubble (Confirmed, owner 2026-11-02):** the ceiling is 25 studs lower, at 225 (`layout.cavern.ceilingY`; `CEILING_DROP` in `HubArt.server` moves its art). The rubble is a short tornado hanging from the storm, from about 120 to 245 studs, wide at the top and thin at the tip. There are 80 more small stones under the spawn rock.
- **Ceiling redesign (owner 2026-11-02, generated by `tools/lobby/ceiling_sites.py`):** the black moat and glowing lines are gone. From the middle out: a collar of small rocks and crystals, the crown, dark paving behind it, two courses of cut slabs with runes on the inner one as the divide, the natural cave, and a border of 12 hanging rune stones, a curtain of hanging rock, crystal clusters and more vines.
- **Storm (owner 2026-11-02):** one solid funnel reaching behind the rock at its rim, with a soft see-through veil over it turning slightly faster. It replaces six flat sheets at different speeds, whose low tongues read as cut-off pieces. Bolts and a local bloom play just under its surface.
- **Floor lava (owner 2026-11-02):** its own part with a repeating 1024 magma map, every 30 studs, about 34 pixels per stud, plus a painted glow on the rock and soft glow beams over the cracks.
- **Sky (Implemented):** a dark sky the colour of the cavern, because the bright default showed where Roblox stopped drawing the far wall.
- **Removed (Confirmed, owner 2026-11-02):** the spiral route, the cave entrance and the climbs to the volcano and mountain that belonged to the route. The owner plans something else there. **Unresolved:** what replaces them; the bounty board is still block-out.

## Roblox versions differ from the concept on purpose

| Concept | Game |
| --- | --- |
| Volumetric storm | Stacked discs of the concept's cloud field, turning at slightly different rates. Lightning brightens the discs themselves. No camera-facing sprite may cross a disc: it gets cut in a straight line, which read as a box |
| Volumetric light | Soft camera-facing Beams |
| Folded juice surface | A smooth funnel that rotates, with folds in its colour and normal maps |
| Falls | Scrolling Beams with wavering edges, ripples and foam at the foot |
| Light rising from cracks | Emission and bloom only, with the painted halo |

## Costs

Latest, after portal side round 2: spawn view about 279k triangles and 171 draw calls; the top-down check views peak at about 317k triangles, 223 draw calls and 127 MB of textures, on an RTX 3070. After solid art: spawn view about 253k to 284k triangles and 160 to 171 draw calls, with mesh memory up from 5 to about 11 MB. After the portal layers and lava halos: spawn view about 279k triangles and 207 draw calls. After the ceiling redesign the spawn view is about 296k triangles and 210 draw calls. The view from under the spawn rock, last measured at about 373k triangles and 227 draw calls, wasn't re-measured. Physics cost on phones is unmeasured. Still no phone evidence.

Measured in Studio on an RTX 3070, before the last two rounds: about 145k to 195k triangles and 80 to 125 draw calls in most views, with the Low setting taking off about 10%. All pieces together are about 270k before Roblox's automatic LOD. Those numbers aren't phone evidence. The last two rounds weren't measured, because Play didn't start from the automated check.

## Mobile check (Confirmed, owner 2026-11-02)

The owner chose an automatic estimate after each lobby or map change, with real phone and iPad tests and fine-tuning once the lobby is complete. Run `python tools/lobby/mobile_check.py` (about 3 minutes): it writes `report.txt` and `sheet-<look>.jpg` to `build/lobby/mobile-check`, and flags budget overruns and jumps of over 10% since the last run.

- **What it does:** real viewports at 844x390 and 1180x820, graphics levels 1, 5 and 10, Low detail as touch devices get, eight views. Game scripts can't set the graphics level, so a small plugin does, on a signal only this check sends; it is installed for the run and removed afterwards.
- **Trust it for:** how things look at phone size, and whether a change made things heavier. Two runs with nothing changed agreed within about 1% on triangles and raised no false jumps.
- **Don't trust it for:** real frame rate, heat or memory crashes. The budgets (200k triangles, 150 draw calls, 100 MB of textures) are starting guesses until a real device run calibrates them. Touch controls aren't shown, and the level numbers are stand-ins for what a real device picks.
- **First results:** textures 135 to 168 MB over the guess everywhere. Spawn about 171k triangles and 130 draw calls at Low detail; Across and Falling are heaviest, about 277k and 226. At level 1 steam and flames mostly go, portals flatten, and the volcano vanishes from across the map. The desktop help panel would cover about half a phone screen, so it must be hidden on touch before the real test.
- **Real device test, later:** `python tools/lobby/build_hub.py --phone` builds the self-running private copy, without the owner's private clips. Publishing it is a manual step in Studio.

## Slug Grove (slug side, built 2026-11-02)

**Complete (owner, 2026-11-03: "Looking perfect").** See the [checkpoint](lobby-checkpoint.md). The `hub-grove-*` pieces (ground, mountain, solid, water, falls, rocks, dress) and five `hub-flora-*` plants come from asset 9 in the library (`tools/lobby/hub_mesh.py`), placed by `buildGrove` in `HubArt.server.luau`: concept origin at the pond (radius 155 at 90 degrees), +z toward the wall. Ground, stones and rune stones are solid as drawn, the mountain through hidden chunks (`hub-grove-solid`), and large mushrooms at their stems; water, falls, plants, caps and crystals are passable.

- **Mountain:** one form of flat triangular faces and hard ridges after the owner's references: `mountainHeight` gives the ridges and each triangle's corners sample it, so the surface is flat faces with no cracks or overhangs. About 165 studs tall and 370 across. Thin black lines and small broken facets are baked onto the flat faces (`rockFacets`), with cut-out shading; the earlier tilted layers read as a contour map and are gone. Players touch `hub-grove-solid`, 24 chunks hidden 0.3 studs under the surface, because one collision shape over the whole mountain bridged its valleys with invisible walls. Its back passes through the wall, so the wall is hidden from 52 to 128 degrees and has no collision from 58 to 122.
- **Ground:** replaces the flat block-out from 40 to 135 degrees, with a basin for the pond.
- **Slugs:** 15 slugs at 1.3 studs, 10 Floppies and 5 Infernos in his base form (owner, 2026-11-03), on 15 of the 30 sites in `experiments/lobby/scale/shared/grove_slugs.json`. `GROVE_SITES` and `GROVE_INFERNOS` in `HubArt.server.luau` choose them: spread out, with the close-up group kept. `GroveSlugs.client.luau` moves them: hops, a drowsy idle up close, and one in four glancing at a player within 15 studs. Inferno hops more often and higher and has his screen-space outline; Floppies stand in if he fails to load.
- **Trees:** all 47 mushrooms, including three in each back corner (`side_trees`), are the approved giant mushroom v2, in teal, green, purple and azure, at 30% glow. Those under 20 studs tall use lighter `mushroom-N-s` copies of about 1,800 triangles; only large stems are solid.
- **Volcano and gate:** Titan's Arch and the volcano stand at 85% height through `PLAZA_HEIGHT`, keeping their width (owner). The volcano's walls between its lava streams rise above the lava, slightly pointed, and its steam is about 25% denser (owner).
- **Plants:** five designs the owner approved (grass, broad plant, lanterns, moonbells, star lily; artifact 5HPDn2SiYnPcvKJyGs58KX), `hub-flora-*`, each a separate prop placed from `grove_flora.json`, 155 in all, the later ones filling the empty ground (`side_flora`). The block-out's sketched overgrowth mushrooms are removed.
- **Crystals:** nine of the crystal assets in cyan, emerald and jade, from `grove_crystals.json`.
- **Cost:** a Floppy is the heavy part, so slugs beyond 130 studs (60 at low detail) aren't drawn. A lighter slug model is the likely fix if phones struggle.

### Grove stream (owner, 2026-11-02)

Unlike the Maelstrom's falls, the grove's waterfall is a thick stream hugging the mountain. `stream_path` in `tools/lobby/grove_sites.py` traces it down the exported mountain mesh, taking the furthest-out rock across its whole width, then pushes nodes out until nothing comes through; rebuild `hub-grove-mountain` before running it. It writes `GROVE_STREAM` and `grove_stream.json`. Motion is two chains of beams node to node in `groveFlow`, each segment one texture repeat, so the pattern runs across joins. It starts inside a rough cave, `groveHole`, and the old gorge cut is gone.

### Grove pond (owner, 2026-11-03)

About 2.5 studs deeper, see-through, with currents spreading from the falls, rings, glints and pads on a swell (`pondLife` in `HubArt`). `GroveWater.client.luau` splashes for each character in the water: a ripple, drops and foam with each step, more at speed, a big splash on landing, and small ripples when standing still. It's look-only. It takes its outline from `pondEdge`, so change both together.

### Whirlpool basins and mushroom glow (owner, 2026-11-03)

The basins' pools have no splash rings; the foam where each fall lands stays. The whirlpool's and spawn rock's mushrooms glow more through `GLOW` in `HubArt`; they are older baked mushrooms, not the giant mushroom asset.

## Costs at the checkpoint

Desktop, grove in view: about 1.3M triangles, 194 draw calls and 266 MB of textures. Portal side: about 182k triangles and 137 draw calls. Measured in Studio on an RTX 3070; not phone evidence.


## Springing exhibition residents ? 2026-11-03

**Confirmed:** owner rejected the low-frame-rate hopping and partial rock support. Residents should compress, briefly build tension, spring forward, and land softly; roam only around the exhibition's pool, mushroom trees and mountain. Passing players should often attract a few brief reactions: blank/drowsy Floppy, smiling or annoyed Inferno. All slugs outside the gun are about two studs, with the loaded scale unchanged. Reducing the resident count is authorized if needed.

**Implemented:** visible position and skeleton presentation run each render frame, replacing the lossy 30 Hz Heartbeat gate. Destination/attention decisions stay infrequent. The hop has 0.24 s compression, 0.07 s tension hold, 0.58 s flight and 0.24 s landing. Idle models avoid redundant whole-model and body-bone writes; detailed faces only run within 24 studs. Existing Floppy face and Inferno grin-to-anger morphs are reused, with a resident-only path that does not start Inferno's display flips/spins.

A nine-contact circular support test checks the whole belly footprint against a gentle plane, rejecting water, steep ground, ledges and rounded tips. Residents are snapped to safe nearby ground, aligned to its normal, and remain inside a 68-stud exhibition radius plus their footprint. Hops stay within seven studs of the supported home. Unsafe sites are omitted if relocation fails. Reactions are limited to three at once, with individual cooldowns; an annoyed Inferno prefers a supported hop away afterward.

`Combat.WorldSlugSize = 2` supplies Floppy and Inferno flight/recovery size and grove scale. Loaded/viewmodel scale and projectile balance values are unchanged.

**Implemented/verified:** native one-client integration checks render cadence, compression/extension, bounded motion, rest contact and player notice; offline combat/movement/foundation and creature checks pass. Reproduce with `python tools/lobby/build_grove_check.py`, then `powershell -NoProfile -File tools/lobby/grove_check.ps1 -OutDir build/grove/review -Timeout 240`.

**Unresolved:** owner motion/face approval, mobile performance and multiplayer observers. Studio texture-service 429 warnings and concurrent Studio load affected this desktop session; frame measurements are evidence for that run, not a claim of steady 60 FPS. The native check is kept out of normal builds.


**Implemented/verified ? final native review:** 14 supported residents (nine Floppies, five Infernos); final authored sites omit the narrow pond rock at site 6. The focused 26-second run measured 1,471 rendered frames and 1,471 animation updates, mean 17.70 ms/frame (about 56.5 FPS), with a 764 ms maximum hitch. It recorded 521 rest-contact samples, squash/stretch range -0.150 to +0.240 and passing-player reactions; bounded motion passed. Earlier background runs were about 15 FPS. [Sanitized evidence](../evidence/2026-11-03-grove-spring-motion.json). This verifies display-frame cadence and native behavior, not an uninterrupted 60 FPS or owner approval.


**Owner revision, 2026-11-03 - body-only splat:** supersedes the weaker landing above. Takeoff now compresses to 0.36 over 0.30 s, holds tension 0.10 s, extends into 0.58 s flight, then compresses to 0.50 on contact and recovers over 0.38 s. Existing Floppy lower-body spread bones add a small bulge. No landing slime or floor wetness is introduced. Floppy's canonical private model now has the flat folded sole and two underside spore patches requested to match Inferno. Native staged-asset review passes for both species, 14 residents and 1,274 animated/display frames, with 414 rest contacts. [Evidence](../evidence/2026-11-03-floppy-flat-sole.json). Owner feel/art review remains open.


**Implemented/verified, 2026-11-03 - actual upward gaze:** corrected resident head-axis signs (and Inferno's resident basis) so both heads physically tilt upward rather than merely entering a look state. The new native check reads each head bone's transformed facing, visits both species, and measures about 12.6 degrees Floppy / 23.3 degrees Inferno upward. Focused run: 1,562 animation/display frames, mean 16.67 ms, maximum 31.72 ms; 524 rest contacts and both landing peaks pass. [Current evidence](../evidence/2026-11-03-settings-and-final-review.json).


**Implemented/verified, 2026-11-03 - canonical flat-sole review refresh:** the open old GroveReview referenced the rounded asset even though the SplatReview/canonical config had the flat sole. `python tools/lobby/build_grove_review.py` now rebuilds the single canonical review, checks embedded config source freshness and includes review-only imported-body bounds validation. All nine Floppies pass at roughly +0.0051 studs above their root. Existing texture folds/spores remain; no added curling or new geometry. Current training's saved asset reference was already correct and was preserved. [Evidence](../evidence/2026-11-03-floppy-lobby-refresh.json).

### Floppy look-up greeting revision - 2026-11-03

**Implemented/verified locally:** Floppy reactions now have their own two slots, reliable nearby notice, shorter cooldown and a stronger height-tracking head tilt. Watching a nearby resident also qualifies. Floppies always smile and lower the jaw a little, then return to hopping. Native head/mouth/boundary/contact/cadence checks pass; owner feel approval remains open. [Evidence](../evidence/2026-11-03-floppy-greeting.json).

### Slow lava and diffuse storm flashes - 2026-11-03

**Confirmed:** owner wants slight downhill lava motion like a slower mountain waterfall, and storm light flashes without solid lightning bolts. **Implemented/verified locally:** increased the existing twenty lava ribbons from 0.07 to 0.28 texture speed (waterfall 1.5/2.3). Removed the Zap emitter and its client emission; retained cloud emissive flashes and a wider, fainter, slightly longer-lived bloom. Its placement is lower to prevent surface clipping. Full native tour checks downward flow and no bolt emitter. [Evidence](../evidence/2026-11-03-lobby-lava-storm.json). Owner motion verdict remains open; no asset upload/publication.

### Owner correction: visible viscous lava and slower storm - 2026-11-03

**Confirmed:** the first glint-speed adjustment still did not read as flowing lava, and storm flashes were too frequent and brief. **Implemented/verified locally:** lava now uses the mountain waterfall's full streak texture with warm orange tint and surface-aligned Wrap ribbons at 0.4 speed, versus waterfall 1.5/2.3. A low-emission alpha-colour layer keeps movement readable over the glowing mesh. Storm intervals are 5-9 seconds; cloud glow rises over 0.2 seconds and dissipates over 1.2, with 1.2-1.6-second soft blooms. Native cadence/flow checks pass. Saved the old review before rebuilding; canonical builder now verifies compiled effect sources as well as private model references. [Evidence](../evidence/2026-11-03-viscous-lava-and-slow-storm.json). This supersedes the earlier sparse-glint lava pass; owner feel approval remains open.

### Lava visibility repair: actual slow surface flow - 2026-11-03

**Confirmed:** owner screenshots still showed static lava and requested a very slow gloop with fixed geometry. **Confirmed root cause:** the flow had one beam segment while its fade was transparent at both ends; the visible middle was never sampled. Earlier speed/texture changes therefore could not appear. **Implemented/verified locally:** twelve segments render the fade; use the waterfall's actual flowing body texture, cover all seven streams at full width/length including wider lower sections, and scroll at 0.22 versus waterfall body 1.5. Native texture loading/reference, fade visibility, seven-stream and close-up time-sequence checks pass. Storm timing preserved. [Evidence](../evidence/2026-11-03-visible-lava-gloop.json). Owner gloop verdict remains open; earlier visual claims are superseded by this diagnosed repair.


## Zone strips, ring edge, pylon tops, shop and mountain (owner, 2026-11-04)

**Owner:** the stone slabs between biomes should be clean, connected dark stone lying on the boundary, not loose grey flagstones on one biome; the gun side's purple crossed into the ring between the bridges and the biomes, which no other biome does (only the cobble path may cross it); the pylon crystals were too small, then, after seeing them bigger, **remove them and leave the pylon tops bare**; extend the shop's main (bottom) pod backwards to fill the platform; the grove mountain looks low resolution close up.

**Implemented/verified in a one-client Studio camera tour (`build_hub.py --gun`, `gun_check.ps1`):**

- **Zone strips:** `chZoneSlab` is now a row of four flush dark slate slabs (8 by 24.75 studs, 0.3 studs proud, 0.2-stud joints, small bevel, painted ids 125/126). `zoneSlabs` lays eight rows end to end on each line from 104.5 studs (the rim art's edge) to the wall, every other row turned end for end. The lines sit where the grounds meet: -40.8 and -135.25 degrees (where the purple now stops), 41.05 (the middle of the grove/portal floor overlap) and 135. Measured on screen: slabs about (55, 55, 65) against the portal floor's (34, 27, 37), after a first pass at (80, 77, 103) read mid-grey.
- **Ring:** the hub's rim art runs from the pit to 104 studs (`RIM_WIDTH` in the block-out); the purple started at 102 and its raised velvet lay over the ring's edge, while the flat portal floor stayed hidden under it. `chWedge` now starts the gun side's ground at 104.5 and ends it on the zone lines; the path (`hub-gun-path`) still crosses the ring.
- **Pylons:** crystals and their lights removed; the tops are bare.
- **Shop:** the main pod is stretched 1.6 units (8 studs) behind its middle (`chPodLocal`, `CH_POD_BACK`), so its back reaches 22 studs behind the centre instead of 14; the door, sign and front windows are unchanged, and the seam paint uses the same shape.
- **Mountain:** Roblox shrinks every map to 1024, and 38% of the old maps' area was the flat underside under the ground. The mountain is now thirteen blocks of about 11,000 visible square studs (`GROVE_BLOCKS` in `hub_mesh.py`) plus a small `MountainBuried` part, packed by island outline (`pack`), painted at 2048 and averaged to 1024 (`supersample`). Measured: 6.6 to 8.3 texels a stud on every visible block, from 2 (peaks) to 4 before; the painted lines have smooth edges instead of pixel steps. Triangles about 25k (was 22.5k), 14 colour and normal maps at 1024 (was 4 at 2048).

**Unresolved:** owner verdict; very close up the mountain is smoother and about twice as sharp but still soft. Crisp lines at any distance would need the ridge lines as geometry, or more maps. Grove flora placed against the old mountain mesh wasn't re-audited (same shell, re-decimated in more parts). Phones and texture memory weren't measured. The far side (135 to 225 degrees) is still block-out ground beside its strip.


## Far side cave and the cavern wall (owner, 2026-11-04)

**Owner:** the lobby's last two pieces are a cave on the far side and the walls. Walk to the edge of the ring, it's a cliff, and you look out into a misty cave you can't enter. **Confirmed** from the [plan](https://claude.ai/artifact/RrouNnPUQBZHGGttm6SG6B) ([source](far-side-plan.html)): cave option B, a great mouth in the wall, made quite big; wall option 1, the approved rock wall's stacked masses; an invisible barrier over the whole mouth, so wall-running its edge can't get anyone in; the canopy hole's layered mist. No reference picture yet; the owner may send one, otherwise the agent designs the cave. Everything is an artifact first, from our own assets, and any new extra is designed on its own and shown beside the composite (owner).

**Implemented as library studies** (`docs/art/asset-library.html`, assets 16 `far-cave` and 17 `cave-spire`):

- **Mouth:** an even, slightly squared arch 280 studs wide and 185 high on the far bridge's line (180 degrees), framed by big masses of the same rock, open below the floor so the cliff drops straight into the cave. The far side's floor stops at a cliff about 288 studs out, with a low broken rim of up to 2 studs.
- **Wall (option 1):** the approved rock wall v6's chunky masses at cavern scale (about 25 studs across), in rows to the ceiling, five in twelve with its carved cracks, its paint and moss; the approved crystal clusters and the hole's small glowing mushrooms on them, and its bead vines hanging from the mouth's head.
- **Cave:** a hall widening and rising past the mouth, about 380 studs deep, full of the hole's five drifting mist layers below the cliff plus two thinner ones higher up, a haze hiding the bottom and far end. Options: A bare spires, B crystal spires (approved cyan and violet clusters), C mushroom depths (giant mushrooms rising through the mist, bead vines from the hanging spires). **Agent's pick:** C.
- **Cave spire (new asset):** first stacked rounded masses; **owner, 2026-11-04:** sharp and jagged, like the mountain. Now built the mountain's way round its own axis: one pointed form, winding star ridges, flat triangular faces in their own shades, thick ink on ridges and valleys, stepped light, moss in patches. Rising or hanging; 35 to 60 studs across where they leave the mist.
- The study shares the canopy hole's pieces by compiling asset 15's block into 16 and 17 (`#if ASSET >= 15`); the hole and rock wall still render as before (regression stills checked).

**Owner, round 3 (2026-11-04):** the spires had too many thick black lines running straight down them, which added little; **Confirmed:** option C, mushroom depths. Split the study so each piece can be looked at on its own. **Implemented:** no ridge or valley ink on the spires (paint lines removed and the renderer's crease off for id 132); thin lines on about one face edge in five, plus the outline. Three pages: [cave spire](https://claude.ai/artifact/Rd4tzdc4jwnGj3hDrh66ax) ([source](cave-spire.html)), [cavern wall](https://claude.ai/artifact/KdgpejJ9tavykNd21oSj5c) on its own with the mouth closed (`uPlaza` 5; [source](cavern-wall.html)), and [the cave and mouth](https://claude.ai/artifact/Ggdo5sXqcyxQWz7SajHiap) in option C with views from the lobby, its roof lifted off (`uPlaza` 3) and cut in half (`uPlaza` 4), keeping only a rock shell about 35 studs thick round the cave ([source](far-side-cave.html)). The cave now has a floor about 300 studs down, under the mist. [Renders](evidence/far-side-cave/).

**Owner, round 4 (2026-11-04):** the walls look too basic, too rounded and the same everywhere; the spires are too spirally, like narwhal tusks. **Implemented:** spires with straight ridges, each ridge's depth on its own pattern up the spire (a pattern shared across angle and height wound round as a helix), faces in zigzag rows with each square split on its own diagonal (one shared diagonal lined the edges into a slanted grain), a lopsided outline, two stepped shoulders, a slight lean, a smaller fused shard on most, less moss ([spire page](https://claude.ai/artifact/Rd4tzdc4jwnGj3hDrh66ax)). The round 3 masses are replaced by two new wall options, each on its own with the mouth closed ([wall page](https://claude.ai/artifact/KdgpejJ9tavykNd21oSj5c)): **A broken blocks** (`fcBlocks`: fractured slabs of two sizes, tilted, standing out by different amounts, a corner snapped off) and **B fused crags** (`fcWallCrags`: the cave spire half sunk into the wall in a front row, a taller back row reaching the ceiling, and crags hanging from it). Both carry the approved crystals, set on the real surface. A third, wedge buttresses, was dropped internally: it rendered as big plain slabs. The cave page still shows the round 3 wall and spires until the owner picks a wall.

**Owner, round 5 (2026-11-04):** the spire is too uniformly coney. The owner is now on a different Claude account and couldn't open the wall page, so both pages are republished from that account: [spire](https://claude.ai/artifact/Rd4tzdc4jwnGj3hDrh66ax), [wall](https://claude.ai/artifact/KdgpejJ9tavykNd21oSj5c). The earlier cave and plan pages belong to the old account. **Implemented:** width from random control heights with hard kinks and a short broken top on a broad body; each tier a flattened blade turned its own way; three steep fracture planes that shear the flanks and move the summit off-centre, and two V notches (`fcSpireCuts`); a stronger lean. The study gains a lineup of different spires. The wall's fused crags inherit the new spire, slimmer and closer together so they break up. Flecks are finer and moss only sits on what faces up. **Limit:** faint contour-like bands remain on some of the fused crags' big flat faces; cause not found.

**Owner, round 6 (2026-11-04):** the spires look too flat, detail on two sides and the other two plain; the wall should be a mix of A and B with more textures; the crystals weren't ours. **Implemented, replacing the earlier options above:** spire breaks (five shears, seven gouges, spread evenly round it) are worked into the faces' corners (`fcSpireBreaks`), not cut as big planes, with more and smaller faces and a near-round section; checked from four sides. The wall is one mix: broken blocks as its body, crags bursting through in long uneven stretches (`fcCragMask`), taller shards behind and hanging ones above, and the arch framed by broken blocks. Rock paint (`fcRockTex`) uses only approved textures: mottling, grain, the mountain's small facets, worn edges, crevice grime and hatching, inked cracks with a pale lip, moss; lichen, pockmarks and veins stay rejected. Crystals are the approved Cyan cluster and Violet spire layouts and colours without pedestals (`fcOurCrystal`), replacing the canopy hole's `chCrystal` here. Pages: [spire](https://claude.ai/artifact/Rd4tzdc4jwnGj3hDrh66ax), [wall](https://claude.ai/artifact/KdgpejJ9tavykNd21oSj5c), [cave and mouth](https://claude.ai/artifact/Ggdo5sXqcyxQWz7SajHiap). **Verified:** the canopy hole and rock wall render pixel-identical to the check stills taken earlier this round of work, after the first cave splice (one low-resolution still of each). **GPU:** the heavier scene caused `nvlddmkm` event 153 engine resets at 21:58 to 22:00; with a lighter scene and `LOBBY_BANDS=160` in `render_still.py`, all later renders logged none. **Unresolved:** owner verdict on all three; the wall will need simplifying for the game; the far side's floor; the Roblox build (barrier, wall round the circle, phone cost).



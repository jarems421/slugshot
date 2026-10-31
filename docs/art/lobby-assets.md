# Lobby asset plan

The props and kits the lobby needs, to be authored in Blender so the space looks deliberately designed and hand-made, not assembled from generated or free models. Every asset follows the [style guide](style-guide.md); the order of work follows the [lobby roadmap](lobby-roadmap.md).

Research basis: [Slugterra environment research](../research/slugterra-environment.md).

Source: owner request, 2026-10-31 ("build some assets in Blender so that stuff just doesn't look like AI slop… plan out what different assets we're going to have around the lobby… stuff like the Slugterra mushrooms, which are very distinct"). **Status: the list is Considering.** The owner confirms, cuts or adds items before production. Each asset's own design is agreed at concept stage.

## Originality rule

Slugterra is the reference for **categories and atmosphere**: giant glowing cave fungi, huge crystals, hideouts built into rock, slug habitats, glowing caverns. Every Slugshot asset is an **original design** in that category with its own silhouette, proportions and details. Never trace or copy a specific show prop. Each asset's note records its references and how ours differs.

## Asset library (live 3D concepts)

Owner request, 2026-10-31: every asset is first agreed as a rotatable 3D concept in the private [asset library page](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr), the same workflow that settled Floppy. Source: [asset-library.html](asset-library.html). Each concept is defined in that page as exact signed-distance maths, so the Blender build (`tools/lobby/build_vignette.py`, first pass, paused until concepts are agreed) reproduces the agreed forms. Republish the same file to keep the URL, and add each new asset to it.

## Production standard (every asset)

1. **Concept first.** Agree a concept or blockout with the owner for distinctive assets: a rotatable concept, quick Blender blockout renders, or an in-Studio blockout.
2. **Shape:** rounded, exaggerated, chunky, with a clear silhouette ([style guide §3](style-guide.md#3-shapes-and-forms)).
3. **Ink:** outline method and weight chosen per the style test: thick for hero/interactable, thin for architecture, lightest for background.
4. **Paint:** stylised colour map with painted variation and interior ink lines, plus normal/roughness where useful. Colours follow the calm-base/accent rule; the accent is used only where attention belongs.
5. **Modular where it repeats:** a shared grid, sensible pivots and seam-free joins for walls, floors and platforms.
6. **Budgets:** triangle, texture and material budgets are set in Phase 1 from measured Studio cost. Reuse texture atlases and trim sheets across kits.
7. **Motion, if any:** calm and slow ([style guide §6](style-guide.md#6-life-and-motion)).
8. **Checks:** Blender asset QA (normals, scale, floating parts, UVs), export through the Roblox pipeline, Studio screenshot at third-person and low graphics, then owner review.
9. **Files:** editable source in `assets/source/<category>/<asset-name>/`, exports in `assets/exports/…` per [asset conventions](../assets.md). Generated builds stay in ignored `build/`. Upload IDs stay in ignored private storage.

## Phase 1 vignette set

Built first, at first-pass quality, for the [style test](lobby-roadmap.md#phase-1-style-test-vignette).

| Asset | Notes |
| --- | --- |
| **Rock wall module** | Chunky, rounded cave rock with large readable fracture planes and painted ink lines. Tests how ink reads on big natural surfaces. |
| **Crystal cluster** (one medium) | Faceted, clean shapes with a glowing core. Tests glow, bloom and outlines on emissive surfaces. |
| **Giant cave mushroom** (one hero) | The owner's named Slugterra-type centrepiece prop. Tall characterful stem with a broad glowing cap and underside gills or ribbing. Tests organic shapes, glow and soft sway. |
| **Portal frame** | Cartoon-industrial frame (chunky metal and stone) around an energy surface. Tests the hero accent and interactable outline. |
| Blaster, Floppy | Existing assets, reused as-is for scale and cohesion. |

## Full lobby list

Priority: **P1** = vignette, **P2** = needed for a complete lobby, **P3** = dressing and life that adds richness.

### Landmarks

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Floating spawn rock | P2 | Rock island hovering above the Maelstrom in the Sky Well's light, flat walkable top facing the PvP gate, roots/moss/vines trailing beneath, chunky ink lines. |
| Four bridges | P2 | Forward (portals), back (entrance), left (gun side), right (slug side). Each widens onto solid mainland. Owner's current preference (2026-10-31, not final): **droopy wooden suspension bridges**, with sagging plank decks hung on rope or cable, chunky posts and ink-lined timber. Invisible barriers along both sides. |
| Mainland shoreline | P2 | The solid land wrapping around the sinkhole where every bridge lands and the terrain and biomes begin. |
| Maelstrom | P2 | Sinkhole of glowing water spiralling down: layered spiral meshes with animated textures, rim rocks, rising mist. |
| Sky Well | P2 | Ceiling opening far above, with a fake volumetric light column (layered meshes/Beams) and slowly drifting floating rocks trailing moss and vines. |
| PvP gate | P2 | Straight ahead of spawn and the grandest gate. Warmer, more dramatic frame with orange energy. |
| Training gate | P2 | Left of PvP. Cool, clean, practical frame. |
| Veylume gate | P2 | Right of PvP; the exploration world. Mysterious: overgrown, sealed or dormant, hinting at the biomes beyond. Green/teal/violet glow. |
| Portal frame | P1 | Base design that the three gates vary from. Confirmed 2026-10-31: each gate has a symbol on the keystone gem (PvP crossed swords, Training target, Veylume map; symbol in grey metal) and its own colour for the energy, gem and bolts: **PvP orange, Training green, Veylume purple**. |
| Entrance | P2 | Behind spawn, on the far side of the round hub from PvP. |
| Gate signage | P2 | A large painted sign over each gate, readable from spawn. |

### Cavern kit (natural)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Rock wall modules (straight, corner, overhang) | P1→P2 | Main surface of the cavern. Big soft forms with ink fractures. |
| Floor slabs and ledges | P2 | Walkable rock with chunky edges; small height steps. |
| Boulders and rock clusters (S/M/L) | P2 | Break up edges and frame paths. |
| Stalactites and stalagmites | P2 | Sell the scale and the "ancient cavern". Exaggerated tapers. |
| Ceiling and backdrop rock | P2 | Distant cavern shell, lightest ink, low detail. |
| Crystals: fourteen designs in fourteen colours (owner, 2026-10-31) | P1→P2 | Main vibrant accent and light source. A few clear crystal varieties, each with its own glow family. |
| Water feature: pool, drip or small waterfall | P3 | Calm movement and sound. Considering. |

### Fungi and flora (Slugterra-category, original designs)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Giant cave mushrooms (2–3 distinct silhouettes; any colour from the 14-colour mushroom bank) | P1→P2 | Signature environment prop. Glowing caps, characterful stems. Some tall enough to canopy paths or act as platforms. |
| Mushroom clusters (small; each mushroom a random colour from the 14-colour bank) | P2 | Ground dressing around rocks and paths, glow in clumps. |
| Shelf fungi on walls | P3 | Bracket fungi on rock faces, small glow spots. |
| Glowing moss and lichen patches | P2 | Soft colour on rock; may be texture/decal rather than mesh. |
| Hanging vines and glow-bulb plants | P3 | Vertical life from the ceiling; gentle sway. |
| Bioluminescent ferns, grasses and pods | P3 | Low ground flora with subtle sway and pulse. |

### Outpost kit (cartoon-industrial)

Ties into the blaster's chunky orange/graphite/steel language.

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Platforms and decks (metal and plank modules) | P2 | Hand-built floors on top of rock. Oversized bolts and thick bevels. |
| Railings, stairs and ramps | P2 | Chunky, readable, slightly irregular. |
| Rope-and-plank or metal bridge | P3 | Spans a gap between rock areas. Considering. |
| Doorway/hatch set into rock | P2 | The outpost "carved into stone" look. |
| Pipes, valves and fittings kit | P2 | Run along walls and ceilings; tie zones together. |
| Warm lanterns and lamps | P2 | The amber pockets of light around inhabited areas. |
| Workshop bench and tool rack | P3 | Lived-in detail, possibly with a blaster on the bench. |
| Blaster display rack | P3 | Accent showcase prop. |
| Slug habitat (terrarium or nest) | P3 | Where lobby Floppies rest. Accent glow. |
| Slug canister stack and cases | P3 | Ties to the blaster's slug canisters. |
| Crates, barrels and supply sacks | P3 | Generic dressing, made in the house style. |
| Signs and wayfinding boards | P2 | Point to Training, PvP and Exploration. Painted, readable from spawn. |
| Training targets | P3 | Clean, readable targets for the training zone. Non-functional until combat is approved. |

### Slug exhibition (owner-requested)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Display habitats (terrariums) | P2 | Glass and chunky-metal enclosures, each a miniature biome (moss, crystal, water) with a slug inside. Floppy first; more as slugs are made. |
| Glowing pond | P2 | Owner-confirmed. A shallow luminous pool where wild Floppies rest among giant mushrooms and glowing plants. |
| Plinths and info plaques | P2 | Name and short description per slug; painted wood/metal frontier style. |
| Slug canister wall | P3 | Rows of glowing canisters, as if slugs are stored ready for slinging. |
| Specimen jars and field-notes desk | P3 | A naturalist's corner: sketches, magnifier, jars. Original look. |

### Gun exhibition (owner-requested)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Blaster display stands | P2 | Turning plinths or wall mounts showing the blaster and future variants, lit like museum pieces. |
| Slug workshop | P2 | Owner-confirmed. A Slugterra-esque slug-tech workbench, **not a real blacksmith forge**: the heat or glow comes from slug energy or crystals, with chunky hand-built tools and a half-built blaster. The gun area's "made here" story. |
| Parts rack and crates | P3 | Barrels, springs and canister parts in the blaster's orange/graphite/steel. |
| Test target stand | P3 | One small target beside the display. Decorative until combat is approved. |

### Frontier flavour (research-led, Considering)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Bounty and duel board | P2 | Owner-confirmed. Near the PvP gate: posters, pinned notes, later leaderboards. |
| Hitching posts, benches and porch fronts | P3 | Frontier-outpost shapes on the built structures. |

### Terrain features (owner-confirmed, high interest)

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Spiralling cavern kit | P2 | Passages, arches and ledges that spiral around and above the hub. Built from the rock kit plus large sweeping hero pieces. |
| Little volcano | P2 | Stylised, chunky cone with ink fractures and a glowing crater. Faint smoke or embers (calm, slow). |
| Lava ravine | P2 | Deep ravine with lava pouring down its walls into a glowing channel. Needs stylised flowing lava (animated texture or emissive mesh), cooled-crust edges and warm rim lighting. Cost check in Studio. |
| Waterfall mountain | P2 | Small mountain with a stylised waterfall (animated texture), mist, and Slugterra-type greenery: giant mushrooms, vines, moss, glowing plants. |
| Slug murals | P3 | Owner-confirmed. Original slug carvings or paintings on cavern walls, done as texture or relief. |

### Slug-energy technology

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Energy conduits and pylons | P2 | Pipes with glowing windows carrying slug energy to gates and lamps; connects tech to the world's glow. |
| Energy lamps | P2 | Lamps that look powered by creature energy (a glowing core in a cage), not electric bulbs. |

### Biome hints

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Biome-specific flora sets | P3 | Small groups of plants and rocks from future map biomes (frozen, crystal, water, overgrown), mostly around the Veylume gate. Built once the map's biomes are defined. |
| Cavern backdrop vista | P3 | A low-detail distant cavern beyond an overlook, showing layered biomes and scale. |

### Life and ambience

| Asset | Priority | Role and design notes |
| --- | --- | --- |
| Lobby Floppies (resting/idle placements) | P3 | Existing Floppy with calm idle; placed on rocks, habitats and benches. |
| Glow particle textures (motes, spores, fireflies) | P3 | Painted soft sprites in the accent families. |
| Plant sway and crystal pulse setups | P3 | Slow, subtle motion. |
| Ambient sound list | P3 | Drips, hums, distant water, creature chirps. Sourced and licensed separately. |

## Open questions for the owner

- Which items to cut, add or promote, in particular further Slugterra-category props you have in mind.
- Should the giant mushrooms be climbable or walkable, or purely visual? (Movement interaction would touch the separate movement work.)
- Bridge style: leaning toward droopy wooden suspension bridges; confirm at the greybox/style test.

# Lobby roadmap

How the Slugshot lobby goes from plan to finished space. Each phase ends with an owner review, and the next phase does not start until the owner is happy. The look follows the [style guide](style-guide.md); the props come from the [lobby asset plan](lobby-assets.md).

Source: owner's pasted art-direction chat and requests, 2026-10-31. **Status: Confirmed** that the lobby should be planned, assets authored in Blender, and the look tested before the full build. The gate, spawn and entrance arrangement is **Confirmed**. Exact dimensions and the extra areas are **Considering**. Environmental research: [Slugterra environment research](../research/slugterra-environment.md).

## Concept

**Confirmed direction:** not a generic Roblox lobby with three portals in a flat room. The lobby is **a small underground Slugshot outpost nestled inside a larger, ancient cavern**. Natural cavern walls and giant glowing growths surround hand-built platforms, chunky metal fittings, pipes and little workshop areas, lit by warm amber pockets.

### Layout

**Confirmed by the owner, 2026-10-31.** This is the arrangement only; distances and sizes are still open.

**Shape: a round, roughly octagonal hub** (owner, 2026-10-31). The areas sit around a circular central plaza, like the faces of an octagon, though not necessarily eight of them.

```
                 [Training]     [PvP]     [Veylume]
            ~~~~~~~~~~~~ portal mainland ~~~~~~~~~~~~
                               |
                            bridge
                               |
  [Gun exhibition  ]           |           [Slug exhibition]
  [+ slug workshop ]=== bridge (SPAWN) bridge ===[+ glowing pond  ]
  [   mainland     ]           |           [    mainland    ]
                            bridge
                               |
            ~~~~~~~~~~~~ entrance mainland ~~~~~~~~~~~
                          [Entrance]

  (SPAWN) = floating rock in the light column, between the Sky Well
  above and the Maelstrom sinkhole below. All four bridges land on
  solid mainland that wraps round the sinkhole, where the terrain and
  biomes are built: spiralling caverns, volcano, lava ravine,
  waterfall mountain.
```

- **Central spawn point:** a **floating rock** hovering above the Maelstrom sinkhole and below the Sky Well, in the light column (see [centrepiece](#hub-centrepiece-sky-well-and-maelstrom)). Players face the PvP gate when they spawn.
- **Four bridges** from the spawn rock, owner-confirmed 2026-10-31:
  - **forward** to the mainland holding the three portals;
  - **back** to the entrance;
  - **left** to the gun exhibition side;
  - **right** to the slug exhibition side.
- **Bridges land on solid mainland, not small platforms.** Each one opens out into broad land that wraps around the sinkhole, and the terrain and biomes grow out from there. The round/octagonal shape is the sinkhole and the mainland shoreline around it.
- **Bridge style:** the owner is leaning toward **droopy wooden suspension bridges** (sagging plank decks on rope). Not final; confirm in the greybox.
- **Invisible barriers** along the bridges (and the sinkhole edge) so players cannot jump or fall off. Owner-confirmed 2026-10-31.
- **PvP gate** straight ahead.
- **Training gate** immediately left of PvP.
- **Veylume gate** (the exploration world) immediately right of PvP. The mode comes later, so the gate stays visually mysterious, sealed or dormant for now.
- **Entrance** behind spawn, on the opposite side from PvP: the way into the whole lobby.
- **Slug exhibition area** and **gun exhibition area** on the ring's flanks: guns on the Training side, slugs on the Veylume side. The owner confirmed this as "basically right".
- **Surroundings:** Slugterra-type natural terrain and structures all around, with dramatic terrain features (below). See the [research](../research/slugterra-environment.md) and [asset plan](lobby-assets.md). The owner wants it to look really cool.

The wider game map is planned as different biomes merging together. The lobby can hint at those biomes, especially around the Veylume gate.

The lobby does not need matchmaking or progression systems at first. It can connect to them later. Combat, matchmaking, progression and exploration remain unapproved systems; gates can be non-functional set pieces until those are requested.

### Name for the exploration world

**Confirmed, 2026-10-31: Veylume** (owner-typed spelling). The owner rejected "exploration world" as too generic. Voice dictation may render it "Veilume" or "volume".

### Extra areas

**Confirmed by the owner, 2026-10-31:**

| Area | Notes |
| --- | --- |
| **Bounty and duel board** | Near the PvP gate. Decorative until progression is approved. |
| **Slug workshop** | Next to the gun exhibition. Must look Slugterra-esque, **not like a real-world blacksmith forge**: a fantasy slug-tech workbench whose "forge" glows with slug energy or crystal heat, with chunky hand-built tools and blaster parts. |
| **Glowing pond** | Next to the slug exhibition: a shallow luminous pool with wild Floppies resting among giant mushrooms. |
| **Slug murals** | Original slug carvings on the cavern walls. |

**Terrain features: confirmed, and the owner's main interest.** Most of the "extra stuff" should be dramatic natural terrain around the hub:

| Feature | Notes |
| --- | --- |
| **Spiralling caverns** | Cavern passages and ledges spiralling around and above the hub, giving height and depth. |
| **Little volcano** | A small stylised volcano with a glowing crater: a warm landmark, likely on the PvP/warm side. |
| **Lava ravine** | A ravine with lava pouring down its walls, flowing into a glowing channel. |
| **Waterfall mountain** | A small mountain with a waterfall and Slugterra-type greenery: giant mushrooms, vines, glowing plants. A cool, calm counterpart to the volcano. |

Colour balance: lava and volcano glow are hero accents. Keep the surrounding rock dark and calm so they pop without making the scene loud ([readability check](style-guide.md#readability-check-ask-of-every-scene)).

### Hub centrepiece: Sky Well and Maelstrom

**Confirmed by the owner, 2026-10-31** ("an opening above and that pit below… would look sick"). A dramatic natural feature, unique to the hub, made of two halves on one vertical axis:

- **Sky Well (above):** a huge opening in the cavern ceiling far overhead. A column of soft light pours straight down onto the centre of the hub, and chunks of rock float slowly inside it, trailing moss, vines and drips. It sells how deep underground the lobby is.
- **Maelstrom (below):** a sinkhole in the middle of the hub, with glowing water spiralling down into the depths. Mist rises off it, catching the light from above.
- **Spawn:** a floating rock in the light column, between the Sky Well and the Maelstrom. Four bridges lead out to solid mainland: forward to the portals, back to the entrance, left and right to the exhibitions.

Design notes:

- The spiral of the Maelstrom echoes the spiralling caverns around the hub.
- Lighting: the light column is the hub's calm key light. The water's glow lights the floating rock's underside and the bridges from below.
- Colour: keep both halves in calm, cool tones so the gates, lava and exhibitions stay the accents ([readability check](style-guide.md#readability-check-ask-of-every-scene)).
- Motion: slow swirl, slow drifting rocks, gentle mist; calm, never busy.
- Roblox technique to prove in Phase 1 or 2: a fake volumetric light column (layered transparent meshes or Beams, plus Atmosphere and bloom), swirling water (animated textures on layered spiral meshes) and floating rocks (slow client-side motion).
- **Falling:** prevented by invisible barriers on the bridges and sinkhole edge (owner-confirmed). Visible low railings or rock lips can make the edges read naturally. Floating-rock and bridge motion must not move players: the spawn rock stays still or bobs only in visual effects.
- Earlier ideas rejected 2026-10-31: slug-tube canister tree, ancient stone slug colossus, hanging slug orrery, slug-energy well with launching slugs.

**Not chosen for now:** descent-shaft entrance, overlook balcony, canteen, map table. They can be revisited later.

### Zone identities

Each destination has its own mood without clashing with the others. These are moods, not fixed colours.

| Zone | Feel | Lighting/colour lean |
| --- | --- | --- |
| Central hub | Calm, welcoming, visually rich, not aggressive | Softer, balanced light, ambient glows, clean outlines. One main crystal or portal centrepiece. |
| Training | Practical, focused, controlled | Cooler tones, clean targets, slightly brighter readable light |
| PvP | Competitive, energetic | Warmer orange/red-orange glow, more dramatic contrast |
| Veylume | Mysterious, adventurous, magical | Green/teal/violet, less direct light, hidden depth |
| Entrance | Arrival, sense of depth and scale | Light falling from high above; reveals the hub ahead |
| Slug exhibition | Wonder, calm, alive | Soft glowing habitats and natural flora; the most organic area |
| Gun exhibition | Craft, power, polish | Warm workshop light; chunky orange/graphite/steel accents |

## Where the work lives

Lobby work goes in its **own branch and worktree** so it never interferes with Codex's movement, Rocklock map or gun development. Proposed: branch `experiment/lobby`, worktree `C:/Users/runni/slugshot-lobby`, based on `feature/slug-asset-pipeline` so Floppy and the blaster are available. Its own Rojo project and test place, and Blender sources under its own asset folders. The Floppy/blaster private asset files are ignored by Git and must be copied privately into the new worktree, never committed. Nothing merges into `main` and nothing is published without owner approval.

## Phases

### Phase 0: Plan (this document) ✅

Style guide, roadmap and asset plan written. **Owner review needed** before Phase 1.

### Phase 1: Style test vignette

Before building the lobby, prove the look on **one small test area** in Studio containing:

- a rock wall,
- crystals,
- a giant cave mushroom,
- a portal frame,
- the blaster,
- Floppy.

The wall, crystals, mushroom and portal frame are built as first-pass Blender assets (see the [asset plan](lobby-assets.md#phase-1-vignette-set)) so the test judges real art, not grey parts. Then the same scene is shown in **three treatments**:

| Treatment | Description |
| --- | --- |
| **A: Comic Cavern** | Heavy black outlines, bold hand-painted details, strongest Borderlands influence. |
| **B: Enchanted Cavern** | Softer outlines, brighter fantasy lighting, beautiful bioluminescence. |
| **C: Living Comic Fantasy** | Strong outlines on important objects, glowing fantasy environment, detailed but restrained shading. The proposal's favourite. |

Also compare:

- outline methods (inverted hull vs painted lines vs `Highlight`, and combinations),
- charcoal vs black ink,
- bloom strength,
- low graphics settings and a mobile-sized view.

**Deliverable:** side-by-side Studio screenshots from the third-person view and a wide view, the cost of each method, and one Studio place the owner can walk around with a treatment switcher. **Gate:** the owner picks a treatment, possibly mixing details from several. Record the decision in an ADR.

### Phase 2: Greybox layout

Block out the outpost and cavern with simple parts at true scale against the R6 character, ground slugs (about 0.9 studs) and the blaster. Establish sightlines from spawn to all three destinations, paths, open space and the cavern's sense of size. **Gate:** the owner walks the greybox and approves layout and scale.

### Phase 3: Asset production

Build the [asset plan](lobby-assets.md) in Blender in priority order: landmarks and modular kits first, then dressing. Each distinctive asset gets a concept or blockout agreed with the owner before detailed work, then is exported with its outlines and painted textures through the existing Roblox pipeline. **Gate:** owner approval per asset or per batch.

### Phase 4: Assembly and lighting

Replace greybox with final assets. Light the hub and each zone with its own identity. Apply the chosen grade and post-processing. Run the [readability check](style-guide.md#readability-check-ask-of-every-scene) on every view. **Gate:** owner review in Studio.

### Phase 5: Life pass

Add the ambient life: Floppies resting and wandering, drifting glow particles, plant sway, slow crystal pulses, environmental sound. Keep it calm. **Gate:** owner review; it should feel alive but not busy.

### Phase 6: Performance and polish

Check low graphics settings, mobile, triangle/texture/light budgets and draw calls. Fix anything that breaks the look at low quality. **Gate:** owner art approval of the finished lobby, recorded with evidence.

## Status tracker

| Phase | Status |
| --- | --- |
| 0 Plan | Implemented; awaiting owner review |
| 1 Style test | Not started |
| 2 Greybox | Not started |
| 3 Assets | Not started |
| 4 Assembly/lighting | Not started |
| 5 Life pass | Not started |
| 6 Performance/polish | Not started |

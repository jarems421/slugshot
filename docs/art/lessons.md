# Art direction and asset library lessons

What was hard during the lobby art-direction and concept rounds of 2026-10-31 to 2026-11-01, and how each problem was solved. Read this before the next environment or prop concept task so the same ground is not covered twice. Owner phrasing that took several rounds to decode is in [owner design language](../slugs/owner-design-language.md#environment-and-art-direction-2026-10-31-to-11-01).

## Final state

- **Final designs, owner-approved 2026-11-01**, in the [asset library](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr). Source: [asset-library.html](asset-library.html).
  - Rock wall module v6.
  - Crystals: 14 designs in 14 colours.
  - Giant cave mushroom v2, with a 14-colour bank.
  - PvP, Training and Veylume gates v3.
- **Treatment:** Slugshot mix ([style guide](style-guide.md#treatment-rule-slugshot-mix-confirmed-2026-10-31)).
- **Next:** build these in Blender from the same shapes. `tools/lobby/build_vignette.py` is an unrun first pass and predates the final concepts, so it must be updated to the library's SDF forms first.

## Workflow that worked

1. **Write the philosophy first, without numbers.** The [style guide](style-guide.md) records principles only, and palettes stay out until assets need them. The owner explicitly wanted rules that survive colour and layout changes.
2. **Research the reference franchise for categories, not designs.** See [Slugterra research](../research/slugterra-environment.md). The fan wiki and TV Tropes block automated fetches, so mark each fact as search-confirmed or from memory.
3. **Agree layout in words and simple diagrams before any geometry.** The owner described the hub, gates, bridges and centrepiece verbally across several messages. An ASCII diagram in the roadmap, updated each round, kept it straight.
4. **Agree every asset as a live 3D concept in one library page before Blender,** the same lesson as Floppy. The owner asked for this mid-task: "it made it very accurate and easy to envision".
5. **Change only what was criticised; keep what was praised.** When the owner says a version was worse, roll back to the version they liked and add the requested items to it. Rock wall v3 was "the worst": v4 restarted from v1 plus the dressing they listed.
6. **Render and look before publishing.** Once offline rendering existed, inspecting a contact sheet caught bugs that blind publishing had shipped, such as the false bounding spheres described below.

## Problems and their fixes

### Choosing the treatment took four rounds

- **What happened:** three treatments were offered: A Comic Cavern, B Enchanted and C Living Comic.
  1. The owner rejected B outright.
  2. They asked for a midpoint "closer to Comic Cavern". The first blend was "not there enough".
  3. They described what they actually wanted: Living Comic's *clean* look with Comic Cavern's *thick ink and shadowing*.
- **What fixed it:** split the treatment into independent controls instead of blending presets. Inked Cavern took Comic Cavern's ink width and colour, Living Comic's interior-line density and glow, plus deeper shadows with a crisp comic edge. The owner's reaction: "you nailed it".
- **Then the rule went per material:** the owner saw that dark rock looks better with Comic Cavern, glowing and clear things with Inked Cavern, and characters always Inked. Comic Cavern's heavy lines also "engulfed" small metal details. The final rule assigns a treatment by material, and small metal details get a thick silhouette with light interior lines.
- **Lesson:** when the owner wants "between X and Y", ask which *qualities* come from each, and expose those as separate controls.

### Bold ink swallowed small details

- Raised symbols on the gate keystones were unreadable under thick ink.
- **Fix:** make the symbol a flush, glowing inlay with a fine painted edge, so no geometry means no ink outline. The same principle as the per-material rule.
- **General rule:** small readable details (symbols, bolts, inlays) should be painted or emissive, not raised geometry, under the Slugshot ink style.

### Too much interior line work read as "weird lines"

- Carved horizontal strata on the rock wall cut across every mass, and the owner found them strange and noisy.
- Painted, short, broken cracks and simple masses worked.
- Vines on the wall "ruined it". Small glowing mushrooms in cracks replaced them.

### Dressing hovered off the rock

- Hand-placed mushroom and crystal positions on an organic SDF surface floated or sank, because the surface is not where it looks from coordinates.
- **Fix:** `tools/lobby/wall_sites.py` ray-marches each spot onto the actual `wallMass` surface on the GPU and searches a small neighbourhood for front-facing, non-overhang rock. Stems root inside the rock and grow along the normal and up. Spots with no suitable surface are skipped, not forced.
- **Apply the same approach** to any dressing placed on organic surfaces, including future Blender scatter: project onto the real surface and check the normal.

### Generated variants drifted off their bases

- The crimson shard field's generated layout spread crystals beyond its rock.
- **Fix:** keep the generated spread well inside the base rock's footprint, and give hand-built designs explicit base positions.

### The live 3D page froze Chrome, then WebGL was disabled

- **Cause:** one fragment shader held every asset's geometry plus nested loops. On Windows, Chrome's ANGLE/D3D compiler unrolled all of it, hung the GPU process and froze the whole browser. After the crashes, Chrome refused WebGL entirely, even after a restart with graphics acceleration on. The RTX 3070 itself was fine: the same shader runs through native OpenGL in moderngl in about 0.03 s per frame.
- **Fixes, in order:**
  1. One small shader per asset (`#define ASSET n`), compiled only when that asset is opened.
  2. Bounding early-outs for crystals, rock chunks and dressing.
  3. **Rendered turntables as the default view:** `tools/lobby/render_library.py` renders 36-frame sheets offline from the page's own shader and `lib` script, so they match exactly. The page draws frames on a 2D canvas. Live 3D became an opt-in button that falls back to the renders on failure.
- **Smoothness:**
  - 16 frames moved as a large CSS background felt laggy. 36 frames drawn on a canvas only when the frame changes is smooth.
  - Overcautious live settings (low starting resolution, low resolution while dragging, a 25 fps cap) made live 3D worse than the original. Restore the original settings once the real cause is fixed.
- **Early-out pitfall:** returning the distance to a bounding sphere with no margin creates a false surface on the sphere itself. That bug rendered giant glossy spheres. Only take the early-out when the distance is above a margin (0.3 to 0.5 studs).
- **Publishing:** the Artifact tool takes supporting files only from the working directory or scratchpad. Copy the page and `build/lobby/renders/` into the scratchpad and publish with `files`. See [lobby assets](lobby-assets.md#asset-library-live-3d-concepts).

### Small props crushed by a shared triangle budget

- Decimation shared one budget per material group. Many tiny mushrooms in one group got about 14 triangles each and read as shards.
- **Rule:** give small-detail groups a floor (a quarter of dense detail, up to 4,000) and scale outline width with feature size.

### Ambient tint is not a lighting fix

- Raising a blue-violet ambient to make walls visible tinted all the stone blue, and the owner rejected it.
- **Rule:** keep ambient dark and near neutral, and light surfaces with placed lights so materials keep their own colour.

### Agent-side blind spots

- Until offline rendering existed, the agent could not see the page and shipped shader bugs blind. Render and inspect at least one contact sheet before telling the owner a change is done.
- GLSL ES 1.0 has no shader compiler on this machine. Check brace and parenthesis balance and JS syntax with Node, and avoid names like `cross` that shadow built-ins.

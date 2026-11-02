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

### "Recalculate outside" turned small pieces inside out

- **Symptom (owner, round 4):** some wall mushrooms were "black voids" with a ring of light and no glow, some sprout bases looked strange, few crystals showed and sparkles came "from nowhere".
- **Cause:** each material group is an open surface, cut where it meets the next material. Blender's `normals_make_consistent` guesses wrong on open pieces: it flipped 13 of 52 wall caps, 15 of 34 stems, the biggest wall crystals, and part of the gate's iron and stone. Roblox culls back faces, so a flipped piece vanished and its ink shell (built along the flipped normals) became a shrunken black copy.
- **Fix:** keep the marching-cubes winding, which faces outward. `orient_like` flips any decimated island the dense mesh disagrees with as a guard. Previews now cull back faces like Roblox and include a low view under overhangs; they had hidden the problem.
- **Check:** compare every island's face normals with the dense source mesh. All groups now read zero flipped islands.

### Boundary ink sampled into the air

- **Symptom:** ragged black patches around crystal and mushroom bases, and dark stems and caps.
- **Cause:** the concept's material-boundary ink compares four diagonal samples about 0.15 to 0.3 studs away. Painted per texel, those samples landed in the air beyond thin stems and caps, where the nearest material is the rock. That inked 63% of stem texels, 42% of caps and 23% of crystals.
- **Fix:** the painter samples a ring of points in the surface's tangent plane, snaps each back onto the surface and inks only where the material changes there: a fixed 0.045-stud contact line. Coverage dropped to 4%, 7% and 2%. Crease ink is unchanged.

### Roblox flips the axes of glTF imports

- The concept's −Z side, where wall dressing faces, arrives in Roblox facing +Z. Effect points placed with a plain offset were mirrored into the rock behind each crystal, so twinkles rose from gaps.
- The look test now measures the flip per asset: it records each group's concept centre and picks the axis flip that best lands those centres on the imported parts. The Output log prints the result as `LookTest: <key> import axes …`.

### Sharp box edges mesh into saw teeth

- **Symptom (owner, round 5):** the outlines on the gate's iron bands looked corrupted, front and back.
- **Cause:** the bands were perfectly sharp boxes. Marching cubes cannot reproduce a sharp edge at the sampling step, so the edges came out as teeth. Heavy decimation (about 37 triangles a band) made it worse, and the ink shell traced every tooth.
- **Fix:** bevel sharp edges in the concept by at least the sampling step (0.05 studs on the bands), sample the gate at 0.04, and give `Iron` the small-detail triangle floor.

### Too many small lights make the look shift with the camera

- About 300 point lights (one per crystal and cap cluster) made the walls look different from shot to shot. Roblox renders only a limited number of lights near the camera, so they faded in and out as it moved.
- Zone moods also changed exposure and fog density, which re-lit the whole cavern as the player walked.
- **Rule:** merge nearby emitters into shared lights (within 4 studs: about 90 lights in the test place), and let zone moods shift colour only.

### Light bank colours wash out under Roblox glow

- Small caps with pastel bank colours read "dull and pale": glow strength about 3.4 pushed the bright channels past 1 and tone mapping turned them white.
- **Fix (Roblox build only):** square each small-cap channel against its brightest one and cap the glow so the brightest channel reaches 1. The concept page keeps the original bank.

### Rock texture: features on a portion of masses

- **Owner (round 6):** the rocks "look so basic"; moss worked, but not on every rock, so other kinds of texture are needed on a scattered portion.
- **Approach:** the wall's 15 masses are indexed (`wallMassParams`), and a hash of each mass's seed picks which ones carry a feature. Geometry features live in `wallMass`, painted ones in the rock albedo through `wallMassAt`. Option 1 stays pixel-identical to the approved v6, which was checked.
- **What read and what did not, in the turntables:**
  - Hairline cracks were invisible at viewing distance. Cracks need a 0.13-stud carved width plus a painted ink line and a light chipped edge.
  - Thick noise isolines made glowing blobs, not veins. The threshold has to be narrow.
  - Cell-grid lichen dots read as polka dots. Crusty noise patches work.
  - Round pockmarks always collected crease ink at their centres and read as bullet holes, even as shallow saucers. They were dropped for chipped facets.
- **Small caps:** capping their glow at 1 kept the colour but was "too dim". The deepened colours allow a 1.6 peak (about concept strength) without washing out.

### Lighting that flips between two looks: automatic graphics quality

- **Symptom (owner, round 7):** two screenshots from the same spot looked completely different. One had dark walls, crisp coloured light pools on the floor and a dark character; the other had evenly lit walls, no pools and a lit character.
- **Cause:** Studio's automatic graphics quality changes level with frame rate. At high quality, the wall lights' shadows let the rock masses shade each other, so most of each face went dark; at lower quality those shadows are skipped and the face lights fully. Cutting the light count in round 5 did not address this.
- **Fix:** wall lights cast no shadows, so both quality levels match the brighter look the owner wants. For judging looks, set Graphics Mode to Manual in the in-game Settings so the level stops changing.
- **Rule:** never rely on a light's shadows to set an asset's overall brightness; Roblox drops them at lower quality.

### Rock texture round 7: what finally read

- **Owner on round 6:** the zigzag cracks read as "squiggles that you just wiggled around the rocks", and chipped facets made rocks look deformed.
- **What works:**
  - Cracks as a few straight segments with sharp alternating turns and one fork, wide at the rim and tapering. They are carved as a V-groove no deeper than 0.3 studs, so the rock's shape never changes.
  - One cracked rock per column of the wall, so a third crack and they spread evenly; a seed per wall variant moves them.
- **Cracks on the thin top row** read as black slots when seen from above, so the top row never cracks.
- **Fossils** needed to be big (0.75 to 1 stud) with a pale disc and ribs; small thin spirals read as targets.
- **Surface texture** at wall distance needs strong contrast: tonal mottling at 0.4, flecks at 0.45, and hatching whose crevice mask reaches gentle concavity.

### Round 8: real cracks kept, everything faint removed

- **Owner:** loves the carved cracks and wants a few more; disliked "the faint line that just squiggles around everywhere" and the fossil shells ("mid").
- **Two sources of faint squiggles,** both removed in the texture study:
  - v6's painted noise-isoline cracks in the rock albedo.
  - The concept page's material-boundary ink. Its diagonal samples dipped under the rock surface and outlined the buried roots of wall crystals and stems as arcs. The fix is the surface ring test the Roblox painter has used since round 4. It also removed the dark blobs around sprout bases in the concept renders.
- **Ruled out first:** convex crease lines, and the ambient-occlusion reach past the dressing's bounding spheres. Each was tested on renders and left the arcs in place.
- **Cracks:** now on five of the twelve big rocks (one per column plus one), with a second shorter crack on about half.

### Round 9: the base wall design, filled in every region

- **Owner:** a little more crystals, especially where the top left felt bland; make this the base design, with crack, moss, mushroom and crystal positions changing per wall and "every corner has something".
- **How:** `tools/lobby/wall_sites.py` splits the face into six regions and gives each a crystal cluster (two or three) or a mushroom cluster (three), plus tiny mushrooms everywhere. Each wall draws from its own seed and is measured on that wall's cracked surface. Moss shifts per wall.
- **Found on the way:** the approved v6 anchors no longer match today's rock surface. Re-probing moves some by up to about 0.2 studs, so the rock moved after they were measured. They are frozen verbatim to keep v6 and its Roblox build unchanged; walls A-D are measured fresh. When rock geometry changes, re-run `wall_sites.py` straight away.

### Round 10: freshly uploaded textures, even cracks, matching gate bands

- **One wall looked bare and pale with unlit caps:** all four new walls' textures had been uploaded minutes before the owner played, and were probably still in Roblox moderation, which shows images blank. Every map read back as Approved afterwards. **Rule:** after an upload, query each asset's `moderationResult` through Open Cloud and reopen Studio only once all are Approved.
- **Cracks rarely in the top left:** the top row never cracked, so the top-left region had one candidate rock at 50%. Cracks are now picked per region (the dressing's six regions; five of six crack, the skipped one random). Top-row cracks start on the lower half of the rim, so they never open across a top.
- **Gate bands differed:** the bands were a fixed size while each block's thickness is jittered, so some bands sat proud and others sank. Each band now sits a fixed height above its own block.

### Agent-side blind spots

- Until offline rendering existed, the agent could not see the page and shipped shader bugs blind. Render and inspect at least one contact sheet before telling the owner a change is done.
- GLSL ES 1.0 has no shader compiler on this machine. Check brace and parenthesis balance and JS syntax with Node, and avoid names like `cross` that shadow built-ins.

## UI motion and the "AI slop" feedback (2026-11-02)

- **Roblox snaps UI to whole pixels.** Slow Position or Size changes step visibly ("0.5 frames a second"). Resample with ImageRectOffset instead.
- **Scale hover by pixels, not percent.** A percentage makes wide buttons spill onto neighbours, and draw order then covers only one side.
- **No generic effects.** The owner hates halftone dot backgrounds ("never do that") and thin glowing lines passed off as cracks. A glow cut off by its image shows straight edges, so check the alpha at the edges.
- **A drip is one shape with the goo.** A sprite with its own outline placed on the edge reads as stuck on.
- **Look before handing over.** `tools/studio/pvp_ui_check.ps1` captures real Play in under a minute.

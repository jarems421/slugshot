# Art direction and asset library lessons

## 2026-11-03 - Reject texture-quality and performance regressions

Owner's close-up exposed the 256-square lava material as jagged and low quality. The original 1024-square atlas has tightly packed UV islands: reducing colour, normal and glow maps together damages the painted surface. Distant screenshots and changed-pixel counts missed this. The final full-resolution variant preserved original normal pixels but cost about 25-30 ms per update, and its material-swap comparison rendered white. These are failed acceptance results. Restore the original static material rather than ship the experiment. [Record](../evidence/2026-11-03-lava-quality-rollback.json). Earlier integrated-material conclusions below are superseded.

## 2026-11-03 - Integrate flow into the material

**Confirmed:** visible beams still looked detached from lava. Replace overlays with an animated colour image on the original UV-mapped SurfaceAppearance. Native image-buffer changes and fixed-mesh checks establish actual material animation; close-up captures establish retained colour and surface registration. Preserve the source paint and shading maps.

**Implemented/verified:** initial vertex tint did not visibly affect SurfaceAppearance. The first image resize used the default center pivot at zero, copying only a quarter and rendering white despite passing pixel-change tests. Center the target pivot, require over 90% opaque coverage on mapped texels, then inspect corrected native captures. Wait for HubSolid and the material's actual SlugshotMaterial name, rather than assuming the tag and child replicate together. [Evidence and API limits](../evidence/2026-11-03-integrated-lava-material.json).

### Shop study 03 rejected (2026-11-03)

- **Owner:** "very bad, horrible". It didn't fit the lobby map and didn't use any existing assets; it generated its own.
- **Lesson:** design lobby pieces in the lobby's real coordinates and with the approved library (giant mushroom v2, grove plants, crystals, Floppies, rope bridge). Only model what doesn't exist yet. Check the layout with the owner on a to-scale plan before building art.
- **Owner's layout (Confirmed):** remove the lava ravine. The gun-side rope bridge lands on a place with a small mushroom forest; a second, substantial bridge crosses a big hole full of mushroom canopy to the shop. [Plan](https://claude.ai/artifact/DEmM21QCY21ykLjvw93HUr).

### Pod-house shop feedback (2026-11-02)

- **Confirmed:** "like the houses" referred to clustered rounded pods around an organic tree/fungal silhouette, not another arched retailer or a palette swap. Owner-provided screenshots resolved the ambiguity.
- **Implemented:** replace the primary masses before dressing them. Keep dominant shells pale/cool, luminous details selective, and retain a readable general-shop entrance.
- **Verified during browser review:** full-width horizontal mist cards protruded below the terrain as a stacked skirt. Constrain mist within the chasm, use inward-facing pit walls and extend surrounding ground beyond the framing. The concept is not evidence for Roblox VFX or collision.


## General shop research and first concept, 2026-11-01

**Confirmed:** owner approved the volcano and requested a researched Slugterra-inspired general shopping hub, closer to medium size. The shopkeeper and gameplay remain future work.

**Implemented/verified:** [research](../research/slugterra-shops.md) found Barton and Spinks and inspected official episode storyboard thumbnails rather than relying on generic Western storefronts. The original concept combines rounded industrial architecture, muted teal/slate, warm energy accents, varied supplies and the existing fern. First browser review caught a plain side wall, an interior camera obstructed by a door, and an unfilled rear gable. A real round side window, revised camera and closed rear gable fix those issues. Full orbit views matter: front-only checks would have missed the roof gap. Exterior and roof-off turntables allow review on devices without WebGL. See [concept/evidence](general-shop.md); owner art verdict and Studio remain unresolved.

## Volcano study, 2026-11-01

**Confirmed, study 05:** owner called the lava spitting underwhelming and choppy, requested curled cave ferns at the base, then requested the fern separately for reuse. Whole-segment trail reveal introduced visible stepping; study 05 evaluates jet head/tail continuously and interpolates fallback path endpoints. Per-segment blurred strokes and resetting canvas dimensions on every frame also wasted fallback drawing work; filled ribbons and resize-on-change replace them. A 60 Hz timing check and phase sheet cover the movement, while owner-device smoothness still needs review. One shared fern generator now serves the dressing, isolated preview and GLB export; see [fern record](curled-cave-fern.md).

**Confirmed follow-up:** owner likes study 03, but wants the already-authored crystal family instead of simple cones at the foot, in red/gold/orange with varied designs and mushrooms. Reuse the library's layout parameters and hexagonal prism/tip forms; keep provenance explicit when the browser reconstructs source definitions rather than loading exported GLBs. For browser devices without WebGL, a static turntable plus smoke does not show downhill lava motion: study 04 uses projected ribbon/fountain paths for animated fallback effects. Final appearance is pending owner review.

**Confirmed owner feedback:** the early volcano was bland, generic, without vibrancy or liveliness. It must belong with the approved spawn island and Maelstrom, with jagged rock forming the walls, molten creases, diffuse smoke and occasional lava spurts. Source images guide shape and behaviour; the project's illustrated cavern treatment guides the finish.

**Implemented/verified in browser review:** plain grey material and a generic cone do not reproduce the library's painted variation, dark ink, coloured shadows and surface glow. The revised study adds those explicitly and is documented in [remaining concepts](remaining-concepts.md#volcano-study-03-2026-11-01). Visually inspecting the first revision caught overly smooth walls and fine speckled lava; broader fracture planes and larger crust patterns replaced them. Two inward-facing surfaces (crater bowl and top of the bedrock foot) were corrected after they rendered as dark voids. Broken, locally staggered joints replaced continuous ring-like seams; the earlier rejection of uniform horizontal strata remains relevant.

**Unresolved:** owner art verdict and Studio. Browser improvements are concept evidence, not proof of final Roblox appearance. A wider visual silhouette must be fitted to the approved lobby before placement.

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

### Studio MCP listed no Studio windows

- **What happened (2026-11-01):** `list_roblox_studios` stayed empty with several Studios open, and Windows refused to bring Studio to the foreground for keystrokes.
- **What worked:** a check build (`tools/lobby/build_scale.py --check`) whose scripts measure themselves and print to the output, started by posting F5 directly to that window's handle. Results come from the newest `%LOCALAPPDATA%/Roblox/logs/*Studio*_last.log`, and `PrintWindow` captures the window without focus. A true-speed test character found a lip height bug that reading the numbers would not have.
- **Testing falls:** teleporting the player trips the movement anti-cheat, which snaps them back. Move them at a legal speed instead.

### Very large concepts (spawn rock, Sky Well, Maelstrom, 2026-11-01)

- **Scale:** ink, ambient occlusion and fades in the library shader are tuned for prop-sized assets. Build huge assets in scaled units (1 unit = 5 or 10 studs) and scale the figure, so they keep the same look.
- **What the first render showed:** rounded moss lumps read as green balls or lily pads, because ink outlines every raised shape; paint moss onto the rock instead. Long curved roots read as tentacles or tusks; keep them short, thin and close to the rock. Floating rocks with one thick trail read as mushrooms; give them a pointed underside and thin vines. Crystals seen end on read as flat white plates; angle them to show their sides and use a colour gradient so they don't blow out.
- **Shore and backdrops:** the rock wall's moss noise turns into camouflage at this scale. Keep surrounding ground dark and fade it out so the eye stays on the asset.

### Spawn rock v2 (2026-11-01)

- **Threads on spike tips:** surface noise ate away the thin ends of tapered spikes. Fade the noise toward the tips instead of fattening the spikes; fat spikes lost the shape the owner liked.
- **Telling roots and vines apart:** give them different forms, not just colours. Roots are thick, forked, barked and follow the rock; vines are thin, leafy and hang free.
- **Roots need to stand off the surface.** A root centred on the surface is half buried and shows only as lumps. Thick roots crossing an edge become knobs, so keep them slim there.
- **"More moss" still means patches.** Covering everything hid the rock and fangs. Keep moss a muted colour, distinct from leaf green, with rock showing through.
- **Heavy shaders:** the three big concepts have Live 3D switched off (`noLive`), since a heavy shader froze Chrome before.

### Spawn rock v3: the approved language beats new detail (2026-11-01)

- **What happened:** v2 did everything asked for, one request at a time, and the sum drifted off style. The owner still liked the individual designs but said it was no longer Slugterra, too cramped and too green.
- **What fixed it:** comparing against a render of the approved rock wall, then building from that wall's masses, colours, cracks and moss, with far fewer accents.
- **Rule:** after a round of "add more" feedback, compare the result side by side with an approved asset before publishing, and judge the base-to-accent balance from the [readability check](style-guide.md#readability-check-ask-of-every-scene).
- **Ink:** large dressed assets need the surface-measured material boundaries the rock wall uses, or buried parts draw black splotches.

### Spawn rock v5: ask for a reference sooner (2026-11-01)

- **What happened:** four rounds of words about the rock's shape didn't land; two reference images settled it at once. When shape feedback keeps circling, ask the owner for an image early.
- **Blocks on a grid read as brick walls:** vary lengths widely, slant the ends, turn and lean each block, and thin the ink on joints, so no two line up into courses.

### Sky Well lightning and vortex (2026-11-01)

- **Lightning that reads as cracks:** a thin white line with a few long straight segments. It needs fine jagged detail, tapering, a trunk-branch-twig hierarchy, and layers from white core to colour band to wide glow.
- **Looking up a shaft:** a volume that stops at the rim reads as a flat disc. A spiral converging on a hollow, bright eye gives depth, and cloud crossing the rim breaks the circle.
- **Tone mapping lifts dark values a lot:** cloud colours that look dark in code came out pale lavender. Test dark storm values low.


### Bridge hook-up: rope that looks attached (2026-11-01)

- **A wrap must share the shape it wraps:** a ring built from a plain box sank in and out of a turned, tapered, noisy stone and read as neither inside nor outside it. Build the ring from the stone's own frame and outline, smooth the stone under it, and cut a shallow groove.
- **Show the load path:** a rope reads as tied when it ends in a visible knot sitting proud of the wraps, with a loose tail. Thicken it near the tie so it reads from a distance.
- **Check a repeated stray shape by colour:** painting each part a flat colour showed that a line at all four gates was the first plank, tilted up by the deck's slope and poking through the slab.

### Hub designs into Roblox (2026-11-01)

- **Decimation erases what makes a shape:** cracks flattened into painted lines, thin stems became spikes, and a folded liquid became hard facets. Give important detail its own part and budget. Keep a surface smooth and put its folds in the maps.
- **An outline must match its part exactly:** a lighter shell sinks inside in places and pokes out in others.
- **Normalise glow per colour:** against the part's brightest colour, only cyan glowed.
- **A frozen mesh can't read as liquid, however it wobbles:** scrolling sheets with wavering edges do, and they stay cheap.
- **Grey-map stand-ins can stand in front of the art:** look for them when you see "gaps".
- **Replication order:** a tag can arrive before the descendants it refers to, so wait for them.
- **Cut flat surfaces, don't decimate them:** a decimated top lay over its own grooves and showed their paint. Triangulating it from the groove outlines gave real holes in 324 triangles.
- **Check motion triggers against what the owner said:** "when walking" means moving, not merely standing on the bridge.
- **Shader hash values differ between Python and the GPU:** a recomputed value put two falls 19 studs from their mouths. Measure from the GPU that made the art.
- **Generate collision from the art:** hand-made rim shapes were up to 8 studs off, so players sank into the lip and fell through the rock's edge.
- **The shader's hash isn't a stable number:** the same call gives different values depending on how it's compiled, so anything two systems must agree on needs a plain constant.
- **A non-camera-facing Beam's width runs along its attachments' Y axis.**
- **Look before handing over:** a short camera check caught edge-on strips and water passing behind the rim, neither of which any offline check could show.
- **Never let two shader programs share a hash-derived layout:** the sampling and painting programs compiled the hash differently, so crack paint and crack holes landed in different places for many rounds. If repainting never fixes something, compare what each program actually computes.
- **Camera-facing sprites and flat transparent layers don't mix:** where a sprite crosses a layer it is cut in a straight line. Switching effects off one at a time found this in one run after a round of guessing.
- **Tiny detail needs its own fine sampling:** mini crystals melted into blobs at the dressing's grid, and read as real faceted clusters once they had their own piece at a third of that step.
- **Regenerating a call whose signature changed:** clear the old generated lines first, because the generator compiles the page they sit in.
- **A clean glowing circle reads as sci-fi, not a cavern:** the first ring around the Sky Well was a neon hoop. A thinner, wandering, broken seam in deeper colours separated the zones just as clearly, helped by the dark moat beside it.
- **Even scatters read as polka dots:** glowing fungus looks natural in tight colonies of small, unevenly sized lights.
- **Moss on a big surface goes camo fast:** noise patches covering half the Sky Well's ceiling read as flat green blobs. Keep it under about a fifth, small, soft and darker than the rock's lit tone.
- **A part showing flat grey right after an upload is probably still processing:** look again a few minutes later before changing anything.
- **Check sightlines before scaling a backdrop:** from the spawn rock the arch's keystone hid the crater, whatever the volcano's size. Widening the opening fixed it.
- **Glowing surfaces washed out when their glow was baked into the colour map:** keep the colour in the map and let the mask carry the glow.
- **Size imported pieces from their longest side:** on a thin piece, a tiny height error scaled the whole floor by 6% and opened gaps at its edges.
- **Hide block-out parts by what they are, not by where their centre is:** a long wedge's centre can sit in the neighbouring sector.
- **Thick liquid needs its own smooth surface:** riding on ribbed rock made it faceted or half buried, and noise running along one diagonal turned into ladder rungs.
- **Roblox's camera ignores invisible colliders:** it only stops at parts under 25% transparent, so hidden block-out ground let it pass under the map. Making the visible art solid fixes both the camera and phasing.
- **Test collision with a pushed block, not `MoveTo`:** the movement controller ignores `MoveTo`, so a character that never moved looked like a blocked one. Include cases that must pass, so that a block that stops everywhere can't look like success.
- **Don't stretch a gradient across a big surface map:** Roblox's compression turned the portal's into visible square blocks. Keep the map a flat colour and put gradients in large alpha-only particle textures.
- **Continuous rotation from particles:** give an N-armed texture fixed rotation, and emit a new particle each time the last has turned one arm, with lifetime twice that and a triangular fade. Copies line up exactly, so it reads as one steady swirl with no popping. Random rotations read as broken shards.
- **Adding light stacks with overlap:** several additive layers blow out to white long before any one looks bright. Count the overlaps when setting strength; a deeper base shows a swirl better than more brightness.
- **Symbol polygons must be convex and anticlockwise:** `poly3`, `poly4` and `poly5` silently draw nothing otherwise. Check 2D previews against the same rule, because a general-purpose preview hides this.
- **Neon can't carry detail:** it renders far past full brightness and its response to colour is very steep, so overlays barely show and small colour changes swing the hue. Use a solid map with `EmissiveStrength` and a real light when something must be drawn on top.
- **A flat glowing surface exposes its mesh:** decimated triangles showed as hairline cracks and shading fans, which read as shards. Author it as a simple sheet with shared corners; a low triangle count isn't what matters, flatness is.
- **Measure authored meshes from the art they replace:** design constants missed the gate's real scale by about 40%.
- **Don't queue a Studio run alongside a patch that can fail:** it silently tests the previous build. Run it only after the build step has succeeded.
- **Trace symbols from the real model:** hand-drawn silhouettes read as an older design; `tools/lobby/blaster_rune.py` regenerates the rune from the current mesh.
- **Surfaces that must blend need one paint function and no moving parts at the join:** a spinning pool and separately painted streams could never line up.
- **In `cut`-style patches, don't stop at a marker the same patch moves:** it silently ate the start of `volcanoFlow`; the shader compile caught it.
- **Keep the sky the colour of the enclosure:** Roblox can stop drawing far parts at lower graphics levels, and anything bright behind them flashes through a closed cavern.
- **A repeating map beats a bigger one for large surfaces:** the floor lava went from a few blurry pixels per stud to about 34, with world-space UVs and one 1024 tile. Mesh UVs outside 0 to 1 do repeat on a SurfaceAppearance.
- **Stacked sheets read as separate pieces:** different speeds and hard alpha edges make layers look like loose chunks. Make the main body one opaque surface that reaches behind whatever frames it, and keep any overlay soft.
- **A patch script should write its files together at the end:** one that stops midway leaves some files changed and others not.
- **Never send global keystrokes to Studio on a shared machine:** `SetForegroundWindow` can silently fail, and the keys go to whatever has focus, which may be someone else's session or a place that must not be published. Check the foreground window first, and hand outward-facing steps to the owner.
- **Studio frame rates only count while focused:** an unfocused window is throttled to 15 fps, which looks like a performance problem.
- **Graphics level in Studio:** game scripts can't set it (`settings()` needs the Plugin capability). A plugin setting `Rendering.QualityLevel` works and visibly changes the picture; `EditQualityLevel` had no visible effect in Play.
- **Resizing the Studio window gives true device viewports:** panels take 200 by 295 pixels, so a 1044x685 window has an exact 844x390 view.
- **Texture memory builds up during a run:** report its peak per device, not per view.
- **Start a green scene dark:** bright moss and glowing water at full strength flattened the first grove render into a toy. Dark ground and stone first, then saturation only on mushrooms, water and crystals.
- **The ink's reach is fixed in world units:** at true scale it swallowed Floppy's face, so anything that small must draw its own lines.
- **Build a surface from the approved parts:** a noisy cone painted like rock never read as Slugterra; rebuilding from the lining's actual block shape did in one pass. Square tops still read as a ruined castle until the slants and height differences were strong.
- **Give hero objects their own random stream in generators:** changing the mountain's placements moved every Floppy away from the camera and the arrival side.
- **Check file times after a batch render:** one silently failed render left an old mountain in a sheet that looked plausible.
- **Upright blocks read as a castle, slope-following plates as a mountain:** the same rock works once it's sheared along the slope, with ridges and an uneven outline. Too regular a profile just turns it into cones or a tiled pyramid.
- **Keep concept renders gentle:** `--gentle` splits each frame into five times as many bands and rests between them, about doubling the time but leaving the PC usable.
- **Measure where water lands against where the pond is:** the falls' foot sat about 10 studs behind the pond's edge, hidden by the bank, which read as disconnected from every angle.
- **Regular rows and straight profiles read as architecture on any rock:** tilt the layers, vary the profile and add lower spurs before adding detail.

## Mountain summits (2026-11-02)

A slope that narrows to zero always ends in a small, shrunken tip, however broken its rocks are. Keep a share of the width at the top and split it into separate tapered masses with notches between them (owner: "too thin at the top"). In the grove's views the camera faces +z, so a peak at negative x appears on screen right.

## Grove in Roblox (2026-11-02)

Scattered props sharing one mesh need a budget per prop, not per part: 200 triangles per mushroom cap read as faceted up close. Small emissive spots such as lily buds blow out to white at the strength that suits larger glowing shapes. Crowds of full-detail skinned models cost far more than the scenery around them, so check triangles with them in and out of view.

## Simplifying a shape with hidden insides (2026-11-02)

Blender's Decimate keeps triangles on sealed pockets inside a shape, because they are small and closed, and leaves the visible skin in huge shards that look like holes. Keep only the largest connected surface, and sample it near the final triangle size so little simplifying is needed. Measure the spread of triangle areas in the export: a median of 3 square studs with many far larger ones was the tell. A shape that must be walked on can be a separate smooth form with the detailed one baked onto it.

## Placing things on simplified meshes (2026-11-02)

Place what stands on a surface using the exported mesh, not the ideal shape: the grove's simplified ground differed by up to 2 studs, enough for plants to float. Sink feet a little and use the lowest ground under the whole foot. A piece's fit bounds must also come from the exported mesh, or the game rescales it. And a tapered square block reads as a pyramid at any size: tips need uneven faces, shelves and neighbouring crags. When a check reads Studio logs, make sure other open windows' logs aren't mixed in: a 0.903 size warning came from an older window.

## Mountain form (2026-11-02)

Rounds of designing tips on a body failed because a peak isn't a part: in the owner's references the whole mountain is one form, with ridges unbroken from summit to foot. A height over a triangle grid with its corners sampled from a ridged shape gives real flat faces and hard edges. Ask for references before designing a distinctive shape: six written designs missed where six pictures from the owner settled it.

## Shader size and collision on large meshes (2026-11-02)

Adding many samples of a heavy shape to one paint branch made the driver run the wrong branch for other materials: mushrooms and crystals came out in the ground's colours, and unrelated code changes made the fault come and go. Keep heavy paint out of pieces that don't use it (`@mountain-paint` markers), and compare painted colours per piece after any shader growth. Precise collision on one huge mesh can stand tens of studs above a concave surface, so measure it against the drawn surface and split it into chunks. The owner reads raised rims as "the wall between the lava streams": tie such changes to where the streams actually are.

## Replacing shader blocks (2026-11-03)

Cutting between two markers removed code living between them that others needed, and because the batch kept going, a 13-minute rebuild left the old mountain in place with no plants. Print failures loudly in long batches and stop at the first one. Raising glow on many props at once bleaches them: check colour before brightness.

## 2026-11-02 - Training asset reuse and review

- **Confirmed:** reuse the spawn rock without roots, cracked top or lower spiral; enlarge it and add underside debris. Build a full asset for owner inspection before gameplay.
- **Implemented/verified:** source lobby GLBs carry geometry only. Restoring each report's color/normal/emissive maps and inverse ink materials prevents a misleading grey review. Packed images survive the GLB reimport. Keep the original assets as a read-only, hashed snapshot.
- **Implemented/verified:** the measured rim uses x=sin(angle), shader z=-cos(angle). Blender maps y=-z, so y must be +cos(angle). Mirroring that sign produced cap overhangs; material renders exposed the error, and the corrected cap tracks the rock.
- **QA lesson:** the generic wire review scales thickness to total asset bounds, producing enormous miter spikes on thin range marks. The training-only verification adapts that invocation to 0.015-stud wires without even-offset miters; the installed skill remains unchanged. Random-color and thin-wire sheets plus actual materials are complementary checks.
- **Limits:** deliberate detached rubble, split source shells and arena-relative offsets are documented exceptions. Offline export consistency and a desktop/mobile-width browser check do not prove Roblox collision or runtime performance. [Asset and evidence](training-arena.md).

## 2026-11-02 - Plain rock training floor and native review

- **Confirmed:** the owner liked the first layout; flooring should use the normal stone language without fungi, with action pictograms rather than words. Some rubble should be visible from eye height at the rim; most stays below.
- **Implemented/verified:** low, closed painted stones cover the support cap, original running/target runestones replace all lettering, and 48 additional closed rocks span the rim. Geometry QA catches degenerate clip intersections and inconsistent winding: weld duplicate vertices, remove degenerates, and use convex boundary stones before exporting.
- **Rejected internally:** taking arbitrary loose components from the existing debris group produced thin flakes that read as cards near eye height. Closed faceted stones give the higher pieces volume; original debris groups remain below.
- **Native evidence:** sealed roofs block the sun; ambient alone made the first Studio review too dark. Local shadow-free fills restore readability. Mesh/texture loading initially made screenshots show missing or white pieces: preload the review art before acceptance captures. Source rubble imports can recenter groups separately; restore each group's bounds. Eye-height rim, rune, room and ceiling captures were inspected after these fixes.
- **Limits:** offline QA and a one-client native review do not prove mobile performance, route collision quality or final owner approval. [Current review](training-arena.md).

## 2026-11-03 - Check movement from an unobstructed view

The first fixed lava-camera view sat inside the portal arch and could not show the volcano. Technical scrolling checks alone were insufficient visual evidence. Move the authored review view beside the arch, then capture the same view at different times. The storm review must not wait for or emit a deleted Zap effect; keep only normal-lifetime diffuse blooms and cloud flashes.

## 2026-11-03 - A moving glint is not a flowing liquid surface

Owner could not see the intended lava motion after a texture-speed increase. The sparse highlight texture plus additive glow was too subtle over the emissive painted lava. Use the waterfall's fuller streak pattern, warm tint, surface-aligned width and wrapping; preserve slow speed and include alpha-colour contrast instead of relying entirely on emitted light. Storm flash timing needs both longer intervals and a gentle attack/release: slowing only the sprite fade leaves abrupt whole-cloud illumination. Native review now observes actual cloud material changes and checks their duration/spacing. Confirm the compiled review embeds current effect source before reopening the same file; save/checkpoint the old session before rebuilding.

## 2026-11-03 - A transparent beam can pass a texture-speed check

**Repeated failure:** owner still saw static lava after several speed/contrast edits. **Actual cause:** one segment samples only the fade's fully transparent ends. Opaque diagnostic strips proved placement; a native image gallery and fetch status proved texture loading. Set enough segments to draw interior transparency keys (twelve here), then inspect a close-up time sequence. Also use the waterfall's primary `flow` texture, not only its `streak` highlight, and cover all seven streams at their full modelled widths. Do not claim visibility from a nonzero TextureSpeed alone. Native comparison initially looked for a beam parented directly to FallFlow; its actual parent is an Attachment. Correct the observer rather than bypassing it. See [Roblox Beam reference](https://create.roblox.com/docs/reference/engine/classes/Beam) and [local evidence](../evidence/2026-11-03-visible-lava-gloop.json).
## Training arena: seeing through the wrong lighting (2026-11-03)

- **Problem:** the arena's walls looked huge and close until the client's void fog applied, and reused lobby crystal sets put sprouts on the lanes. Scale walls for the distance and judge them only with the zone's real fog; reuse set dressing by group, not whole assets.
- **Limits:** one-client Studio only. [Record](training-arena.md).

## 2026-11-04 - Roblox caps every map at 1024: huge pieces blur, thin detail collapses

**Owner, on the gun side in Studio:** the velvet and cobbles looked low resolution and unoutlined, the cavern's roots like flat sticks, the vines just glow with no substance, cuts in the side mushrooms' caps, sloppy shop windows and outlines, and you walked through the ground. **Causes:** Roblox shrinks every uploaded image to 1024, so the 2048 maps planned for pieces covering thousands of square studs gave about 9 texels per stud. Thin, repeated things (vines 0.25 studs across, 0.7-stud beads, cupped shelves) baked into one whole-wall mesh at 12,000 triangles decimated into shards and smears of glow. The art's ground stood up to 1.25 studs above the flat block-out you actually stand on. **Rules now:** big ground uses small maps repeating every few studs (`tile` parts in `hub_mesh.py`, painted by `velvet_maps`, `cobble_maps`, `kerb_maps`), seams drawn by true distance to the cell edge, as the nearest-two-points gap smudged at corners. Art ground stays within a fifth of a stud of the floor it covers, or is made solid. Small repeated things are modelled once each with their own budget and placed many times (`hub-gun-root-*`, `-shelves-*`, `-sideshroom-*`, `-vine-*`), and existing approved designs (crystals) are placed as templates rather than redrawn. Preview every new piece in Blender with its painted maps before uploading. **Checking:** `build_hub.py --gun` and `gun_check.ps1` give a camera tour of the gun side with a capture per view. Send Play as a plain F5 (no repeat-count or key-up flags in the message): the flagged message opened the Roblox menu over every capture.

## 2026-11-04 - Why a check place sat in Edit mode

Three tour runs never entered Play. Force-closing a check window leaves Studio auto-recovery copies (`AutoSaves/<place>_AutoRecovery_*.rbxl`); the next open of that place asks to restore, and the prompt swallowed the posted F5. `gun_check.ps1` now deletes the throwaway place's recovery copies before opening it, reads only the log that names its own place (other sessions' Studio windows write the same `server foundation ready` line, which once made it think Play had started), and if a plain F5 hasn't started Play after 45 seconds, brings its own window forward and presses again.


## 2026-11-04 - Spend texels where they're seen; supersample painted lines

**Owner:** the grove mountain looked low resolution close up. **Causes:** the three 2048 maps arrived at 1024, 38% of the mesh area was the flat underside below the ground, and smart projection left about a third of each map empty: 2 to 4 texels a stud. Each texel was painted from one sample, so hard-edged lines stair-stepped when magnified. **Rules now:** measure texels a stud from the exported mesh before judging; split big pieces into blocks of equal *visible* area, give hidden faces their own tiny map, and paint at twice the size and average down (`supersample`). **Checking:** `gun_check.ps1` matched `GUNCHECK` case-insensitively, so Studio's own "open place ...SlugshotLobbyGunCheck" line counted as Play having started and Play was never retried; it now matches case-sensitively. **Limits:** one-client desktop Studio. [Notes](lobby-hub.md#zone-strips-ring-edge-pylon-tops-shop-and-mountain-owner-2026-11-04).

## 2026-11-04 - Steep relief needs a scaled field; the library camera is narrow

- **Problem:** in the far side cave study, distant spires came out as horizontal stripes and the cave walls speckled. Raising the march budget did nothing.
- **Cause:** the cave walls' rocky folds (`smoothstep` on `abs(noise)` times 3.2) bent the distance field about three times steeper than a true distance, so rays skipped through thin parts. **Fix:** scale that field (here by 0.4); the shape is unchanged. Check a new relief term's slope before blaming the step count.
- **Camera:** the library's views have a narrow field of view, so a steep look-down from a cliff shows only the floor in front. Stand at the edge and look out a little downward instead.
- **Owner on the spire:** stacked rounded masses read as soft; the owner wanted the grove mountain's sharp, jagged look. Reuse the mountain's construction (star ridges, flat faces between jittered corners, ink on the smooth form's ridges) for any new rock that should feel related.
- **Layered mist cuts thin columns into floating boxes** when seen from just above it; frame spires so their tips stand clear of the layers.
- **Ink down the spires:** ridge lines painted from the smooth form's curvature, plus the renderer's valley creases, ran straight down every spire, and the owner found them too thick and empty. On tall ridged forms, keep the outline and a few thin facet edges.
- **Round arcs of ink on big masses:** the shared `chunk` returns its bounding sphere outside 0.4 units, and at cavern scale neighbouring masses blend inside that sphere, so the field kinks and the crease ink draws arcs. Use the full shape (`fcChunk`) for masses this large.
- **Cutaways:** a cave cut out of infinite rock shows as grey slabs; keep a shell of rock round it instead. Mist that only rock hid must then be limited to the cave itself.

## 2026-11-04 - Faceting round a column reads as a spiral

- **Owner:** the faceted spires looked "too spirally", like narwhal tusks. **Causes, in order found:** ridges twisted with height; a ridge-depth pattern of angle plus height, which is a helix; the mountain's sheared triangle grid, which wraps a cylinder as a helix; and one shared split diagonal, which lines face edges into a slanted grain. **Fix:** straight ridges with per-ridge patterns, rows offset alternately (zigzag), and a random diagonal per square. The mountain's grid is fine on a plane, not round an axis.
- **Walls:** scaling up the approved small rock wall gave rounded, repeating pillows. Heightfield facets over shallow relief read as crumpled low-poly paper, and big planar wedges as plain slabs. Solid pieces with strong relief and two sizes (broken blocks, fused crags) read as rock at cavern scale.
- **render_still.py takes the variant's index, not its option number.** Removing a variant shifted every later index, and two option renders came out labelled as each other. Check a render's look against its label after editing the variant list.

## 2026-11-04 - A ridged taper is still a cone

Ridges, facets and shoulders on one even taper still read as a cone (owner: "too uniformly coney"). What changed the read was the silhouette: non-monotonic width with hard kinks, a broad body with a short broken top, flattened tiers turned different ways, fracture planes that move the summit off-centre, and notches. Check the outline first; surface detail can't fix it. Don't shade faces by a quantised normal: the numerical normal jitters across a rounding boundary and draws contour bands.

## 2026-11-04 - Big cuts make flat sides; use the real crystals; watch the GPU log

- **Flat sides:** SDF plane cuts break a silhouette but leave blank sheets, and the owner saw detail on two sides only. Apply breaks to the facet corners instead, spread evenly by angle, and check a turntable of four sides.
- **Stand-ins:** `chCrystal` was the canopy hole's generated stand-in, not an approved design. Check `CRYSTALS` in the library and use those layouts and colours. Big-scene convex ink only marks a crystal's corners, as dark stars: shade its facets instead.
- **GPU resets:** an unexplained exit 127 from `render_still.py` with no output was a GPU reset, shown as `nvlddmkm` event 153 in the System log. Check that log and that files exist after heavy renders, set `LOBBY_BANDS` higher for heavy scenes, and cut per-pixel cost (here: costly surface searches for dressing that couldn't reach the point).

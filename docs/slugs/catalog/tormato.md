# Slug design record: Tormato

## Implemented - in the game place, seen in one Studio client, 2026-11-16

**Mouth and spinning eyes (2026-11-16, owner through the slug-idle session: the slugs "don't have any mouth movement"; "animate Tormato's eyes ... Make them have a spin"):**
- **Mouth:** base export adds `mouth_L`, `mouth_R`, `mouth_low` under `head` ([`mouth_rig.py`](../../../tools/slugs/mouth_rig.py), the slug-idle session's helper): corners (0.305, 1.388) and (-0.265, 1.331), lower lip (0.020, 1.183), reach 0.08. Posed in Blender: the corners lift into a smile and the lip drops open cleanly.
- **Eyes:** [`tormato_eyes.py`](../../../tools/slugs/tormato_eyes.py) cuts each open eye out of the body before it is painted, moves the cut's edge onto the almond, and puts a round storm disc behind it on `eye_L`/`eye_R` (bone head on the disc's centre, bone Y the eye's axis), in one `TormatoEyes` mesh with the ink lines fixed to `head` in front of it. The disc is a surface of revolution kept behind both the rim and the brow at every distance from its centre, so it can turn freely; the export asserts no disc vertex pokes through the skin. SlugIdle spins them.
- **Changed from the concept, because of the spin:** the storm's rings are round, not squashed to the almond; the lid's shadow over the top of the eye and the rings' drift and parallax are gone (they'd turn with the disc).
- **Verified:** Blender (GLB reimported, bones turned about Y) and Studio (Edit, model loaded from the new upload with its materials, `Bone.Transform` turned 60 degrees): the storm turns in place; almond, ink and rim stay put. In the game, SlugIdle turns them opposite ways (about 0.59 rad per 0.375 s) and the slug-idle session saw the storms turn cleanly in Studio; his HUD canister loop is re-recorded with eyes and mouth moving. Owner verdict on the round rings pending.

**Owner, 2026-11-16:** "do that for this slug and also for [Boon Doc] ... add both into Studio. There's another chat that's working on ... general animations for all the slugs ... I would like it [to apply to these]." On six slugs and five slots: "this is what the inventory is for, make it so you can swap out the slugs in your HUD bar using inventory".

- **Game models:** [`export_tormato_roblox.py`](../../../tools/slugs/export_tormato_roblox.py) reduces each form to 18,500 triangles (face kept finer), bakes normals and contact shading, and paints 2048 colour and glow maps from the concept shader at each texel (texel points snapped onto the surface, probes 20 and 21 in `build_tormato.py`). Game scale 0.41: base 0.96 studs tall, transformed 2.0 studs wingspan and 1.5 long.
  - Base rig: `root`, `body`, `head` (the bones the shared slug idle uses).
  - Transformed rig: `Body`, `Head`, `Tail1`, `Tail2`, `Wing1-3.L/R` (arm, hand, tip).
  - Checked by reimporting both GLBs and posing the wings, tail and head: clean bends. Every bone carries weights (Roblox drops bones that don't).
- **Upload:** [`upload_tormato.py`](../../../tools/slugs/upload_tormato.py) uploaded both models and maps as private assets; ids and SurfaceAppearance templates only in ignored `private-assets/tormato/`.
- **In the game:** `CombatServer` builds `TormatoIcon`, `TormatoFlight` and `TormatoTransformed` (a shared `buildConceptSlug` for him and Boon Doc), dressed by [`TormatoAppearance`](../../../experiments/creatures/tormato/server/TormatoAppearance.luau); `FloppyBlaster` fits `TormatoLoaded` in the gun's canister (shared `fitConceptSlug`); `Combat.Slugs.Tormato` with prototype flight numbers (damage 18, speeds 240/320/400, gravity 22, drag 0.06; Tornado and Updraft not built); `TransformationStyles` vermilion glow.
- **Motion:** [`TormatoMotion`](../../../experiments/creatures/tormato/client/TormatoMotion.client.luau): in the gun's canister, the top drifting round in a slow circle with the head a beat behind; in flight, the flap travelling out along each wing (20, 14, 12 degrees, each bone 0.7 rad behind), the tail swinging, the body rolling, and thin pale wind trails off both wing tips and the tail tip (`FlightTrail`). The HUD canister idle is the other session's `SlugIdle` (quick breaths, two darting head looks, a small bounce); they captured his canister idle loop (two flipbook sheets, GooArt canisterIdleTormato1/2, 176 frames), seen playing in Studio.
- **Loadout:** in the game place he is carried in slot 5 by default; the inventory swaps him with any slot.

**Verified in Studio (one client, real F key for the inventory):** both forms load, every bone imported, no errors from him in Output; he faces front; the base form's face, mark, bands and belly, and the transformed form's horns, wings and face render as the concept; his wind trails run off the wing tips. **Not yet seen:** a shot transforming and flying (the training arena never signalled ready in that session); eye and lid parts for idle expressions are not built (painted eyes). Combat numbers are prototypes.

## Implemented - Blender source models of both final forms, not in Studio, 2026-11-16

**Owner:** "okay perfect, build this design out in blendere too like u did with boon doc". **Implemented:** [`build_tormato.py`](../../../tools/slugs/build_tormato.py) rebuilds both forms from the concept page itself, as Boon Doc's and Aquabeek's builds do ([ADR 0033](../../decisions/0033-concept-shader-sampling.md)): the page's own shader sampled in headless Chrome, meshed with surface nets, each vertex snapped onto the surface, with vertex colour, glow and part membership (`parts`: r wings, g horns, b tail) for the rig later. The page's time uniform stays 0, and a new `REST 1` switch holds the transformed form straight with its wings level (at time 0 its body wave and wing flap would still bend it); the page renders are unchanged with it off. The base form keeps its slight lean. A sampling-box check stops the build if anything touches the box's sides.

- `assets/source/slugs/models/tormato/tormato-base.blend`: `TormatoBody`, 236,201 vertices (0.008 grid), no loose islands, no diverged snaps.
- `assets/source/slugs/models/tormato/tormato-transformed.blend`: `TormatoTransformedBody`, 346,488 vertices on a 0.009 grid (slightly coarser so the 5 x 2 x 4 box stayed within the free memory: about 1.5 to 2 GB with Studio open), no loose islands, 1 snap left unmoved.
- The build unpacks the sampled distances in float32 (exact for the 24-bit values) rather than the shared float64 unpack, roughly halving the peak memory.
- Review renders (front, three-quarter, side, back) and report.json in ignored build/slugs/tormato/source/.

**Verified:** both forms' renders match the approved concept (Eye of the storm eyes, tornado mark, grin and fangs, horns, crimson bands, belly; transformed: ram curls, wings with bones and grey-fraying edges, flat belly, grey tail tip), and the wing membranes have no holes; the transformed file opened in the owner's Blender in Material Preview. **Not done:** rig, skin weights, game mesh and texture bake, export, upload and Studio. **Unresolved:** owner's look at the Blender files.

## Confirmed - final transformed design, 2026-11-15

**Owner:** "okay perfect, build this design out in blendere too like u did with boon doc"

**Confirmed (owner):** transformed round 7 below is the final transformed design. Accepted means stop: change it only on request. A red dragon after the show's transformed form, carrying the final base face (Eye of the storm eyes, the grin with two fangs, the tornado mark): ram horns curled up over the head like Rammstone's, tilted outward; dragon wings with an arm bone, three finger bones and a scalloped membrane fraying into storm grey, flapping in a wave along the span; a compact dragon's torso with a flat belly like Inferno's, no arms or legs; a short red tail striped with the crimson twister bands, ending in a small storm-grey tip. **Saved:** page and all 52 frames (both forms) in [evidence/tormato/transformed-final](evidence/tormato/transformed-final/tormato-final.html); the template builds it (`XF 1`, form key `comet`); base frames still match base-final exactly. A `REST 1` switch (added for Blender) holds the body straight and the wings level; with it off, every frame is unchanged.

## Implemented - transformed form, round 7, final, 2026-11-15

**Owner on round 6:** "i think lets flatten out the belly like inferno"

Round 6's frames are kept in [evidence/tormato/transformed-6](evidence/tormato/transformed-6/). Base frames still match base-final exactly.

- **Flat belly, like Inferno's transformed form:** the underside is sliced level by a plane at y 0.88 under the chest, rising 0.14 per unit toward the tail, blended with a soft edge (0.12), and faded out toward the head (from z 0.05 to -0.25) so the jaw and face are untouched. The rounded chest no longer hangs below the head; the yellow belly now faces down, so it shows mostly from below and the front.
- Everything else as round 6.

**Draft, not shown:** fading the cut's value toward the head (rather than blending the cut and uncut shapes) pinned the inside of the head to zero, damaging the face, and with the plane at y 1.00 the body was too thin.

**Verified:** all 24 turntable frames, the face close-up and the view from above, inspected; a side-by-side of the side view before and after. **Unresolved:** the owner's verdict.

## History - transformed form, round 6, 2026-11-15

**Owner on round 5:** "body is very long both torso and tail neeed to be shortened"

Round 5's frames are kept in [evidence/tormato/transformed-5](evidence/tormato/transformed-5/). Base frames still match base-final exactly.

- **Torso about a third shorter:** chest `(0, 1.22, -0.72)` radii `(0.62, 0.56, 0.58)` (was centred at -0.78, 0.66 deep), waist `(0, 1.24, -1.08)` (was -1.30), haunches `(0, 1.28, -1.36)` 0.36 deep (was -1.68, 0.44); the body now ends about 1.75 behind the head's centre (was 2.1).
- **Tail shorter:** starts 1.50 behind the head (was 1.85) and is 1.60 long (was 2.40), the same taper, stripes and small grey tip.
- **Camera:** the transformed turntable moved in (distance 8.8, centred at z -0.90).
- Wings, horns, face unchanged.

**Verified:** all 24 turntable frames, the face close-up and the view from above, inspected. **Unresolved:** the owner's verdict.

## History - transformed form, round 5, 2026-11-15

**Owner on round 4:** "make the horns kinda tilt outwar4ds a bit"

Round 4's frames are kept in [evidence/tormato/transformed-4](evidence/tormato/transformed-4/). Base frames still match base-final exactly.

- **Horns tilted outward:** each curl's plane leans outward by 0.40 rad (`RAM_TILT`, about 23 degrees), turning about the root so the root stays put; from the front the curls now open in a V. Everything else as round 4.

**Verified:** all 24 turntable frames, the face close-up and the view from above, inspected. **Unresolved:** the owner's verdict.

## History - transformed form, round 4, 2026-11-15

**Owner on round 3:** "remove the grey tail finish, just do the nrmal striped bit, with a small grey tip, like we do with other slugs antennas, then remove the arms and legs, make the horns be more up, so theyre less in the slugs face, like rammstones horns"

Round 3's frames are kept in [evidence/tormato/transformed-3](evidence/tormato/transformed-3/). Base frames still match base-final exactly.

- **Tail:** no tornado funnel. A long red tail (2.40) tapering from the haunches to a point (`0.40 (1 - t)^1.1 + 0.012`), curving up a little, striped with the twister bands to 0.88 of its length, with a small storm-grey tip from 0.86 to 0.91 onward, paling at the very end.
- **No arms or legs:** the limbs, claws and muscle masses removed.
- **Horns raised:** the curl's centre moved up and back to (y 2.20, z -0.28); from the root (start angle -0.528 rad, radius 0.417) each rises up and back, curls over the top, behind, down and forward to 4.90 rad, tightening to radius 0.15, the point forward; spreading out from x 0.30 to 0.62 toward the head's top corners. Thickness unchanged (0.165, tapering near the end).
- **Kept:** the face, the dragon wings (the owner's pick), the torso, bands and belly.

**Draft, not shown:** with the curl raised but barely spreading (x 0.30 to 0.55), the two curls stood close together over the head like tall ears from the front.

**Verified:** all 24 turntable frames, the face close-up and the view from above, inspected. **Unresolved:** the owner's verdict.

## History - transformed form, round 3, 2026-11-15


**Owner on round 2:** "Okay, it's much better. But the tail looks weird because it's just a random spiral. And the legs and arms are just look like they're slapped on. And then ... the horns, make them be more like ramstone's where they're more like curled and pointed or pushed forward ... And then the wings are good. Just don't like the arms and legs, and the tail. And the horns."

**Confirmed, owner:** the wings. Round 2's frames are kept in [evidence/tormato/transformed-2](evidence/tormato/transformed-2/). Base frames still match base-final exactly.

- **Horns, curled like Rammstone's:** from the same roots each rises, arcs back and curls tightly down behind and round, the point pushed forward: a tightening spiral (radius 0.34 to 0.15, 5.75 rad from the front over the top, back, down and forward), centred at y 1.99, z -0.26, drifting out from x 0.30 to 0.74 to clear the head; 24 capsules joined with plain min; radius 0.165, staying thick to about halfway, tapering to 0.010. Ridged, storm-grey tips.
- **Legs, grown in:** shoulder `(0.38, 1.10, -0.68)` and thigh `(0.36, 1.14, -1.58)` muscle masses blended into the body (0.14 to the legs, 0.18 to the body); thicker limbs (0.15); the front legs fold forward under the chest to claws at z -0.16, the hind legs trail back along the belly to claws at z -2.08.
- **Tail, a dragon's ending in a tornado:** the red tail tapers smoothly from the haunches (radius `0.40 (1 - t/0.62)^1.2 + 0.06`) and curves up a little (`0.20t^2`); from 0.62 of its length a smooth funnel opens out behind the tip to radius 0.36 and rounds over like a cloud top (0.30 long). No lumps: storm grey with three clean pale lines of wind spiralling up it and turning, a pale ring where it leaves the red. The bands stop before the funnel; the belly narrows to nothing before it.

**Bugs fixed on the way:** black patches on the funnel's end were NaN normals: inside the tail the distance was a flat zero (the along-the-tail term was clamped at 0), so there was no gradient; the along term is now signed. Also guarded: a band of zero width made `smoothstep` take equal edges; the belly's width divided by zero on the funnel; negative bases in `pow` on the unchosen side of a ternary.

**Verified:** all 24 turntable frames, the face close-up and the view from above, plus a 1000-pixel crop of the tail end, inspected. **Unresolved:** the owner's verdict on horns, legs and tail.

## History - transformed form, round 2, 2026-11-15


**Owner on concept 1** (with a new reference: the show's red dragon in flight, big ram horns curling round its head, clawed legs, membrane wings, a grey tornado trailing behind): "Doesn't really look like the reference image that much. Should have like more, the horn should be grown out better. The wings look way too stiff. Face looks too much like the base slug rather than looking like it's more grown ... To be fair, face is fine. I guess the horns will fix that. Then the body is just weird. It's okay, but yeah." The reference is study material and is not stored.

Concept 1's frames are kept in [evidence/tormato/transformed-1](evidence/tormato/transformed-1/). Base frames still match base-final exactly.

- **Horns, grown:** thick ram horns from the same roots, two quadratic sweeps joined in line: `(0.30, 1.99, 0.08)` through `(0.66, 2.38, -0.10)` to `(0.80, 2.12, -0.46)`, then on through `(0.91, 1.91, -0.75)` to a tip at `(0.86, 1.70, -0.42)` pointing forward beside the head; radius 0.170 to 0.020; ridged (a darker ring every 0.09 along), storm-grey tips.
- **Wings, dragon not board:** in the wing's plane, a leading edge `0.15 + 0.95x(1 - x/1.6)` bulging forward to the wrist at (0.80, 0.50) then sweeping back to the tip at span 2.05; trailing edge `-0.72 + 0.12x` with scallops 0.20 deep every 0.47; an arm bone, a hand bone to the tip and three finger bones, raised 0.022. The flap is a wave travelling out (`x(0.30 + 0.22 sin(2.6t - 1.2x))`), so the wing bends. Membrane vermilion deepening toward the root, the scalloped edge fraying into storm grey; bones darker crimson. Rooted at x 0.42, y 1.52, z -0.95.
- **Body, a dragon's:** the head flows into a thick neck `(0, 1.56, -0.40)`, a deep chest dropping below the head `(0, 1.22, -0.78)` radii `(0.62, 0.56, 0.66)`, a narrower waist `(0, 1.24, -1.30)`, haunches `(0, 1.28, -1.68)`. Front legs reach forward under the chest, hind legs trail back, each two tapered segments (radius 0.13 to 0.14) ending in three pale claws.
- **Kept:** the face, the tornado tail (now from 1.85 behind the head), bands and belly.

**Verified:** all 24 turntable frames, the face close-up and the view from above, inspected. **Still wrong (assistant):** from the front the head still reads as a round ball over the body; the legs are short; the wings' resting angle is high. **Unresolved:** the owner's verdict.

## History - transformed form, concept 1, 2026-11-15


**Owner:** "Let's move on to the transformation." Method (design language): the show's silhouette, the slug's own face and theme, elegant execution; a transformed form is a new body, not the base with parts added. The show's transformed form is a red winged dragon trailing grey wind. Inferno is already a slug-dragon (big bat wings, a flame on the tail), so concept 1 keeps the winged-dragon outline and changes the wings and tail.

Built in the base form's template behind `XF 1` (form key `comet`), as Boon Doc's is, so the face code is shared. Base frames still match [base-final](evidence/tormato/base-final/tormato-base.html) exactly (max pixel difference 0).

- **Head and face:** the base head, crown and muzzle unchanged, with the Eye of the storm eyes, grin and fangs, tornado mark and swept-back horns; the back of the head flows into the neck (`(0, 1.58, -0.38)`, radii `(0.54, 0.42, 0.58)`).
- **Body:** flying level along +z: neck, deep chest `(0, 1.36, -0.78)` radii `(0.62, 0.50, 0.80)`, body `(0, 1.32, -1.45)`; gliding with a bob and a slow wave running back.
- **Wings:** long, slender, swept-back sickle wings like a swift's from the shoulders (root x 0.45, z -0.62), span 1.85, leading edge sweeping back `1.05 u^1.5` to a fine point, trailing edge curved; thicker toward the root and leading edge; a slow, shallow beat. Vermilion on top, butter yellow underneath, the outer third greying into storm and wind.
- **Tornado tail:** from 1.75 behind the head, 2.5 long: a funnel `0.42 (1 - t)^1.5 + 0.028` snaking to one side (`0.30 sin(3.6t) t`), three spiral ridges (16%) turning with time; red at the root turning storm grey, the ridges catching pale wind light, paling toward the point.
- **Twister bands** along the body, tightening backward, ending where the tail turns grey; **belly** butter yellow underneath from under the chin, narrowing down the tail.

**Drafts, not shown:** with the base head alone on the body, the head read as a ball stuck on the front, and a short red tail read as a snake; the back of the head now flows into a bigger body, and the tail is a longer grey funnel.

**Verified:** all 24 turntable frames, a face close-up and a view from above rendered and inspected. **Unresolved:** the owner's verdict on the direction (wings, tornado tail, body length); the head still reads round from the front; Blender build and Roblox look.

## Confirmed - final base design, 2026-11-15

**Owner:** "Okay, straight looks good. Finalize that base design. Let's move on to the transformation."

**Confirmed (owner):** round 10 with the straight tornado mark is the final base design. Accepted means stop: change it only on request. Round 10's frames of both marks are kept in [evidence/tormato/round10](evidence/tormato/round10/).

- **Body:** Boon Doc's approved body plan, crown a little taller (`(0, 1.86, -0.02)`, radii `(0.53, 0.40, 0.48)`); the pooled base's lobes twist as they rise; a short plain tail. Vermilion `#D8472C` deepening to `#A8301F` down the back and warming to `#E9693F` over the muzzle; butter-yellow belly `#F5D872` with faint air ripples and a warm edge line.
- **Eyes:** Eye of the storm (rings wheeling round a calm bright middle, no pupil, iris or white) in an almond (half-width 0.262, arches 0.178 and 0.128, upper peaking toward the inner corner, lower lowest toward the outer, inner end rounded), centres at x 0.340, positive canthal tilt 0.075 per unit plus a 0.022 outer lift. Sculpted depth: rim 0.020 below the skin, a glassy cap 0.014 proud, a rolled upper lid and crease, the storm drawn 0.075 below the glass along the view ray. The confirmed shape is the almond.
- **Horns:** short, thick pale-yellow horns swept back by the wind, storm-grey tips: one quadratic sweep `(0.30, 1.99, 0.08)` to `(0.50, 2.14, -0.22)` to `(0.53, 2.33, -0.46)`, radius 0.130 to 0.012.
- **Mouth:** a lopsided open grin at y 1.325, half-width 0.285, depth 0.142, tilt 0.10, corner curve 0.42; a row of top teeth; two round cone fangs from behind the lower lip at x -0.140 and 0.135.
- **Twister bands:** four crimson bands spiralling up the body, tight near the base and opening toward the shoulders, one long tapering stroke per turn with a slow wave, finer lines between them from y 0.70; solid crimson lightening along the upper edge; they turn slowly.
- **Forehead:** a straight tornado mark, one solid crimson funnel from a point just above the eyes to a rounded top 0.150 wide on each side, with thin curved gaps slanted a touch.
- **No** wind rings or aura (Boon Doc's alone), no back gusts, no cloud.

**Saved:** page and all 26 frames in [evidence/tormato/base-final](evidence/tormato/base-final/tormato-base.html); the template builds it as form `base`; published to <https://claude.ai/artifact/TEzgN1R1bSkDf3c4aCRsqZ> version 9 (rounds 1 and 2 were at an earlier link under another account). **Next:** the transformed form. Blender build and Roblox later.

## History - base-form visual concept round 10, 2026-11-15


**Owner on round 9:** "Okay, almost there. My only critique is that I don't like how it's only going to one side. Either make it turn left and then end right, or make it be like straight."

Round 9's frames are kept in [evidence/tormato/round9](evidence/tormato/round9/).

- **Tornado mark (option t):** the same solid funnel; its gaps now curve evenly (`y - 0.08x - 0.9x^2`, every 0.050) with only a slight slant, since round 9's strong slant also leaned it one way. t0 **S-curve** (default): the centre line `-0.032 sin(5.34(1 - u))` drifts toward his right (the viewer's left) as it narrows, then the tail ends toward his left. t1 **Straight:** upright and even.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for both (12 frames), inspected. **Unresolved:** the owner's pick and final word on the base form; the eye shape (Almond) to confirm; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 9, 2026-11-15


**Owner on round 8:** "The teeth are good. The tornado mark reads as forehead wrinkles."

**Confirmed, owner:** the round cone fangs. Round 8's frames are kept in [evidence/tormato/round8](evidence/tormato/round8/).

- **Tornado mark, one silhouette:** five separate stacked strokes on a forehead read as wrinkles, however clean. Now one solid crimson funnel on the head's arc: half-width 0.006 at the tip (y 0) widening as `u^1.35` to 0.150 at the top (y 0.235), the top bowing up 0.022; its centre line snakes (`0.042 sin(4.5u - 0.9)(1 - 0.6u)`) so the tail curls. Thin skin-coloured gaps every 0.050 run across it on a slant (rising 0.32 toward his right, bowing slightly), so it reads as spinning. Lighter on his right, the lit side.

**Verified:** all 24 turntable frames and the face and belly close-ups, plus an 800-pixel forehead crop, inspected. **Unresolved:** the owner's final word on the base form; the eye shape (Almond) to confirm; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 8, 2026-11-15


**Owner on round 7:** "Okay, this is perfect. Let's do the tornado mark. Make it look a bit cleaner first, though. It looks a bit not blurry, but it's not clean. Very bumpy. It should look clean, kind of like the body marks ... And also, when you look at this smile from like the side or from 3/4, the bottom canines can look a bit chunky and weird. Just not defined."

**Confirmed, owner:** round 7's design is "perfect" apart from the two fixes; the tornado mark is the forehead. The page has no option rows left (one form, `base`, full turntable). Round 7's frames are kept in [evidence/tormato/round7](evidence/tormato/round7/).

- **Tornado mark, cleaner:** round 7's strokes were each two straight tapers joined into a diamond, with a kink in the middle, a stepped join and a blob at the tip. Now five strokes, each one smooth lens (half-thickness `r (1 - t^2)^0.8`, a quarter fuller toward his left), bowing 0.018 in the middle as if wrapping round the funnel; half-lengths 0.175 to 0.039, half-thickness 0.022 to 0.010, at y 0.215 to 0.031 on the head's arc, nudged sideways (`0.026 sin(1.7i + 0.4)`) so the funnel twists. Shaded like the bands: solid crimson lightening along the upper edge, the same soft edge.
- **Fangs:** were the front outline pushed straight back, so from the side or three-quarters they read as slabs. Now round cones: across the face and in depth (measured by the skin's own distance, centred 0.034 behind it and leaning back 0.012 toward the point), radius 0.026 at the root to 0.003 at the tip. The top teeth are unchanged.
- **Horns:** the chain of 18 capsules showed its joints as faint ridges in close-ups; now one exact quadratic sweep (`sdBezier`) with the same curve and taper.

**Verified:** all 24 turntable frames and the face and belly close-ups, plus 1000-pixel crops of the forehead, the three-quarter mouth and the side, inspected. **Unresolved:** the owner's final word on the base form; the eye shape (Almond) to confirm; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 7, 2026-11-15


**Owner on round 6:** "Give the eyes slightly more positive [canthal] tilt ... But then also I don't like the forehead design. It's nice. It's in the right direction, but I don't really like it that much."

Same link. Round 6's frames (Swirl, Updraft, Wind lines) are kept in [evidence/tormato/round6](evidence/tormato/round6/).

- **Canthal tilt:** the eye's centre line now rises 0.075 per unit across (`CANTHAL`), on top of the outer corner's 0.022 lift: outer corners about 0.02 higher and inner corners 0.02 lower than round 6. The lid line and ink follow.
- **Forehead (option f), redesigned bolder:** measured on the head from the crown's centre (x across, y the arc up over the top from the front, both times 0.45). The forehead seen from the front is only y 0.0 to about 0.22 before the head curves away, so designs placed higher read small; all three sit low.
  - f0 **Tornado mark:** four tapering strokes stacked wide to narrow (half-lengths 0.175 to 0.061, thickness 0.030 to 0.018, at y 0.215 to 0.065), each nudged sideways so the funnel twists, ending in a small tip just above the eyes.
  - f1 **Crown swoop:** one stroke (half-width up to 0.070) from behind the top of the head sweeping forward over the crown and curling up on the forehead.
  - f2 **Widow's peak** (default): crimson over the crown coming down to a point at y 0.005, sides rising 0.95 per unit across and rippling (0.012 at 26 per unit), fading out between y 0.42 and 0.74 so the back of the head stays plain.

**Drafts, not shown:** the first placement (strokes up to y 0.34) sat where the head curves away and read tiny; the first swoop (half-width 0.030 to 0.048) read as a crack.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for each forehead design (18 frames), inspected. **Unresolved:** the forehead pick; the eye shape to confirm; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 6, 2026-11-15


**Owner on round 5:** "Okay, it's almost perfect, but the inner bottom corners of the eye is just still look a bit weird to me. Then we need to do some little design on the forehead. Just to like just spice that area up a bit. And then I feel like the mouth is a little bit too expressive now. Tone it down just a little bit so it looks the same level of expressiveness as it was before."

**Considering, to confirm:** the owner did not name an eye shape; round 5 opened on the Almond and he called it "almost perfect", so the Almond is kept and the Oval and Gust code removed. Same link. Round 5's Almond frames are kept in [evidence/tormato/round5](evidence/tormato/round5/).

- **Eyes, inner corners:** the inner end pinched to a point, and the recessed rim's wall (the eyes turn outward, so the inner wall faces the viewer) caught the light as a pale sliver. Now both arches use lower powers toward the inner corner (upper 0.58 to 0.44, lower 0.75 to 0.46, lower skew 0.16 to 0.10), so the inner end is blunt and round; the recess is 75% shallower over the inner fifth; the fine lower ink line runs right into the inner corner.
- **Mouth, calmer:** kept at y 1.325; half-width 0.300 to 0.285, depth 0.155 to 0.142, tilt 0.12 to 0.10, corner curve 0.50 to 0.42 (`MCURVE`), corner creases shorter. The bottom fangs still clear the top teeth.
- **Forehead (option f):** a small crimson mark centred at (0, 2.06), drawn as seen from the front, only on the front of the head. f0 **Swirl** (default): an Archimedean spiral, 0.0105 per radian, 1.75 turns, line half-width 0.003 at the heart to 0.012 outside, tapering at its outer end. f1 **Updraft**: three stacked chevrons rising (for his passive), half-spans 0.082 to 0.054, tapering from 0.012 at the point to 0.004. f2 **Wind lines**: three staggered streaks blowing toward his left with a slight wave, 0.012 at the start tapering to 0.003.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for each forehead mark (18 frames), and a 900-pixel face close-up of the eye corners, inspected. **Unresolved:** the forehead pick and verdict; the eye shape to confirm; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 5, 2026-11-15


**Owner on round 4:** "Move the smile a bit up and make it a little bit wider. And then do something with the eye shape. The eye shape is a bit weird. Spirals are nice, but on one part of the back, it just feels like it's a bit empty because there's no spiral thing there. So maybe add some lines in that area ... top right, top left, I can't remember which one. And then move the [horns] just a tad bit forward on the head ... And then shorten the horns a bit as well." (He said "heads"; read as horns.)

Same link as rounds 3 and 4. Round 4's frames are kept in [evidence/tormato/round4](evidence/tormato/round4/).

- **Mouth:** centre raised from y 1.290 to 1.325, half-width 0.270 to 0.300; fangs moved out to x -0.140 and 0.135.
- **Horns:** root moved forward from z 0.00 to 0.08 (`(0.30, 1.99, 0.08)` through `(0.50, 2.14, -0.22)` to `(0.53, 2.33, -0.46)`), about a fifth shorter; root radius 0.135 to 0.130.
- **Twister bands, upper back:** the funnel opens toward the shoulders, so the bands spread apart there and the gaps between strokes left bare patches (the owner saw one on the upper back). A finer line (half-width up to 0.085 of the band spacing) now runs between each pair from y 0.70 up, its strokes offset half a turn from the main ones.
- **Eye shape (option e):** round 4's lemon shape (outer corner lifted, lid cut lower toward the nose) is gone; no lid tilt in any option.
  - e0 **Oval:** half-width 0.250, arches 0.168 and 0.150, elliptical, no corner lift.
  - e1 **Almond** (default): half-width 0.262, arches 0.178 and 0.128; the upper arch skewed to peak toward the inner corner (`x (1 - 0.16u)`), the lower lowest toward the outer (`x (1 + 0.16u)`), the outer corner lifting 0.022.
  - e2 **Gust:** half-width 0.290; round at the inner end, both arches tapering by up to 62% toward the outer end, which rises 0.060: a teardrop narrowing outward. The lid roll covers only the round end.
  - Each option centres and sizes the storm to its own shape (`ECEN`, `ESC`).

**Drafts, not shown:** the first Gust (taper 80%, lift 0.085) lost its tail to the eyes' outward turn, and the lid roll following the tail rippled like a brow fringe.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for each eye shape (18 frames), inspected. **Unresolved:** the owner's eye-shape pick and verdict; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 4, 2026-11-15


**Owner on round 3:** "Remove the mohawk. So let's just do the horns only. Give the eyes more depth. Right now they look quite flat. And painted on, I guess. And then with the mouth, I think we need to make it a little wider vertically. Just so you can see the fangs properly, because right now they're kind of hidden. Under the top row of teeth. And then I like the crimson bands, but they look a bit weird to me. They look kind of blocky and thick ... Not fluid."

**Confirmed, owner:** horns only (no mohawk); crimson bands (not grey). The page has no option rows left; one form, `base`, with a full 24-frame turntable. Round 3's horns-only frames are kept in [evidence/tormato/round3](evidence/tormato/round3/).

- **Eyes, depth:** sculpted, not painted (lesson row 141: a shallow dome reads as a sticker). The rim sits 0.020 below the skin and the eye rises in a rounded cap (`sqrt` profile, 0.034 high) to only 0.014 proud of the skin; the upper lid rolls over the top edge (+0.011 at 0.014 above the lid line, a 0.004 crease at 0.062), fading toward the corners; same skin, no lid band. The storm is drawn 0.075 below the glass at the middle, falling to nothing at the rim, along the view ray (parallax), so the rings sink in like a funnel and slide against the rim as he turns. Inside the eye: shadowed up to 45% under the lid roll and darkened to 55% in the recess at the rim; its glow is halved under the lid. The eye's surface is glassy: a crisp highlight (power 140), a rim-light highlight and a faint sky reflection, on top of the skin's tight highlight (the broad sheen stays masked off).
- **Mouth:** depth 0.115 to 0.155 and the top teeth 0.048 to 0.046 deep, so the bottom fangs' tips sit about 0.026 below the top teeth instead of behind them.
- **Twister bands:** half-width 0.165 of the band spacing at most (was 0.21 with a square-root profile), one long stroke per turn (was two) shaped `sin(pi q^1.5)` over 84% of the turn, so each is fine at both ends and fullest past the middle; a slow wave (`0.16 sin(2 th + 2.5y)`) so the lines flow; the belly, face and base edges thin each stroke to a point instead of cutting it. Solid crimson (`CRIMSON*0.80`) lightening only along the upper edge; raised just 0.002; no ink edge.
- **Removed:** the mohawk, the grey band option.

**Drafts, not shown:** at half-width 0.115 the bands read as thin cuts; a dark lower edge with a raised ridge read as folds or grooves in the skin.

**Verified:** all 24 turntable frames and the face and belly close-ups rendered and inspected; both fangs clear of the top teeth in the close-ups. **Unresolved:** the owner's verdict; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 3, 2026-11-14


**Owner on round 2:** "I like the swept back horns. But I think a mohawk would look really cool in it, like a spiky mohawk. So maybe just test that out. And then I don't like the back design and the back of the head design ... just remove it and then do like the twister bands design, but make it look more like it's like twisting around ... because it's like tornado-y."

**Confirmed, owner:** the swept-back horns (round 2's h4). The back gusts and the storm cloud are removed. The twister bands are the body pattern, reworked to twist round him. **Being tested:** a spiky mohawk. Private artifact: Round 3, a new link, because the session's signed-in account changed and the round 1 and 2 link belongs to the previous account. Round 2's swept-back horn frames are kept in [evidence/tormato/round2](evidence/tormato/round2/).

- **Horns:** round 2's swept-back horns unchanged; the other horn and antenna options removed from the page and the shader.
- **Mohawk (option h, h1 the default):** six spikes down the midline of the crown, rooted round the crown ellipse from 0.55 rad in front of the top to 1.45 rad behind, each a quadratic Bezier swept back 0.55 rad and curving to 0.85 rad at the tip; length 0.20 + 0.28 times a bump peaking just behind the top; root radius 0.105 scaled by the square root of the length, tapering to 0.006; flattened side to side by 1.5; spikes joined with `smin` 0.03 and blended into the head with 0.05. Dark storm grey at the root paling to wind at the tips. h0 is the horns alone.
- **Twister bands:** four bands spiralling up the body, `u = 4 th/2pi + 3.4y - 0.5y^2`, so they are wound tight near the base and open into steeper sweeps toward the shoulders. Each band is broken into two brush strokes per turn with a thin tail and a thick rounded head (half-width up to 0.21 of the band spacing, varied per band), turning at 0.5 rad/s, raised 0.007 off the skin, dark along the lower edge and light along the upper, with a fine ink edge. They run from y 0.08 to 1.62 at the back and stop at 1.08 in front of the face, tucking under the belly's edge. **Colour (option p):** p0 crimson (the default), p1 storm grey.
- **Removed:** the two back gusts, the storm cloud, the more-gusts option.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for the default and each option on its own (18 frames), inspected. The first mohawk (spikes 0.15 to 0.36 long, flattened by 1.8) was too thin to read and was enlarged. **Unresolved:** whether the mohawk stays; the band colour; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 2, 2026-11-14


**Owner on round 1:** "I like Eye of the Storm but then the horns are like a bit weird ... they're too similar to the base design. So we need different styles of horns or just normal antennas or something. And then remove the little aura around it, only the healing slug has it because it's like unique in it. And then move the eyes a little further apart ... generate multiple different horn slash antenna style designs. And then add a second fang on the bottom row, so it's like two fangs. With a top row of normal teeth. Mouth is a bit perfect though. And then like improve just the general body patterns and stuff ... it looks too basic and it just looks like two solid colours."

**Confirmed, owner:** Eye of the storm. The corkscrew horns are rejected as too close to the reference. No wind rings: an aura is Boon Doc's alone. Read as approval, to confirm: "Mouth is a bit perfect" taken as the grin being right, so only the fangs changed.

Same page and build script, two option rows instead of the eye row. Private artifact: Round 2 (same link as round 1). Round 1's Eye of the storm frames are kept in [evidence/tormato/round1](evidence/tormato/round1/).

- **Eyes:** Eye of the storm only. Centres moved out from x 0.300 to 0.340 (z 0.525), the axis turned out a little more (`s*0.47`).
- **Mouth:** the same grin; the snaggle tooth replaced by two bottom fangs at x -0.125 and 0.120, heights 0.064 and 0.056, base half-width 0.029 tapering to 0.009; the top row unchanged.
- **Wind rings:** removed.
- **Colour, all options:** a warmer vermilion `#E9693F` over the muzzle; faint wavy ripple lines across the belly (every 0.15 of height, fading toward its edges); a warm red line along the belly's edge.
- **Horns or antennae (option h)**, each a capsule chain of 18 segments joined with plain `min`, blended into the head with `smin` 0.07:
  - h0 **Curl antennae** (default): a stalk from `(0.22, 1.98, 0.06)` to `(0.42, 2.56, 0.02)`, then a clockwise curl (radius 0.125 tightening 55%, 4.9 rad) rolling outward; radius 0.062 to 0.020; skin up the stalk, storm grey on the curl, paling to wind.
  - h1 **Knob antennae**: up and out to `(0.46, 2.72, 0.04)`, radius 0.058 to 0.032, a storm-grey knob of radius 0.068.
  - h2 **Streamers**: back off the head from `(0.22, 2.08, -0.04)` to `(0.54, 2.12, -1.08)`, rippling, radius 0.090 to 0.012, red through grey to pale tips. Barely seen from the front.
  - h3 **Blown crest**: three tufts rooted across the crown, swept toward his right and curling over, lengths 1.35, 1.08 and 0.81, greying at the tips.
  - h4 **Swept-back horns**: pale yellow, from `(0.30, 2.00, 0.00)` back to `(0.56, 2.40, -0.70)`, radius 0.135 to 0.012, storm-grey tips.
- **Pattern (option p):**
  - p0 **Storm cloud** (default): grey over the back of the crown and head, its lower edge a row of puffs (y 1.52 at the back, lifting clear of the crown before the front), an inner puff line, inked edge.
  - p1 **Twister bands**: dark crimson tapered strokes winding diagonally round the body (0.42 rise per unit along, 0.22 apart), off the belly, below the face, cleared round the gusts.
  - p2 **More gusts**: three smaller pale-grey glyphs on his left shoulder and both sides, joining the two on his back.

**Drafts, not shown:** the cloud first capped the brow and read as a swim cap; `smin` between capsules beaded the antennae; twister bands one turn per 0.30 rise read as level straps or cuts, then as scratches on the cheeks; crimson extra gusts vanished on the deep red back.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups for the defaults and each option on its own (42 frames), inspected. **Unresolved:** the owner's horn and pattern picks; whether the twister bands read strongly enough; transformed form not started; Blender build and Roblox look.

## History - base-form visual concept round 1, 2026-11-14


**Owner request** (calling him "Tornado"): build him to "resemble the images ... but it needs to look different", as with the other slugs; "do something interesting with the eyes ... windy, like tornado-y ... I just don't like doing the human eye designs"; "keep the same color palette. Maybe we can do a touch more grey ... a bit more distinctive". The owner supplied four stills of the franchise wind slug (red-orange, pale yellow straight belly panel, curved pale-yellow horns, big human eyes, a buck-toothed grin; a red winged dragon form trailing grey wind). They are study material with no reuse rights and are not stored here.

One base-form design with three eye options, as a signed-distance concept page built by [`build_tormato_concept.py`](../../../tools/slugs/build_tormato_concept.py) from its own [template](../../../tools/slugs/tormato_concept/template.html). Page and frames: [evidence/tormato](evidence/tormato/tormato.html). Private artifact: Round 1.

- **Body:** Boon Doc's approved body stack with the crown a little taller (`(0, 1.86, -0.02)`, radii `(0.53, 0.40, 0.48)`); the pooled base's lobes twist as they rise (2.4 rad per unit height). Idle: breathing, and the top drifting round in a slow circle (0.024 by 0.012, 1.3 rad/s).
- **Horns (the one signature kept):** pale yellow `#EED68E` to cream tips, a quadratic sweep from `(0.32, 1.97, -0.04)` through `(0.62, 2.38, -0.02)` to `(0.66, 2.74, -0.28)`, radius 0.140 to 0.014; the centreline coils round the sweep (radius 0.072 fading to the tip, 9.4 rad, about one and a half turns) as 12 capsule segments, with a storm-grey stripe on the inside of the coil.
- **Colour:** vermilion `#D8472C`, redder than Inferno's orange, deepening to `#A8301F` down the back; butter-yellow belly `#F5D872` following the body's curve, top at y 0.98; storm grey `#8C929C` for the wind.
- **Gusts:** two parallel storm-grey wind glyphs (a swoosh rolling up into a tightening curl, 4.2 rad) rising diagonally across the back from his right hip toward his left shoulder, widths 0.060 and 0.052, raised 0.007, paler toward the curl, fine ink edge. Not mirrored (see the rejected draft below).
- **Eyes:** two flush almonds (centre x 0.300, y 1.700; half-width 0.268, arches 0.182 and 0.130), outer corners lifting, the top cut slightly lower toward the nose; a bold ink line on top and a fine one below; no lid band. Pure wind, no pupil, iris or white: pale storm light `#AAB8C7` deepening to slate at the rim, a bright middle. **Options:** e0 **Vortex** (three spiral arms turning slowly, the default), e1 **Gale** (broken streaks blowing to the outer corner), e2 **Eye of the storm** (wobbling rings drifting out round a calm bright middle).
- **Mouth:** a lopsided open grin (half-width 0.270, depth 0.115, tilt 0.12 rising to his left) carved into the muzzle with rolled lips, dimples, a row of top teeth, a tongue and one snaggle tooth rising from the low side at x -0.12. The reference's two buck teeth are left out.
- **Wind:** three tapered rings of wind wheeling round the lower body (heights 0.16, 0.50, 0.84; radii 0.86 to 1.04), each broken into two gusts.

**Drafts, not shown to the owner:** mirrored curl gusts either side of the spine read as an angry face from behind; thin helical grey bands read as hoops or bandages; ridged horns without a coiling centreline showed no twist at turntable distance; dark-rimmed grey eyes read as chrome goggles; a wind ring at y 1.20 crossed the face.

**Verified:** frames 0, 3, 6, 12, face and belly close-ups rendered for all three eyes and inspected; the horn early-out seam fixed. **Unresolved:** owner's eye pick and verdict on the horns, gusts, grin and palette; whether an open grin suits the resting face (Boon Doc's lesson: an open mouth reads as a reaction); transformed form not started; Blender build and Roblox look.

**Confirmed, owner, 2026-11-06 - Updraft launches away from the surface:** "if u shoot on as wall it laubnches u sideways, if u shoot on floor it launches u up, if u shoot on ceiling it lasunhes u down, if u shoot on diagonal surface is launches u diagonally up". Its gust also pushes Mistbank the same way, and Tornado pulls Mistbank in, "good for [both] counter and amplification".

## Confirmed - owner's direction, 2026-11-05

**Owner:** "It should just be like a tornado main ... more like utility-based, like you can use it to kind of if you shoot it in front of you, then it might slow down slugs so they can't transform or something ... Just make it smart. And make a good passive."

## Confirmed - Tornado main + Updraft passive, 2026-11-05

**Owner:** "I think I like updraft more. But Tornado is good. Yeah, so Tornado and updraft. Because updraft provides a bit more movement. Which I like."

| Ability | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Tornado | Main | The hit leaves a tornado that drags nearby opponents in. They can still walk, aim and fire | Move straight away at the edge, or wait behind cover |
| Updraft | Passive | A rising column of wind on the surface hit lifts anyone who steps in, on either team | Walk around it, use it yourself, or shoot the rider |

- **Job:** Tornado gathers enemies without hitting a group itself, and the drag is not a bind because the target keeps moving, aiming and firing. Updraft is vertical movement, unlike Silkline's anchors and swings.
- **Techs:** drag a group for Chain Lightning, Iceburst or Crashwave; ride Updraft to a high angle; a rider rising in a straight line is an easy shot for anyone.
- **Element rule, Considering:** wind carries things, so a tornado could pick up fire, mist or sparks it passes through.

## History - not selected

The assistant recommended **Windbreak** as the passive: a wall of wind on the surface hit that slowed enemy slugs in flight and stopped them transforming, built from the owner's "shoot it in front of you" idea, because a shot in front of you lands on a surface. The owner preferred Updraft's movement.

**Owner's rule for Windbreak, 2026-11-05**, kept in case it returns: a slug already transformed still goes through the wind, but its first hit does less damage; its ability damage is unchanged. A slug not yet transformed does not transform going through, so its ability does not activate.

## Unresolved

Transformed form not started (the base design is final); how high and how long Updraft lifts; how strong the drag is; whether the wind-carries rule is confirmed.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers Tornado's drag and escape and Updraft on floors, walls and ceilings. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

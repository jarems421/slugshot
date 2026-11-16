# Slug design record: Rammstone

**Confirmed, 2026-11-06:** full spec in [ability specs](../ability-specs.md#rammstone---confirmed-spec-2026-11-06). Shove Punch's knockback grows with charge; rock cover is 8 wide, takes 8 hits, is immune to fire, one at a time.

## Confirmed - molten lava and rock trail, the ideal trail, 2026-11-14

**Owner:** "Bramstone's one is perfect. That's the one that we should use as the ideal trail. Burpee's one looks weird because it's just individual fireballs kind of just coming out as like PNGs almost. Then Aquabeaks is almost perfect ... I like the splattering water particles ... it looks like it's spraying ... the main bulk of the trail itself. It's not as like smooth as Ramstone's one". Accepted: keep it as it is; Inferno's and Aquabeek's trail bodies now follow its recipe (round `lava` masses, spacing 0.14, at most 18 a frame, sizes 0.45-0.6, opaque, slow, spinning ±60).

## Superseded record - molten lava and rock trail, awaiting owner review, 2026-11-14

**Owner:** "They read more as 3D cubes. Tubes. Rather than trails. Like they just look like colored tubes. So it should be more like yes, 3D, but it's like a 3D trail of something resembling fire. It's a 3D trail of something resembling molten lava / rock for Ramstone. It's a 3D trail resembling something like water for Aquabeak." **Rejected:** the round tubes ("colored tubes"). **Implemented:** [`FlightTrail`](../../../experiments/combat/client/FlightTrail.luau) now lays overlapping comic particle sprites ([`build_trail_art.py`](../../../tools/slugs/build_trail_art.py): a flame tongue, a crusted lava blob, a water splash, grey bands tinted by each layer's colours; uploaded privately as `TrailArt`) all along the tip's path, each swelling, drifting, turning, changing colour and fading over up to a second. Each frame's particles come out of a box stretched along that frame's stretch of path, so a fast shot leaves no gaps. His, off the tail: crusted molten blobs sagging and turning, orange at once (yellow read as cheese) to red and dark rock; falling drips; his 3D pebbles bigger, most starting glowing molten and cooling to slate by halfway. **Seen in Studio:** a chain of molten blobs off the tail. **Unresolved:** the owner's verdict.

## Superseded - 3D tube trail lasting a second, 2026-11-14

**Owner:** "The way the streaks attach onto the tips ... it always forms some like it just doesn't attach properly. It's just a flat line attaching onto a tip. It's not 3D or anything ... It should be like a 3D trail, and it should last on a bit longer than just 0.3 seconds. Maybe make it last on like a second or something." His fluid streak's flat ribbon met his tail as a flat line, so it is now a FlightTrail tube too. **Implemented:** a shared [`FlightTrail`](../../../experiments/combat/client/FlightTrail.luau) in place of every Roblox Trail (a flat ribbon turned to the camera): a round tube along the path the tip has taken, sampled 30 times a second, a solid Neon core (70% of the radius) inside a see-through coloured shell, a round cap on the tip, narrower on the tip, fullest just behind it, thinning and fading over 1 s. Trails start once the form's `Reveal` (new attribute from `SlugTransformation`) passes 0.7, so the growing form does not lay trail over its own blades and wings. His: radius 0.18 concept units, orange-red at the tail to red and dark ember (Neon turns the earlier yellow-orange bands yellow, so red comes in at once). **Seen in Studio:** a round lava tube off the tail tip, deepening to red. **Unresolved:** the owner's verdict.

## Confirmed - his trail is the reference, 2026-11-14

**Owner:** "I don't actually like the built geometry that much. Because it just looks too stiff, like I want fluid trails, like Ramstone's trail is perfect because it's fluid. Inferno and Aquabeats trails are bad because they're just stiff things." His thin lava streak (below) stays as it is, and Inferno's and Aquabeek's trails now follow it.

## Implemented - a thin lava streak in place of the flat trail band, 2026-11-14

**Owner:** "let's work on the transformations and transformation trails." Seen in Studio, his red trail was a wide flat band (a sheet, like the one rejected on Inferno). **Implemented** in `RammstoneMotion`, keeping the owner's brief (a red trail with small pebbles): the trail a third as wide (0.11 studs at import scale), fully glowing, banded yellow-hot to orange, red and dark ember, tapering to a point and fading, lifetime 0.3 s; pebbles 0.08 to 0.18 of a unit instead of 0.05 to 0.12. Seen in Studio: it reads as a hot streak off his tail. **Unresolved:** the owner's verdict; whether he should get geometry like Inferno's and Aquabeek's.

## Implemented - in the game place, not yet seen in Studio, 2026-11-14

**Owner:** "build it in Studio. Do the idle animations, the transformation, make sure the transformation is similar to Burpee's thing, maybe have like a red trail with like floating rocks behind it, like just really small pebbles", then "Yeah, do it all" (including the private upload to their Roblox account).

**Implemented (offline checks pass; Studio unverified):**
- **Game models:** [`export_rammstone_roblox.py`](../../../tools/slugs/export_rammstone_roblox.py) reads both final models untouched and writes one skinned game mesh per form to `build/slugs/rammstone/roblox/`. Each is 18,500 triangles, with the face kept finer, plus two eye meshes of about 600. Colour, glow, contact shading and facet normals are baked at 2048 (eyes 512).
  - Base rig: root, body, head.
  - Transformed rig: Body, Tail and each arm's upper arm and forearm, as its preview rig.
  - Game scale 0.47 (base body 0.95 studs).
- **Upload:** [`upload_rammstone.py`](../../../tools/slugs/upload_rammstone.py) uploads the models and maps as private assets on the owner's account. Ids and SurfaceAppearance templates are only in ignored `private-assets/rammstone/`.
- **In the game:**
  - `CombatServer` builds `RammstoneIcon`, `RammstoneFlight` and `RammstoneTransformed`, dressed by [`RammstoneAppearance`](../../../experiments/creatures/rammstone/server/RammstoneAppearance.luau).
  - `FloppyBlaster` puts `RammstoneLoaded` in the canister.
  - `Combat.Slugs.Rammstone` is a prototype: damage 22, speeds 220/280/340, transforms like Inferno. He is third in the loadout.
  - `TransformationStyles` gives him a red glow at 2.6x.
  - `SlugTransformation` now gives a form its predicted impact time (`ImpactIn`).
- **Motion:** [`RammstoneMotion`](../../../experiments/creatures/rammstone/client/RammstoneMotion.client.luau):
  - a slow idle in the canister;
  - a flight idle (roll, tail swing);
  - the approved punch, timed so its hit frame lands on impact, faster on short shots and swing-only point-blank;
  - a red trail with small tumbling pebbles off the tail's tip.
- `verify_combat.py`, `verify_slugs.py` and `verify.py` pass; the game place is rebuilt.

**Unresolved:** nothing has been seen in Studio. The Studio MCP bridge for this session saw no Studio (other sessions' bridges were running), so the load, appearance, canister fit, transformation, punch timing, trail and pebbles all await the owner's Play test. The lobby grove and inspect act are not done.

## Confirmed - final transformed design, 2026-11-13

**Owner:** "Okay, finalize this as the transform design for Ramstone, and then I guess the next step would be to build it in Studio. Do the idle animations, the transformation, make sure the transformation is similar to Burpee's thing, maybe have like a red trail with like floating rocks behind it, like just really small pebbles."

**Final** (accepted: preserve it, change only what is asked): concept 14 below, as built by `tools/slugs/build_rammstone_transformed.py`. The model is `assets/source/slugs/models/rammstone/rammstone-transformed.blend`, with a copy kept as `rammstone-transformed-final.blend`. The punch (frames 1 to 34) and its preview rig are part of the concept, not the game's rig. **Next:** Studio, covering the base form's idle, the transformation like Inferno's, and a red trail with small floating pebbles behind the flight.

## Implemented - transformed form, concept 14, 2026-11-13

**Owner, on concept 13:** the teeth "look red when they should be the white", and "there's still the gap... between the jaw, chin area... and then there's a small gap diagonally to that point. Just fill that in with armor. But make sure it looks like it's actually connected rather than just a layer on top."

**Implemented, a concept for review** (concept 13 kept as `rammstone-transformed-v13.blend`):
- **The teeth:** concept 13 sank the body's skin under the head's instead of removing it, but the mouth is carved into the head's skin, so the body's plain column stood in front of the teeth and showed red. It is now removed behind the mouth (above the seam, within 0.40 of the middle, in front), where the head's front face hides its edge; elsewhere it stays sunk.
- **The jaw's ends:** the jaw's lower edge now runs back along the cheek plate's lower edge at each end, instead of meeting its upper edge at the cheek plate's point. That fills the wedge of skin that was left between them, so jaw and cheek plate read as one piece.
- [The jaw's end from the owner's angles, and the mouth](evidence/rammstone/transformed-14/jaw-and-mouth.jpg), [all views](evidence/rammstone/transformed-14/views.jpg).

## Revised - transformed form, concept 13, 2026-11-13

**Revised** by concept 14 above. Its curved body and tail bone stand.

### Concept 13 (as built)

**Owner, on concept 12:** "fix these last lil gaps then we good, the back of the slug like the body looks a bit stiff too, idk how we could fix that tho".

**Implemented, a concept for review** (concept 12 kept as `rammstone-transformed-v12.blend`):
- **The last gaps:** slits and a jagged edge beside the jaw's ends. They were left where the body's skin was deleted under the head's. Now the body's skin is never deleted there: it is sunk 0.008 inside the head's skin, so only the head skin's clean edge shows.
- **A less stiff body:** the back eases down behind the shoulders and the point lifts a little (two round cones, not one straight one).
- **A tail bone:** the body's skin bends between the body and tail bones, its weight moving to the tail from y 1.15 to 1.95; the back plates behind 1.7 and the rear cap ride the tail. Through the punch the tail lags the wind-up and the swing, whips past and settles (`TAIL_SWING`).
- [The gaps from the owner's angles](evidence/rammstone/transformed-13/gaps.jpg), [all views](evidence/rammstone/transformed-13/views.jpg), [the punch](evidence/rammstone/transformed-13/punch.jpg).

## Revised - transformed form, concept 12, 2026-11-13

**Revised** by concept 13 above. Kept as history.

### Concept 12 (as built)

**Owner, on concept 11 (screenshots from below and in front):** "look at the gaps, now theres no armour on jaw".

**Causes:**
- **The gaps from below:** the base form's rock underlayer was cut at 0.92, so its edge hung beside the chin with nothing behind it, under the hood either side.
- **The ragged line under the mouth:** the body's skin edge had been snapped onto the seam.
- **No jaw armour:** concept 11 removed it.

**Implemented, a concept for review** (concept 11 kept as `rammstone-transformed-v11.blend`):
- **The gaps:** the underlayer is cut at the hood's lower edge (1.24). A collar in the body's field fills solidly under the hood either side of the chin.
- **The seam:** the body's skin now runs 0.05 past the seam just inside the head's (0.005), so its edge sits hidden under the head skin's clean cut edge.
- **Jaw armour is back:** a crescent hugging the crisp jaw edge, its ends on the cheek plates' points. It sits 0.016 off the skin at its edges, so no skin pokes through, and stands out a little along the jaw. Option B is removed.
- [Below, in front, and the owner's two angles](evidence/rammstone/transformed-12/jaw.jpg), [all views](evidence/rammstone/transformed-12/views.jpg).

## Revised - transformed form, concept 11, 2026-11-13

**Revised** by concept 12 above. Kept as history.

### Concept 11 (as built)

**Owner, on concept 10 (screenshot from low on his right):** "it still doesn't connect... It's still hollow on that like half cylinder thing on the side. And then the chin thing is still looking so retarded. Please just do better."

**Causes, found by casting rays through the owner's view:**
- The "half cylinder" was the chest side plate beside the jaw. Since the body was slimmed (concept 4), many of its rays started outside the body, never met its surface, and left the plate hanging behind it as an open shell.
- The chin's look came from armour laid round it, in every version.

**Implemented, a concept for review** (same script and model; concept 10 kept as `rammstone-transformed-v10.blend`):
- **The chest plates' rays start deep in the chest.** The plate rises out of the skin from its lower edge. Every plate now warns if any of its rays start outside its surface; none do.
- **A clean jaw (the default):**
  - There is no armour on the chin.
  - The chin is the head's own column continuing below the mouth and turning under in a tight curve (0.08), so it ends in a crisp jaw edge and runs into one smooth underside.
  - The head's skin is cut at 0.95. Both skins carry the same normals along the join, from the shape they share, so no line shows there.
  - The chin and the throat's sides are tan back to the chest plates; a shorter reach left a red sliver on the throat.
- **Option B, jaw blades:** a thin blade each side along the jaw edge, pointed at the chin and at the jaw's corner, rising out of the skin with a ridge on the edge. It is in the collection "Option B - jaw blades (tick to show)", hidden by default.
- The assistant recommends the clean jaw.
- [Jaw options, from the front and from low in front](evidence/rammstone/transformed-11/jaw-options.jpg), [the owner's angle](evidence/rammstone/transformed-11/your-angle.jpg), [all views](evidence/rammstone/transformed-11/views.jpg).

## Revised - transformed form, concept 10, 2026-11-13

**Revised** by concept 11 above (the hollow chest plate, the chin's armour). Its single skin under the chin stands.

### Concept 10 (as built)

**Owner, on concept 9 (two screenshots):** "the corners of the jaw aren't attached to the armor on the corners... there's a gap... it just looks very chunky. It doesn't look like it's kind of coming out of the skin... being put there to cover it up." "From the underside, there's still that weird double chin skin flab... I don't know why you can't just fix it... gaps from under in the sides... it just doesn't connect to the armor on the underside properly."

**Cause:** every chin so far was a second skin meeting the head's. A separate chin made a stitched line or a fold like a fat lip; the head's skin bent under made a fold where it met the body underneath. Blending, plates and armour each moved the line, but none removed it.

**Implemented, a concept for review** (same script and model; concept 9 kept as `rammstone-transformed-v9.blend`):
- **One skin under the chin:**
  - The base form's skin is cut off at z 0.90 (below the mouth), and the bend is gone.
  - The new body's surface includes the base form's own column (its superellipse section at each height). It runs down from there, rounds off below 0.84 and joins the underside in one smooth surface.
  - The body's skin is trimmed where it lies on the head's above the cut. The edge left is set exactly on the column's section at 0.90, where the head's skin ends, so the two meet on one curve with nothing overlapping.
  - From below there is one tan underside running from the jaw straight back.
- **The jaw rises out of the skin** like the cheek plates. Its edges sit just off the skin (0.008), and it stands out only along its ridge (0.065), so it is a jawline growing from the face, not a slab laid over it. Its crescent ends still meet the cheek plates' points.
- [The chin from in front, below and the side](evidence/rammstone/transformed-10/chin.jpg), [face](evidence/rammstone/transformed-10/face.jpg), [all views](evidence/rammstone/transformed-10/views.jpg).

**Seen in the renders:** beside the face, below the jaw's ends, a faint line where the two skins meet at 0.90 shows close up; elsewhere the jaw covers it.

## Revised - transformed form, concept 9, 2026-11-13

**Revised** by concept 10 above (the double chin from below, a chunky jaw that did not grow out of the skin). Its crescent jaw shape stands.

### Concept 9 (as built)

**Owner, on concept 8 (screenshot of the jaw's end over the cheek armour):** "The way the armor overlaps from the jaw onto the rest just looks weird... It should be a smooth connection. That looks like it's intentional rather than looking like it was slapped on to cover something up."

**Implemented, a concept for review** (same script and model; concept 8 kept as `rammstone-transformed-v8.blend`):
- **The jaw plate is a crescent:** its two edges meet at each end on the cheek plate's own point (0.42, -0.39, 1.10).
- It leaves that point in the cheek plate's own direction, straight down, before sweeping forward under the chin, so each cheek plate and its half of the jaw read as one curved blade. From the front, the cheek plates and jaw frame the face in one U.
- Its edges follow chosen curves (points along each), and its end columns carry no jitter or ridge, so each end closes to a clean point.
- Two tries this round: ends meeting the points but turning inward at once read as two parts touching; ends tucked under the cheek plates (concept 8) read as an overlap.
- Everything else is unchanged. [The join from in front, the side and below, and the face](evidence/rammstone/transformed-9/jaw.jpg), [face](evidence/rammstone/transformed-9/face.jpg), [all views](evidence/rammstone/transformed-9/views.jpg).

**Seen in the renders:** from the side, a narrow wedge of tan cheek shows between the cheek plate's back edge and the jaw's lower edge as they leave the shared point.

## Revised - transformed form, concept 8, 2026-11-13

**Revised** by concept 9 above (the jaw's ends overlapping the cheek plates). Its taper and back plates stand.

### Concept 8 (as built)

**Owner, on concept 7 (three screenshots):** the body's taper "should be a bit more smooth. Currently it's like a big drop off on that... third scale layer"; the jaw's underside is "just too big... It should be like half the thickness", front to back (along the green axis, not the red); and "it doesn't really attach to the other areas of the armor that well. It's just kind of still slapped on."

**Implemented, a concept for review** (same script and model; concept 7 kept as `rammstone-transformed-v7.blend`):
- **An even taper:** the body is one round cone from behind the shoulders (0.56) to the point (0.10). A body ellipsoid that ended part way made a step there.
- **Back plates:** four rows of shorter plates, each stepping down only a little from the one before. Their points flare less: points that flared well up over the next row made the drop-off at the third row.
- **The jaw plate:** about half as deep under the chin. Its ends run up and back under the cheek plates, which now overlap them like layered armour; level with the cheek plates' tips, its ends looked slapped on.
- The punch is unchanged. [Jaw from in front, below and the side, and the rear's taper](evidence/rammstone/transformed-8/jaw-and-rear.jpg), [face](evidence/rammstone/transformed-8/face.jpg), [all views](evidence/rammstone/transformed-8/views.jpg).

**Seen in the renders:** behind the shallower jaw plate, the tan underside of the chin shows from below, with a faint line where it meets the body.

## Revised - transformed form, concept 7, 2026-11-13

**Revised** by concept 8 above (the taper's drop-off, the jaw too deep and not attached). Its punch timing and the punch proposal below it still stand.

### Concept 7 (as built)

**Owner, on concept 6:** "[He looks] better now... the jawline still looks a bit weird. Because it's just like a patch of armor at the bottom. It doesn't like connect to anything properly. And it's a very big patch... And doesn't even cover the front of the chin thing. That pokes out from underneath." "The punch animation is good, but it might be a bit too long... when you shoot the slug in short range, it might not be able to do the punch... how would the punch even work?... I guess the punch would act when it's like within a certain range of the opponent."

**Implemented, a concept for review** (same script and model; concept 6 kept as `rammstone-transformed-v6.blend`):
- **The jaw plate:** smaller, covering the whole chin. Its rays are aimed between two curves:
  - Its upper edge is a jawline just under the mouth, rising either side to the cheek plates' lower tips, so the cheek armour runs on into it.
  - Its lower edge runs round under the chin to where the chin meets the body.
  - It keeps a ridge along the jaw to a point at the chin. The face is now framed by red rock all round: the hood, the cheek plates and the jaw.
- **The punch tightened:** the same moves, with the hit at frame 10 (0.42 s in, was 0.58 s) and the whole move 34 frames (1.4 s).
- [Face](evidence/rammstone/transformed-7/face.jpg), [the chin and jaw from in front, below and the side](evidence/rammstone/transformed-7/chin.jpg), [all views](evidence/rammstone/transformed-7/views.jpg), [the punch](evidence/rammstone/transformed-7/punch.jpg).

**Considering (the assistant's proposal, not decided) - how the punch plays in the game:** the punch is timed back from the predicted hit, as Inferno's transformation already shortens itself for close shots.
- On a long shot he flies tucked, and starts the wind-up 0.42 s before the predicted impact, so the hit frame lands on the hit.
- On a shorter shot the wind-up plays faster.
- Point-blank, he skips to the swing alone (about 0.1 s).
- The follow-through plays after the impact.
- It is cosmetic: the hit, damage and knockback stay the projectile's (Shove Punch's knockback grows with charge).

## Revised - transformed form, concept 6, 2026-11-13

**Revised** by concept 7 above (the jaw plate as a disconnected patch, the punch a bit long). Kept as history.

### Concept 6 (as built)

**Owner, on concept 5 (screenshot from low in front):** "tuck the horns in a bit more... It's still an obvious... triple chin... It should just be a smooth underside with... a prominent jawline probably... just don't make it look stupid... it's not supposed to look like it's a smooth faced thing. Maybe use the armor to create that effect... two big lumps on the bottom which are very obvious... big lines going around them." And: "improve the punching animation... it just looks like a small little bop... kind of move to the left and then swing... it should be like a full-on hook... the punch should have that oomph. Right now, it just looks too light work."

**Implemented, a concept for review** (same script and model; concept 5 kept as `rammstone-transformed-v5.blend`):
- **A jaw guard of red rock** wraps round the jaw and under the chin. It is faceted, with a ridge along the jawline coming to a point at the chin. Its upper edge dips under the mouth and rises at the sides toward the cheek plates; level across, it read as a chin strap. It covers where the head's chin meets the body, so no lumps or lines show from the front or below. It is fitted to the head's real column, which widens upward: fitted to a straight cylinder, the head's sides showed through it in tan spots.
- **Horns** drawn 0.8 as far out from the head.
- **A hefty punch** (frames 1 to 46):
  - He coils away and shifts to his left with the right arm cocked high and back by the head (frames 9 to 11, a beat of hold).
  - Then the arm whips out wide and round in front at an even, fast pace (11 to 15) as he turns hard into it, rolls and lunges forward, the left arm pulling back.
  - He overshoots (18), holds the hit (24) and settles (38).
- [All views](evidence/rammstone/transformed-6/views.jpg), [the chin and jaw from in front, below and the side](evidence/rammstone/transformed-6/chin.jpg), [the punch](evidence/rammstone/transformed-6/punch.jpg).

## Revised - transformed form, concept 5, 2026-11-13

**Revised** by concept 6 above (the chin's lumps and lines, horns tucked in, a heftier punch). Kept as history.

### Concept 5 (as built)

**Owner, on concept 4 (with two screenshots from low in front):** "This double chin thing is still here... there's just two lumps... it just makes the guy look fat. And then the horns are a bit too long, they should be a bit shorter."

**Cause:** the base form's skin column, bent under into the chin, still carried the belly's two V steps; bent under, they made the fold and the second lump. A throat lump behind the chin also showed below it, and the base form's lowest kept back plates poked out under the throat as a red V.

**Implemented, a concept for review** (same script and model; concept 4 kept as `rammstone-transformed-v4.blend`):
- **The chin is one rounded shape:** the column below the mouth is rebuilt on the plain section, without the belly's steps, and bent under 0.17 deep (was 0.22). Its foot is removed and closed with an evened-out fan, so the bottom does not pinch.
- The throat behind it is narrower and higher, inside the chin's outline from the front. The base form's third row of back plates is removed.
- **Horns** drawn at 0.82 of their size about the root, the same shape and thickness.
- [All views](evidence/rammstone/transformed-5/views.jpg), [the chin from low in front and from below](evidence/rammstone/transformed-5/chin.jpg).

**Seen in the renders:** from straight below, a faint mark is left where the chin closes, and a line shows where the throat meets it.

## Revised - transformed form, concept 4, 2026-11-13

**Revised** by concept 5 above (double chin, horns a bit long). Kept as history.

### Concept 4 (as built)

**Owner, on concept 3:** "The body's length is right, but... he's too beefy... Maybe it's because his arms are tucked in too tightly... it doesn't taper down early enough... a beefy missile. Or maybe it's just because of the chin." Horns: "they don't attach smoothly... they're like angled upwards. So tilt them forward... make sure... the horns don't look like they're poking upwards too much"; the curl "gets too thin. It should stay like the same consistent thick size". Hands: "they're perfect, but... add 2 extra rocks per hand... like the number 5 on a dice"; "from the side... there's like a red sphere... It should just be fully rock... add more diagonal, sharp rock coming out to cover that area. And make the hand look a bit bigger too. And more dangerous."

**Implemented, a concept for review** (same script and model; concept 3 kept as `rammstone-transformed-v3.blend`):
- **Slimmer body:** the chest is narrower (0.68 either side, was 0.78) and the body tapers from just behind the shoulders. The length is unchanged.
- **The chin is the head's own skin:** the base form's skin column below the mouth is bent under into a rounded chin, instead of a separate chin joined to it. A chin level with the head showed a stitched line under the grin; one standing proud made a fold like a fat lower lip.
- **Arms angled out** from the body, hands 1.3 out to the side (was 1.04), and a little slimmer.
- **Horns** come out of the hood tilted forward, then arc back low over the head and curl down behind it. They stay thick all the way round the curl, closing only at the very end.
- **Hands:** bigger (about 0.96 across), set back over the wrist so no red arm shows from the side. Five flattened diagonal shards sit on the front like the five on a die, and two broad ones lie back along the wrist. Four long spikes round the wrist read as a spiked mace and were taken out.
- The punch is unchanged. About 96,000 triangles. [All views](evidence/rammstone/transformed-4/views.jpg), [face](evidence/rammstone/transformed-4/face.jpg), [the punch](evidence/rammstone/transformed-4/punch.jpg).

**Open for the owner:** whether he still looks beefy, the horns' new angle and arch, and the hands.

## Revised - transformed form, concept 3, 2026-11-13

**Revised** by concept 4 above (too beefy, horns angled up and thinning, two more rocks per hand, red showing at the wrist). Kept as history.

### Concept 3 (as built)

**Owner, on concept 2:** "The horns are a bit too long... They should point back more as well. And they should curl a bit more so that they don't look as long." "I don't really want proper fists... I think fists look goofy... just like have like jagged black rock looking things for the hands." "I want the arms to be a little curved, like have like elbows." "Rather than looking at some Superman ass pose... the ramstone is gonna like swing... a slight punch animation, which will make it feel like it's impacted more... start with his hands tucked in at his sides, and it just swings a punch with one of his arms." "The belly's bloody massive. And make the like body longer... a more gradual descent into that end bit... Right now it looks like a decapitated bodybuilder. Should be a similar size to Burpee. Maybe not as long, because obviously burpee has a tail."

**Implemented, a concept for review** ([`build_rammstone_transformed.py`](../../../tools/slugs/build_rammstone_transformed.py), `assets/source/slugs/models/rammstone/rammstone-transformed.blend`; concept 2 kept as `build_rammstone_transformed-v2-brute.py` and `rammstone-transformed-v2.blend`):
- **Body like Burpy's:** the head is now the front of a long slug body. It is about as wide as the hood, flows back from the hood and tapers gradually to a point, with no tail. From face to point it is about 3.5 units long (Burpy's dragon is about 4 with his tail, his eyes a little narrower). There's no bulging belly: a slim tan sole runs underneath, the chin rounds off under the grin, and the sole ends in a V near the point.
- **Horns:** shorter (about 2.3 units along the curve, were 3.3), rising back from the hood and curling tightly down behind the head, tips forward. They no longer sweep out to the sides.
- **Arms bent at the elbow, hands tucked at his sides** beside the chin, the elbows back; same pauldrons, jagged bands, elbow caps and black cuffs.
- **Hands:** no fists. Each is a jagged lump of black rock with three chunky shards breaking out. Five long shards read as a spiked mine.
- **The punch** (play frames 1 to 40 in Blender): he winds up a little (frame 7), swings his right arm forward, turning his body into it (frame 12), holds the hit (to 17) and settles back by 32. A preview rig drives it: a body bone and two bones per arm, each piece riding one bone. It isn't the game's rig.
- About 97,000 triangles, 58,000 of them the body skins. [All views at rest](evidence/rammstone/transformed-3/views.jpg), [the punch from his right](evidence/rammstone/transformed-3/punch.jpg).

**Seen in the renders, not yet fixed:** from straight behind, the elbows read as two round domes and the point has a small cap.

**Open for the owner:** the body's length and taper, the horns, the hands, and the punch's size and timing.

## Revised - transformed form, concept 2, 2026-11-13

**Revised** by concept 3 above, on the owner's notes (horns too long, fists goofy, a Superman pose, the belly massive, the body too short). Kept as history.

### Concept 2 (as built)

**Owner, on concept 1:** "this aint transformed u just slapped stuff on the base model, horns facing the wrong way too, look at burpy for example". With a reference picture: "this can be used as a reference image but remember we are using black not blue". **Confirmed:** a transformed form is a new body that carries the slug's face, as Inferno's ("Burpy") slug-dragon does, not the base form with parts added.

**Reference (not stored, no reuse rights assumed):** the owner's picture shows a red, hulking brute flying fist first, with huge blue ram horns curling back, blue stone fists, a cream belly bulging under the chin and a trail of red smoke and rocks. Only that archetype is used: the face, armour, horns and fists here are Slugshot's own, built in the base form's style, with black for blue.

**Implemented, a concept for review** ([`build_rammstone_transformed.py`](../../../tools/slugs/build_rammstone_transformed.py), `assets/source/slugs/models/rammstone/rammstone-transformed.blend`; concept 1 kept as `build_rammstone_transformed-v1-bolted.py` and `rammstone-transformed-v1.blend`):
- **Only the head is the base form's:** face, eyes, grin, hood, crest and cheek shards, exactly as accepted, cut off below the chin.
- **A new hulking body in flight, head first:** a deep chest, a tan belly bulging under the chin, massive shoulders high either side of the head so it sits down between them, a hump behind it and a short body tapering behind. No tail. The surface is one smooth field of ellipsoids and round cones, joined smoothly.
- **Red rock armour over nearly all of it:** three rows of pointed plates down the back and flanks, layered like the base form's; pauldrons; jagged bands all the way round each upper arm and forearm; elbow caps; plates on the chest. The tan belly runs from the chin underneath and ends in a V, like the base form's belly marks. The gaps between plates are dark red.
- **Black ram horns:** huge and ridged, from the base horns' roots, sweeping up, out and back, and curling down behind the head with their tips forward.
- **Arms in a flying punch:** the right fist driven forward, the left cocked back by the chin with its elbow behind. The forearms are about as thick as the head is tall. Black stone cuffs and huge black stone fists, each as wide as the face: the back of the hand, four curled fingers and a thumb across them, all faceted blocks.
- About 106,000 triangles, 66,000 of them the body; no rig or export. [All views](evidence/rammstone/transformed-2/views.jpg), [three-quarter and front](evidence/rammstone/transformed-2/three-quarter-front.jpg).

**Seen in the renders, not yet fixed:** from straight behind, the last row's points still gather at the rear's tip; the cocked fist's cuff shows as a dark block from the side.

**Open for the owner:** the pose (fists, and how level he flies), the body's bulk and the belly's size, the horns' curl and size, and the fists' finger blocks.

## Rejected - transformed form, first concept, 2026-11-13

**Rejected** by the owner (concept 2 above): it was the base form with parts added, and its horns faced the wrong way. Kept as history.

### First concept (as built)

**Owner's direction:** "it needs arms, because obviously it's gonna be punching stuff... It needs the big horns... big devil horn, rock things... red armor all over it. Maybe not all around... you can have the belly and some patches... I don't think it should have a tail... its arms should look like really armored, and I don't know if it should really have fingers, but it should just look like something that like can punch." "I'll give you the main features I want, and then you can just build off it."

**Implemented, a concept for review** ([`build_rammstone_transformed.py`](../../../tools/slugs/build_rammstone_transformed.py), `assets/source/slugs/models/rammstone/rammstone-transformed.blend`): the final base form kept whole (face, hood, crest, cheek shards, plates, belly), so it is plainly the same slug, with:
- **Devil horns** in place of the base horns: thick faceted charcoal horns (0.23 at the root) from the same roots, sweeping out to the sides, up, and curling in at the tips, with seven faint ridges along them.
- **Massive armoured arms** in a ready stance, the fists forward and low at the sides so the face and belly stay clear. Each has a tan skin arm showing at the armpit and elbow; a big layered rock pauldron with two jagged lames; a spike on the elbow; a rock gauntlet flaring to the wrist with three fins along its outer edge; and a big blocky rock fist with no fingers, a thumb across the front and a charcoal knuckle ridge with a few glowing magma cracks.
- **No tail**: the body ends as the base form's does.
- Two earlier tries in this round: fists held up in a guard by the face, at a third of this size, read as small claws; smaller, separate knuckles read as a row of pebbles.
- About 50,400 triangles; no rig or export. [Views, with the base form for comparison](evidence/rammstone/transformed-1/views.jpg).

**Open for the owner:** the stance (ready stance, guard, or a flying punch pose for the shot), the arms' size, whether the body should be bulkier than the base form, and the horns' curl and size.

## Confirmed - final base design, 2026-11-13

**Owner:** on the tusks, "I like the idea of the fangs, but they're just not looking that good right now... the smile looks fine as is" and, given the assistant's view that they clash with the carved grin, "Let's just remove the things for now then... fine without them. And then finalize this as the base design."

**Final** (accepted: preserve it, change only what is asked): the base form as built by `tools/slugs/build_rammstone_clean.py` with no fangs. The model is `assets/source/slugs/models/rammstone/rammstone-clean.blend`, with a copy kept as `rammstone-base-final.blend`. [Final renders](evidence/rammstone/final-base/renders/), [views beside the sheet](evidence/rammstone/final-base/views.jpg), [three-quarter and face](evidence/rammstone/final-base/three-quarter.jpg). Silhouette against the sheet: front 0.928, side 0.920, back 0.834, other side 0.863. The last tusk build is kept as `rammstone-clean-v20.blend` with its script `build_rammstone_clean-v20-tusks.py`, should the owner want fangs back in another form. The assistant suggested faceted stone tusks from the jaw, or fangs only in other expressions; neither was chosen.

**Before the game (not started):** bake the procedural materials, the eye cracks and the emission into textures; reduce about 46,500 triangles to Roblox's 20,000 per mesh; then rig and export. Next: the transformed form.

## Implemented - bigger, longer tusks, awaiting owner review, 2026-11-13

**Owner:** "I think the fangs are big or long enough". Read as "aren't" (likely a dictation slip, given the "or"), so the tusks are bigger and longer. The previous ones are kept in `rammstone-clean-v19.blend` if the owner meant they were fine.

**Implemented/verified** (`build_rammstone_clean.py`):
- Tusks 0.104 across at the root (`TUSK_RADIUS` 0.052, was 0.042) and longer. Standing out in front of the face (`TUSK_OUT` 0.034), each rises `TUSK_RISE` (0.032) over the upper lip's line to its point, like an ogre's tusks, and leans a little outward (0.018).
- Everything else unchanged; silhouettes unchanged; `verify_slugs.py` passes. [Mouth from the front, three-quarter and side, before and after](evidence/rammstone/big-tusks/face-compare.jpg), [views](evidence/rammstone/big-tusks/views.jpg).

## Implemented - tusks standing out of the mouth, awaiting owner review, 2026-11-13

**Owner:** "I think the last change, because everything is perfect now, is just with the fangs... it would look cool if we actually make them come out rather than making them look sort of painted on. You can make them come out a bit and protrude a bit."

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v18.blend`):
- Each tusk now curves forward out of the mouth low down and then turns up to its point, which stands `TUSK_OUT` (0.022) in front of the face. Its front is about 0.03 past the lips, and from the side it sticks out beyond the lip line. Seen from the front, the point stays below the upper lip. A first try pointed the tusks straight at the viewer (0.03 out on a straight line), which made them blobs from the front.
- Everything else unchanged. Silhouettes unchanged (front 0.928, side 0.920, back 0.834, other side 0.863); `verify_slugs.py` passes. [Mouth from the front and three-quarter before and after, and from the side](evidence/rammstone/tusks-out/face-compare.jpg), [views](evidence/rammstone/tusks-out/views.jpg), [three-quarter and face](evidence/rammstone/tusks-out/three-quarter.jpg).

**Before export (not started; the owner gates rigging and export on approving the look):** bake the procedural materials, the eye cracks' texture and the emission into textures; reduce about 47,200 triangles to Roblox's 20,000 per mesh.

## Implemented - closed armour gaps, a shorter back, plain teeth and spread tusks, awaiting owner review, 2026-11-13

**Owner:** "Reduce the size of the lines coming out of the mouth, like on the edges. Add more glowing cracks to the eyes. There's a lot of like gaps in the armor right now, like from the front in that corner we were filling in... when you look under you can see a gap just around where the armor meets the body. And on the... back of the head, there's a gap there. Reduce the size of the back of the head... reduce the length at which the back of the head is kind of protruding outwards." "Remove like all of the individual teeth... the only teeth I want are the like sort of fangs coming out. Aside from that, it should just either be a clean line or just blank white." "Make the fangs be like a little wider, because that's how ogre teeth usually are. They're usually a little more spread out. And they kind of look like they're kind of meshing in with the lips and stuff rather than being a clean tooth thing."

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v17.blend`):
- Back of the head: the hood's overhang behind the body is 35% shorter (`HOOD_BACK_TRIM`); its width is kept. Side silhouettes 0.920 and 0.863 (were 0.933 and 0.877), as the sheet's back is longer.
- Gaps: the hood was a thin shell flared well clear of the body and open underneath. Its lower edge now closes in to just inside the body all round, so from below and behind it is solid rock. From the front, a hollow 0.25 deep under each flared brow corner showed the side of the hood far behind. Each cheek shard's back edge now rises forward into that corner, just under the brow's lip (`CHEEK_CORNER`), and fills it. Checked with rays from the front and by eye from below.
- Eyes: nine more glowing cracks (`EYE_CRACKS`): a second crack across the upper middle joined to the first, and branches toward the rim.
- Corner lines about 40% smaller (`SMILE_CREASE`), still one stroke with the upper lip.
- Teeth: plain white rows with only the bite line; the separate teeth and gaps are gone.
- Tusks further apart (|x| 0.16, was 0.12), broader (0.084 across at the root) and cone-shaped with a clear blunt point just under the upper lip. Each is rooted behind the lower lip's line, so the line runs cleanly across its base and it stands in front of the teeth as a separate tooth.
- `verify_slugs.py` passes. About 47,200 triangles. [Face, side and mouth before and after](evidence/rammstone/closed-gaps/face-compare.jpg), [views](evidence/rammstone/closed-gaps/views.jpg), [three-quarter and face](evidence/rammstone/closed-gaps/three-quarter.jpg).

## Implemented - cheek shards, 3D tusks and sculpted teeth, awaiting owner review, 2026-11-13

**Owner (with two screenshots):** "from the side, there's this gap... tilt the sideburn looking arm back to fill that gap... It'll probably look nicer when you look from the front as well". "At the bottom of the sideburn, it like kind of pokes out a bit." "From the front... it looks very blocky as if it's a sideburn rather than looking like a sharp piece of armor kind of coming out of the skin... just slanted coming out of the skin." "The armor looks curved in the area diagonal to the eye, but I want it to be straight." Then: the curves at the mouth's corners are "not attached properly, and they just look kind of weird"; "the teeth also look weird too... do a bit of research on how like ogre-style smiles / teeth look... Maybe we need to actually make them like actual 3D stuff, like coming out of mouth"; and the fangs "big. In terms of wide and tall", not "tall and thin".

**Research:** little was specific to ogres. Stylized teeth sets model the upper and lower rows (and individual teeth) as separate shapes. A pronounced underbite with lower canines is a defining, menacing cartoon trait.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v16.blend`):
- Cheek plates rebuilt as shards (`build_cheek`). The front edge sits on the skin and is straight seen from the front, from a point beside the mouth's corner (0.42, 1.10) up under the brow's corner (0.575, 1.645). The face tilts back and out from that edge over a raised ridge (0.055 proud, 30% across) to a back edge just under the armour's surface, which sweeps from the point up and back under the hood's flap behind the eye (`CHEEK_BACK`). No gap shows from the side, and there is no ledge at the bottom: it ends in a point.
- Teeth sculpted (`build_teeth`): ten upper and ten lower rounded teeth, narrower toward the corners like an arch seen from the front, with a darkened groove between each (`gap`). The upper row rounds off down into the bite line and the lower row, a little behind it, rounds off up into it. Brighter and glossier (roughness 0.3).
- Tusks (`build_tusks`) replace the flat fangs. Each is a solid cone 0.066 across at the root (`TUSK_RADIUS` 0.033), rooted behind the lower lip at |x| 0.12. It bows out of the mouth in front of the upper teeth and ends in a blunt point just under the upper lip, leaning slightly outward.
- The upper lip's line runs on through each corner into its curling crease as one stroke, instead of separate strokes.
- Silhouettes about unchanged (front 0.927, side 0.933, back 0.835, other side 0.877); `verify_slugs.py` passes. About 47,200 triangles (the sculpted teeth add about 6,000). [Your screenshot's angle before and after, the face, and the mouth](evidence/rammstone/shards-tusks/face-compare.jpg), [views](evidence/rammstone/shards-tusks/views.jpg), [three-quarter and face](evidence/rammstone/shards-tusks/three-quarter.jpg).

## Implemented - a livelier grin, big fangs and the sheet's eyes, awaiting owner review, 2026-11-13

**Owner (with a front screenshot and the sheet):** "it's better. I think we need to improve the smile a bit. So it looks more emotional... make the teeth a bit bigger and look better attached to the lower row of teeth. So it doesn't look like it's just like on top of the line... actually a part of that bottom row." "The sides of the like diagonal lines they look too blocky rather than like they're going into the skin." "The outlining near the place where the armor meets the belly the orange outlining is kind of messed up... I don't know if it's outline or like cracks... It's got to clean up a bit." "Improve the eye shape. I don't know what it is necessarily, but something just feels off with it." Then, mid-round: "make sure they aren't just tall and thin though. I want the fangs to be like big. In terms of wide and tall."

**Eyes, beside the sheet's front view:** ours had cracks spread evenly over a glossy black ball, with an orange ring round its bottom like goggles. The sheet's eye is warm dark brown, darker up under the brow, in a dark socket, with one glowing crack across its middle and a few branches up and down: a fierce focus.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v15.blend`):
- Eyes: the cracks are drawn (`EYE_CRACKS`, eye-local coordinates, mirrored for the left eye) into a small packed texture (`RammstoneEyeCracks`): one jagged main crack across the middle and short branches, each with a hot core, a glow and a faint warmth. The eye is warm dark brown, darker under the brow and toward the rim. The lid line is darker, and the orange glow on the lids is down to 0.3 (it drew the ring). Shape and dome unchanged.
- Grin: the corners curl higher (at 1.19; the upper lip dips 0.05 to the middle instead of 0.027). A short crease curves up round each corner (`SMILE_CREASE`) as the cheek pushes up. The lips' inner curls are tighter, so the teeth show more.
- Fangs: big, broad and tall. Each is about 0.09 wide at the base (with its flare) and rises from the bite line nearly to the upper lip, to a clear point (`FANG_V` 0.92 to 0.17, `FANG_HALF` 0.036). Below the bite line each lies flush on the lower row with no outline, so it is part of that row; above it, the sides flare into the line and a dark outline runs round it. The bite line moved down to 58% of the opening to give them room.
- Side plates: each cheek plate's front edge comes down to the skin (0.004 clear of it) and rises to full thickness within 0.035, so the diagonal edges sink into the skin instead of standing on it as blocks.
- Orange edging: the light bevel goes only on edges standing clear of the skin (`body_clearance` > 0.012); edges running into the skin get none. That removes the stray orange slivers where the armour meets the belly.
- Silhouettes about unchanged (front 0.927, side 0.932, back 0.835, other side 0.877); `verify_slugs.py` passes. About 41,500 triangles. [Eyes beside the sheet, the mouth, and the armour by the belly, before and after](evidence/rammstone/emotion/face-compare.jpg), [views](evidence/rammstone/emotion/views.jpg), [three-quarter and face](evidence/rammstone/emotion/three-quarter.jpg).

## Implemented - straight rock framing the cheeks, awaiting owner review, 2026-11-13

**Owner:** "The cheeks look like two curved or something. Or too puffy. I don't know what it is necessarily, but it's kind of weird. It just removes the jagged look that we're going for. But I like how it looks wider at the" (message cut off; read as wider at the top, round the eyes).

**Cause:** the face's extra width (0.07 each side) ramped in smoothly from the mouth (1.10) to under the eyes (1.35), so the skin swelled out in a curve between them, like round cheeks. The cheek plates' front edges were placed by the hood's angle at brow height, so they did not run straight from the front and shrank to slivers beside the wider skin. In solid view the face read as a smooth bulb.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v14.blend`):
- The face widens only at the eyes' height, in a straight ramp from 1.25 to 1.45 (`FACE_WIDEN_Z`), so it is still wider at the top.
- The cheek plates' front edges run in a straight line seen from the front, from beside each mouth corner (0.46, 1.12) up to the brow's corner (0.66, 1.675). Each edge point is placed by solving for the column that puts the plate's outer face at that x. The plates stand 0.065 clear of the face (was 0.04), so the face is framed by chunky rock in straight lines.
- Eyes, brow, mouth and fangs unchanged. Silhouettes about unchanged (front 0.928, side 0.932, back 0.835, other side 0.877); `verify_slugs.py` passes. [Face: before the widening, widened, and this build](evidence/rammstone/straight-cheeks/face-compare.jpg), [views](evidence/rammstone/straight-cheeks/views.jpg), [three-quarter and face](evidence/rammstone/straight-cheeks/three-quarter.jpg).

## Implemented - meteor eyes, a carved mouth and more room round the eyes, awaiting owner review, 2026-11-13

**Owner:** "Make the eyes bulge out a little more. Not like... bug eyes, but just so that they look more like meteors". "Make the mouth look like it's actually ingrained into the face rather than looking painted on." The fangs "should be like on the that row of teeth rather than just attached on the bottom lip... on that row, like that line." And "the eyes look too far into the corners of the forehead. So either maybe increase the size of the forehead so that the eyes stay in the same place, but they just look like there's more space around them, or do something else, but don't make the eyes look cramped again."

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v13.blend`):
- Eyes: domed 0.075 (was 0.05), the dome gently lumpy (0.004) like a rock but smooth at the rim. A little less glassy (roughness 0.25, coat 0.45). Shape, cracks and glow unchanged.
- More room round the eyes: the face is 0.07 wider each side under the forehead (`FACE_WIDEN`, from 1.10 up to full at 1.35). The brow's corner moved out to (0.66, 1.675) and the cheek plates' front edges to 0.56. The eyes and the brow over them stay where they were, with skin beyond each eye's outer end instead of the corner.
- Mouth carved in (`carve_mouth`): the body's faces round the grin are split into thin columns and laid on its smooth surface. Inside the grin the skin is pushed 0.02 into the face, its wall dropping almost at once and darkened. The lips' inner sides curl dark down into it, and the teeth and fangs sit at its floor. A gentler wall came out stepped by the body's rings (0.01 apart) where the teeth met it. The step behind a smooth curl leaves a clean edge. Teeth a little whiter.
- Fangs on the bite line: each rises from the line between the rows (just below it, so the line runs round it) to a point near the top of the upper row, 0.04 wide at the base.
- The rock's coat is softer (roughness 0.3): at 0.15 whole flat facets turned white under the review renders' sun.
- Silhouettes about unchanged (front 0.928, side 0.932, back 0.834, other side 0.877); `verify_slugs.py` passes. About 40,100 triangles (the mouth's finer faces add about 3,000). [Face and mouth before and after](evidence/rammstone/carved-mouth/face-compare.jpg), [views](evidence/rammstone/carved-mouth/views.jpg), [three-quarter and face](evidence/rammstone/carved-mouth/three-quarter.jpg).

## Implemented - a lower mouth with fangs, deeper eyes and livelier colours, awaiting owner review, 2026-11-13

**Owner:** "looks a lot better for sure. Move the mouth down a bit. Then give the mouth more life... two teeth like going up so it looks a bit like an ogre... just like little ones, not like ones that go over the mouth... little teeth imprints... a cartoon type of look." The eyes "look kind of weird with the head... when you look from the side, the eyes are like kind of under the armor... I like the general eye design and I like the idea behind it, but it's just not, it's not being executed properly right now." And "bring more life to the colors too, like make the red a bit shiny or something. Make the tummy color have a bit more life... Bring the eyes to life, make the orange glow."

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v12.blend`):
- Mouth 0.04 lower: corners at (|x| 0.32, 1.165), the top edge's middle at 1.138, the bottom's at 1.045. Shape, teeth and lips unchanged.
- Two little lower fangs (`RammstoneFangs`) at |x| 0.13. Each rises from under the lower lip to a small rounded point over the upper row (28% of the way down the grin), 0.048 wide at the base. They stand just proud of the teeth and have a dark outline. They stay inside the mouth.
- Eyes: the same D shape and cracks, now domed twice as deep (0.05), so they read as orbs rather than flat patches from the side and three-quarter. Glossy, with a clear coat and a crisp highlight. Glow brighter (core 6, halo 2.5, hotter orange and yellow), and a faint orange glow on the lids' inner slopes (`spill`).
- Colours: the rock a richer, deeper red (roughness 0.6, light clear coat 0.15), with brighter orange-red edges. A broad, strong shine washed it pink in Blender's Material Preview, so the coat is light and crisp. The skin a warmer, more saturated peach, with soft subsurface and a little gloss. The horns a little shiny.
- Silhouettes unchanged (front 0.929, side 0.932, back 0.834, other side 0.877); `verify_slugs.py` passes. About 37,000 triangles. [Face before and after, and the mouth](evidence/rammstone/life/face-compare.jpg), [views](evidence/rammstone/life/views.jpg), [three-quarter and face](evidence/rammstone/life/three-quarter.jpg).

**Still different from the sheet's side view:** there the eye shows higher, at about 1.48 to 1.66 under the raised brow corner; ours shows at about 1.35 to 1.55, below the visor. Showing more would mean moving the cheek plates' upper front edges back, which the owner has not asked for. Materials must be baked, and the triangle count reduced, before any Roblox export. The spill glow, subsurface and coat will need baking into textures.

## Implemented - a wider top from the front, awaiting owner review, 2026-11-13

**Owner:** "These still looks too cramped from the front... it doesn't have the wideness at the top like it does when you look from the sides. It doesn't have that when you look from the front... that's what gives it its like intimidating look from the front... And it makes the eyes look cramped when they're not."

**Measured:** from the side, the hood at brow height (z 1.70) is 1.57 deep against 1.11 for the body below it, about 1.4 times. From the front the sheet's hood is only about 1.2 times as wide as the plates below (half widths 0.79 against 0.65), and ours matched it. So the flare that reads as intimidating from the side barely showed from the front. This departs from the sheet's front view, by the owner's direction.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v11.blend`):
- The hood is at least `HOOD_FLARE` (1.17) times half its side depth wide, so its temple corners reach about 0.92 from the front instead of 0.79. Most of the change is between 1.5 and 1.9; the dome and the lower hood are almost unchanged. The plates, brow band, forehead slabs and keel follow it.
- A wing slab each side (`RammstoneWing`), beside the band's and forehead slab's outer ends, tapers out to a raised point at the flared corner, as the sheet's outer plates step out to its corners.
- Face, eyes and grin unchanged. Side silhouettes unchanged (0.932, 0.877). Front 0.929 and back 0.834 (were 0.939 and 0.85), because the top is now wider than the sheet's front and back views. `verify_slugs.py` passes. [Front: the sheet, the previous build, this one, the side and the face before and after](evidence/rammstone/wide-top/front-compare.jpg), [views](evidence/rammstone/wide-top/views.jpg), [three-quarter and face](evidence/rammstone/wide-top/three-quarter.jpg).

## Implemented - an open face, round-bottomed eyes and layered forehead plates, awaiting owner review, 2026-11-13

**Owner:** "the forehead area it still looks too cramped from the front. If you're looking at it from the side, it looks fine, but from the front it just looks so cramped. Then the eyes look really weird, like the shape of them. They droop down so much. And the actual design itself feels plain compared to the original reference image."

**Measured on the sheet's front view** (pixel colours down columns, and a high-pass that shows its plate seams): the brow's lower edge is about where ours was (1.385 between the eyes, 1.44 at 0.15, 1.605 at 0.50, 1.635 at 0.55). The difference was beside and above it. The sheet's skin shows to the body's side (0.53) at eye level, where our cheek plates closed the face in at 0.44. Each eye is a wide D from 0.12 to 0.52 with a round bottom near 1.29. Ours was an almond whose low point sat near the inner end, with a long tail up to the outer point. The forehead is layered slabs with lit edges: a chevron brow band, forehead plates and raised outer corners.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v10.blend`):
- Face opened: the eye corner moved out to (0.60, 1.645) and the cheek plates' front edges to 0.52, so the face shows to its full width.
- Eyes: a wide D from |x| 0.13 to 0.50 under the brow, with a broad round bottom at about 1.31 in the middle. The sides rise steeply to sharp points under the brow, with no tail. Lids, cracks and depth as before.
- Forehead: a chevron brow band (`RammstoneBrow`, 0.05 proud) along the brow, from the crest's point up to (0.60, 1.785) at each corner. Above it each side is a forehead slab (`RammstoneForehead`, 0.03 proud) between the band and the crest, thickening to a raised outer corner.
- Lit edges: the bevel is wider (0.009) and its faces take light edge materials (`RammstoneRockEdge`, `RammstoneHornEdge`), so every plate and horn edge catches the light as on the sheet. The hood keeps a 0.006 bevel; a wider one pushed through the crest.
- Grin unchanged. Silhouette unchanged (front 0.939, side 0.932, back 0.85, other side 0.877); `verify_slugs.py` passes. [Front view: the sheet, the previous build and this one](evidence/rammstone/open-face/face-compare.jpg), [views](evidence/rammstone/open-face/views.jpg), [three-quarter and face, before and after](evidence/rammstone/open-face/three-quarter.jpg).

**Still different from the sheet:** the beak between the eyes has no dark underside reaching down to 1.30. The sheet has more plate seams across the forehead and an outer plate with a pointed corner each side. Our eyes' cracks spread across the whole eye, where the sheet's sit in the middle. Materials must be baked, and the triangle count (about 36,600) reduced, before any Roblox export.

## Implemented - a steep brow and almond eyes, awaiting owner review, 2026-11-08

**Owner (with a front screenshot):** "when you're looking from the front you can't see how the corners are raised... you can't see the raised corners in the corners of the forehead. So the face still looks sort of cramped... the eyes, they look a bit too rounded. It should be like a sharper finish where the eye meets the forehead. And then the smile is pretty decent."

**Cause:** lowering the brow over the eyes for the review's half-lidded look flattened it to a low line across the face. From the front its raised outer corners sat behind the cheek plates. Oval eyes meet a brow in rounded ends.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v9.blend`):
- Brow: a steep V again, through (0.20, 1.48) and (0.44, 1.58), up to the opening's corner at (0.54, 1.64). Its raised corners show from the front.
- Eyes: slanted almonds instead of ovals. Each top runs 0.03 above the brow's edge, so the brow cuts it all along. Each lower edge is a curve (Bezier) from a sharp inner point (|x| 0.09) just under the brow beside its point, down to about 1.33, and up to a sharp outer point (|x| 0.43) just under the raised brow. The lower lids follow that edge and fade into the points. Same dome, cracks and depth.
- Grin unchanged ("pretty decent").
- Silhouette unchanged; `verify_slugs.py` passes. [Front view beside the sheet, hero, previous and this face](evidence/rammstone/almond/face-compare.jpg), [views](evidence/rammstone/almond/views.jpg), [three-quarter and face, before and after](evidence/rammstone/almond/three-quarter.jpg).

## Implemented - a less packed face, awaiting owner review, 2026-11-08

**Owner:** "From the front, the face looks too packed, like it looks too cramped. And the smile looks a bit too big as well."

**Measured against the sheet's front view at the same scale:** the grin was 0.74 wide and 0.12 tall, its top within about 0.05 of the lower lids. The eyes reached |x| 0.45, against the sheet's 0.37. On the sheet the mouth sits at about 1.15 to 1.22, with clear skin between it and the eyes.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v8.blend`):
- Grin: smaller and lower. The corners are at (|x| 0.32, 1.205), the top edge dips to 1.178 and the bottom reaches 1.085, so the opening is 0.64 wide and about 0.09 tall at its middle. Teeth, bite line and lips as before.
- Eyes: a little smaller, radii 0.165 by 0.095, centred at |x| 0.26. Their inner tips stay about 0.1 either side of the middle and their outer ends reach 0.42, leaving skin round them.
- Silhouette unchanged; `verify_slugs.py` passes. [Face: sheet front view beside this build, and the previous face](evidence/rammstone/grin-2/face-compare.jpg), [views](evidence/rammstone/grin-2/views.jpg), [three-quarter and face, before and after](evidence/rammstone/grin-2/three-quarter.jpg).

## Implemented - the toothy grin and wider-set eyes, awaiting owner review, 2026-11-08

**Owner:** "I think the eyes are too close together. And I think let's just switch to the other smile. It would be easier to model. And I think it will look better. You know the smile that's in the base image? The one that has the teeth showing? Let's do that." This replaces the smirk as the mouth; the smirk and the earlier proposal to keep the grin for the inspect are superseded.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v7.blend`):
- Eyes: centred at |x| 0.265 (was 0.23), radii 0.18 by 0.10, so their inner tips sit 0.085 either side of the middle (was 0.04) and their outer ends stay clear of the corner. Lids, brow and cracks as before; the lid crest is lower (0.0045).
- Grin: a crescent opening seen from the front. Its corners are pointed and turned up at (|x| 0.37, 1.265). The top edge dips gently to 1.222 in the middle; the deep, rounded bottom edge reaches 1.105. It sits close under the eyes, as on the sheet. Teeth: a smooth warm-white surface filling it, highest across its middle. It is shadowed under the upper lip and into the corners (a "shade" attribute), with a fine dark bite line 45% of the way down where the upper and lower rows meet (a "bite" attribute, a mesh row exactly on it). Lips: carved lines in the skin's material, the upper along the top edge flicking up past each corner with a faint rim above, the lower along the bottom edge with a raised lower lip.
- Carved strips (lips, lids) now dive steeply under the skin at their edges (to -0.008). The body's facets sit up to about 0.002 inside its smooth surface between columns, so a shallow dive met them along a wavy line.
- Silhouette unchanged; `verify_slugs.py` passes. About 36,500 triangles. [Face beside the sheet and the previous face](evidence/rammstone/grin/face-compare.jpg), [views](evidence/rammstone/grin/views.jpg), [three-quarter and face, before and after](evidence/rammstone/grin/three-quarter.jpg).

**Still different from the sheet:** the teeth are a little greyer in the review light than the sheet's cream; the eyes are a little glossier; the crack layout is procedural. Materials must be baked, and the triangle count reduced, before any Roblox export.

## Implemented - half-lidded eyes in sockets and a smirk, awaiting owner review, 2026-11-08

**Owner, passing on a review of the face:** "The mouth is too straight and expressionless... an awkward, polite smile... The eyes look intense and slightly startled, while the mouth looks completely relaxed... the brow still doesn't sufficiently conceal the upper portion of the eyes... that characteristic half-lidded appearance." Its changes: eyes "Flatten their forward projection, make them slightly wider horizontally, narrow them vertically and position them deeper beneath the brow. Preserve the molten-crack effect"; brow "partially covers the upper eyes, particularly at the outer corners"; mouth "a proper curved grin. Create a slight asymmetry, raise one corner and introduce a subtle cheek crease"; "model the eye sockets and mouth geometry, not just resize the eyeballs or redraw a smile line". Default expression "a subtle, confident smirk, closer to the smaller expression on the right of your concept sheet" (the neutral close-up the owner chose), and "a more exaggerated, toothy grin for his inspection animation or when using an ability".

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v6.blend`):
- Brow: its lower edge runs lower over the eyes, through (0.20, 1.47), (0.40, 1.50) and (0.44, 1.53), before rising to the drawn-back corner. It covers the eyes' upper part, most at the outer ends.
- Eyes: shallower (0.025 proud, was 0.05), wider and less tall (radii 0.19 by 0.10, was 0.17 by 0.125), centred at (0.23, 1.435) and tilted 8 degrees. Same cracks.
- Sockets: a lower lid each side, a soft ridge of skin from under the eye's rim round its bottom. It has a shadow line where it meets the eye, crests 0.0065 just outside it and sinks back into the face; the brow hides its ends.
- Mouth: a lopsided smirk in the same carved style (dark line, raised lower lip, edges under the skin). It keeps the neutral close-up's rhythm: a curl up at his right corner, a dip, a rise through the middle, a slight dip, and his left corner raised higher (1.218, against 1.190). A faint carved crease curves close round the raised corner.
- Silhouette unchanged; `verify_slugs.py` passes. [Face beside the sheet and the previous face](evidence/rammstone/face-3/face-compare.jpg), [views](evidence/rammstone/face-3/views.jpg), [three-quarter and face, before and after](evidence/rammstone/face-3/three-quarter.jpg).

**Superseded the same day:** the owner chose the toothy grin as the mouth instead (see above).

**Still different from the sheet:** the corner curls are softer than the sheet's; the eyes are a little glossier; the crack layout is procedural. Materials must be baked before any export.

## Implemented - rounder eyes and a carved resting mouth, awaiting owner review, 2026-11-08

**Owner, on the first face:** "The eyes look too cramped, especially like in the corners... that like are meeting the forehead. Like the top left, top right. And then the mouth looks like a cat smile. Rather than this smile that's in the image. Maybe because it's too small. Doesn't have enough depth. Doesn't have that little lower lip. Thing."

**Cause:** each eye filled the opening right up into its drawn-back corner, so its outer top was squeezed into the wedge between the brow and the cheek plate. On the sheet each eye is a rounded oval, the brow crossing its top, with skin round its outer end. The mouth was a thin painted line with a peaked middle and big curled ends, which reads as a cat's ":3". The sheet's is a carved line with a small raised lower lip catching the light, and only a gentle wave.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v5.blend`):
- Eyes: a tilted ellipse (centre (0.22, 1.445), radii 0.17 by 0.125, outer end up 10 degrees). Its inner tip tucks under the brow's point, the brow hides about its top third, and its rounded outer end sits clear of the corner with skin round it. Same dome, material and cracks as before.
- Mouth: a strip of skin over the face along the line, using the skin's own material. Across it: rising out of the skin above, the dark line (an "ink" attribute, 0.010 wide in the middle, thinner toward the ends), then a raised lower lip lightened by a "lip" attribute, sinking back under the skin, so no outline of the strip shows. The line is wider (to |x| 0.378), higher (1.18 in the middle) and gently wavy, its dips out at |x| 0.30 (1.163) and its ends ticking up to 1.199.
- The face's small set-back under the cheek corners now spreads from 1.15 to 1.45 instead of 1.20 to 1.30. A suspected fold over the mouth was not this: renders with and without the mouth matched pixel for pixel above it.
- Silhouette unchanged; `verify_slugs.py` passes. [Face beside the sheet and the previous face](evidence/rammstone/face-2/face-compare.jpg), [views](evidence/rammstone/face-2/views.jpg), [three-quarter and face, before and after](evidence/rammstone/face-2/three-quarter.jpg).

**Still different from the sheet:** the mouth's end curls are softer than the sheet's ticks; the eyes are a little glossier; the crack layout is procedural. The grin and smirk are not built. Materials must be baked before any export.

## Implemented - eyes and resting mouth, awaiting owner review, 2026-11-08

**Owner:** "now add the mouth and eyes. Make the mouth and eyes look exactly like this... the way I want the mouth to look like when it's like resting is... the mouth shape in the third image [of the second row] where it's like a smile that starts up, goes down, goes up, goes down, and ends up. That's the smile I want. For the resting face." Adjusting the forehead or pushing things back to fit is allowed.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v4.blend`):
- Eyes: each is a dark glossy dome on the face inside an outline taken from the sheet's front view. The inner corner is beside the brow's point (0.06, 1.385), the lower edge curves down to about 1.30, and the outer corner (0.49, 1.46) is drawn back under the cheek plate. The top runs above the brow, which hides it. The dome rises 0.05 along the face's normal and sinks under the skin at its rim, so its lower edge is a clean curve. Material: warm charcoal, darker at the edge. Branching lava cracks run mostly across the eye from wide Voronoi cells with some edges left out, as a yellow core in an orange glow, brightest in the middle and fading before the edge, over a faint finer network. The cracks are placed by each eye's UVs, so the two eyes differ.
- Resting mouth: a thin dark brown line laid just over the skin, through points mirrored about the middle and smoothed. It rises a little in the middle (1.17), dips either side (1.146 at |x| 0.20) and hooks up at the corners (1.198 at |x| 0.361), tapering into the hooks: the sheet's neutral close-up.
- Silhouette unchanged (front 0.940, left side 0.934, back 0.850, right side 0.879). About 28,800 triangles. [Face beside the sheet](evidence/rammstone/face/face-compare.jpg), [views](evidence/rammstone/face/views.jpg), [three-quarter and face, before and after](evidence/rammstone/face/three-quarter.jpg).

**Still different from the sheet:** the eyes are wider than the sheet's (to |x| 0.49, not 0.37), because they fill the wider eye space the owner asked for. They are glossier, and their crack layout is procedural rather than the sheet's exact one. The sheet's skin has a faint lighter lower lip under the mouth, which is not built. The grin and smirk are not built yet. The eye and rock materials are procedural, so they must be baked to textures before any Roblox export.

## Implemented - eye corners and belly marks, awaiting owner confirmation, 2026-11-08

**Owner, on the keel crest round:** "look at the way the eyes look here. And the image. Where, like, it's kind of drawing back more. Making it look more predatorial. Like, I mean the corners... And also the belly markings don't look hard enough... I think it's because the lines are, like, pixelated on the belly. Once you make those two fixes, then we'll add on the mouth and eyes and be good."

**Cause:** on the sheet the brow rises over each eye to a pointed outer corner, up and back on the side of the head. The rock beside the face has a slanted front edge running down and forward from that corner. Ours had a level brow and square cheek flaps dropping straight down. The hood's lower edge has one height per column, so it cannot hold rock both above and below an opening. The belly marks were painted and pushed out across level rings of the body, so each V crossing the rows came out stair-stepped and blurred.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v3.blend`):
- Eye corners: the brow rises from its point (1.40) to 1.56 at |x| 0.44 and on to a pointed corner at (0.54, 1.62), set back on the side of the head. Behind the corner the hood comes down to 1.24. A new cheek plate each side lies on the face, with its inner face just inside the skin and its front edge 0.04 proud. That front edge slants from (0.44, 1.20) up and back to the corner, and behind the corner the plate tucks under the hood. The eye space is a little narrower low down and reaches the corner at the top.
- Belly marks: the body's rings are bent column by column so one ring runs exactly along each V. At each V the segment above stands 0.016 proud at a hard step and settles back over 0.28. The step's edges are sharp, and the dark line is exactly the step and the 0.014 band under it (a face attribute), so the lines stay crisp.
- The body's top cap point no longer sits on a ring vertex. It was hidden in the hood.
- Silhouette against the sheet: front 0.940, left side 0.934, back 0.850, right side 0.879 (unchanged). `python tools/verify_slugs.py` passes. [Views](evidence/rammstone/eyes-belly/views.jpg) (sheet, previous build, this build), [three-quarter and face, before and after](evidence/rammstone/eyes-belly/three-quarter.jpg), [scores](evidence/rammstone/eyes-belly/compare.json).

**Next:** the eyes and mouth, as the owner said; then final polish, then rig and export.

## Implemented - keel crest and wider eye space, awaiting owner confirmation, 2026-11-08

**Owner, on the forehead round:** "make the forehead marking look a little less triangular. And then you'll need to widen the area where the eyes are going. Because it looks a bit too narrow. And then from there we'll be good to go. I think. It looks good now."

**Measured on the sheet:** the grey marking is not a separate front triangle. It is a crest: a wedge up the forehead (front view), a band along the top (side view) and a wedge down the back to a point at about 1.68, about 0.17 either side at the top (back view).

**Implemented/verified** (`build_rammstone_clean.py`; the previous build is kept as `rammstone-clean-v2.blend`):
- Keel: one crest from a point at 1.52 on the forehead, up the forehead (0.21 either side by 2.04), over the top between the horns, and down the back (0.17 either side at 2.11) to a point at 1.68. Its sides bow out a little (width grows as distance from the tip to the power 0.75). The flat top edge is gone. Each row is cast in toward the middle of the head, so the rows run round it from front to back.
- Eye space: the brow now runs out to 0.44 (it ended at 0.37), at 1.54, and the hood drops beside it to the cheek corner by 0.49. A new column that would sit on an existing one is skipped.
- Silhouette against the sheet: front 0.940, left side 0.934, back 0.850, right side 0.879 (previously 0.941, 0.939, 0.851, 0.880). [Views](evidence/rammstone/crest/views.jpg) (sheet, previous build, this build), [three-quarter and face, before and after](evidence/rammstone/crest/three-quarter.jpg), [scores](evidence/rammstone/crest/compare.json).

**Next, once the owner confirms the look:** eyes, the grin, smirk and neutral expressions, and final polish. Rig and export come after that.

## Implemented - forehead, keel and cracks, awaiting owner review, 2026-11-08

**Owner, on the clean build:** "the forehead goes down too much, the gray line is too thin, and it should be wider at the top and narrow at the bottom. The cracks on the shell look a bit weird."

**Measured on the sheet's front view:** the brow's point is at 1.40 (ours 1.30), its lower edge rising to 1.49 at |x| 0.20 and 1.53 over the eye's outer edge at 0.37, where the hood drops beside the eye to the cheek; the grey wedge narrows from about 0.20 either side at the top (2.04) to a point at 1.52 (ours 0.08 at the crown, a sliver). The sheet's cracks are a fine, faint network over every plate; ours were large dark cells in patches, which read as crazy paving.

**Implemented/verified** (`build_rammstone_clean.py`; the previous build kept as `rammstone-clean-v1.blend`):
- Brow: the lower edge follows those three points, so the space under it is left for the eyes. The hood gains two columns each side, where the brow ends (0.37) and the cheek starts (0.42).
- Hood rows: every column now shares its rows (1.24, 1.36, 1.52 the visor point, 1.74 the temple corners, 1.92, 2.04, 2.14), and neighbouring columns are zipped together. With rows spread per column, the narrow new columns twisted into vertical slits; with ten evenly spaced shared rows, the outline's bumps showed as horizontal ledges.
- Keel: a charcoal wedge 0.22 either side at its top (2.12), narrowing to a point at 1.52. Two planes meet at a raised ridge, and each row is laid on the hood by casting from the front.
- Cracks: a fine, faint network, Voronoi at 14 with wobbled edges, darkening the rock to 0.62 where it shows and fading in places, in place of the patches of dark cells. The surface pass keeps its own cracks.
- Silhouette against the sheet: front 0.941, left side 0.939, back 0.851, right side 0.880 (previously 0.944, 0.941, 0.852, 0.879). [Views](evidence/rammstone/forehead/views.jpg) (sheet, previous build, this build), [three-quarter and face, before and after](evidence/rammstone/forehead/three-quarter.jpg), [scores](evidence/rammstone/forehead/compare.json).

**Still different from the sheet:** as before, the back of the hood is a rounded cap, the blades are flatter, there are no separate temple plates and the horn roots sit further back. The wedge is a darker charcoal than the sheet's mid grey, and its top runs a little over the dome. The skin under the brow is bare until the eyes go in.

## Implemented - clean build from the sheet's measurements, awaiting owner review, 2026-11-08

**Owner, on the refinement pass:** "What you've made doesn't look clean like this. Like the armor on the edges looks like like it's splitting or something. Like there's loads of little miniature spikes. The place where the horn's coming out of is elevated rather than just being attached to the head like normal... The horns themselves don't look like how they look like in the image... You just need to lock in."

**Cause:** every pass so far edited one surface made from voxels, and faceting or smoothing a voxel surface keeps its noise (the spikes and splitting); the hood was cut flat where the horns separate, so the horns stood on a shelf; the horns were tubes swept along a raw skeleton.

**Implemented/verified:** a clean rebuild of each part on the approved proportions, from [`rammstone_measure.py`](../../../tools/slugs/rammstone_measure.py) (the sheet's outlines per height, plate tips, horn centreline) and [`build_rammstone_clean.py`](../../../tools/slugs/build_rammstone_clean.py), saved as `rammstone-clean.blend` (earlier files kept):
- Body: a smooth lofted column (face line and skin width from the sheet, smoothed), set back under the hood, the belly's two V markings as steps.
- Armour: 24 separate blades in four chevron rows. Measured on the sheet, each row's lower edge runs from a spine tip (0, 0.31, 0.74, 1.32 in the side view) up to a side tip about 0.3 higher (0.28, 0.69, 1.03 in the front view). Each half-row is three overlapping blades pointing down and back, thickest at the tip, thinning toward the belly, creased into two planes; under them a smooth rock layer.
- Hood: one faceted shell (16 columns) lofted through the sheet's outline at each height: a pointed visor, a ridge down the back, a dome to the crown with no shelf, a V brow between cheek corners at the front, and a back edge that points down at the spine and rises to back corners. A flush charcoal keel narrows from the crown to the brow's point.
- Horns: six-sided, along the sheet's smoothed centreline, set and sized by the front view, long front-to-back at the root, tapering to a point, their roots sunk into the dome.
- About 26,000 triangles; bevelled edges; flat-shaded rock and horns, smooth skin. Silhouette against the sheet: front 0.944, left side 0.941, back 0.852, right side 0.879. [Views](evidence/rammstone/clean/views.jpg) (sheet, previous version, clean build), [three-quarter and face](evidence/rammstone/clean/three-quarter.jpg), [scores](evidence/rammstone/clean/compare.json).

**Still different from the sheet:** from the back the hood is a broad rounded cap where the sheet's is a narrower angular pentagon; the blades lie flatter than the sheet's chunky ones, especially in three-quarter; the hood has no separate pointed temple plates; the horns' roots sit further back on the head than in the hero view; the belly creases are soft. Eyes and mouth are not built yet.

## Implemented - refinement pass, awaiting owner review, 2026-11-08

**Owner:** "This version is much closer. Keep the current rocky surface language, horn style, and overall silhouette direction. Do not restart." The face opening "too flat and horizontal; make it feel framed by a heavier V-shaped brow and more sculpted rock cheeks"; the forehead "a stronger, more intentional volcanic hood"; reduce "the stacked horizontal band look by making the armour read as fewer, larger interlocking masses"; the back silhouette "less uniform and cylindrical". "This is now a refinement pass, not a rebuild."

**Implemented/verified** (same builder, `build_rammstone_surface.py`; the previous pass is kept as `rammstone-surface-v1.blend`):
- Face frame: brow line steeper (`1.30 + 0.85|x|`), eye areas set back 0.075; the hood's lower corners beside the eyes became rock cheek plates down toward the mouth, 0.045 proud at their inner edge and pointed at the bottom; the thin lip the blockout left under the eyes is pulled back to the face.
- Hood: its front cut into two flat planes (set back 0.38 per unit of |x|) meeting at the central ridge. The keel is now its own thin charcoal plate placed on that surface by ray casting, a wedge from the brow's point (0.006 wide) to the crown (0.116), because a painted border on the approved mesh's long triangles always zigzagged.
- Armour: below the hood, the stacked bands are smoothed out of the armour's radius and replaced by about four tiers of large, staggered wedge plates in V rows rising to the sides (0.44 tall, 0.95 radians wide, varied in height, width and thickness), with a spine ridge. Part labels tidied by neighbour vote; faceting stays a ring away from part borders.
- Silhouette against the sheet, previous pass to now: front 0.978 to 0.960, left side 0.978 to 0.960, back 0.840 to 0.830, right side 0.891 to 0.882; the change is the new plate tips and spine on the back and sides. About 53,000 triangles plus the keel. [Views](evidence/rammstone/refine/views.jpg) (sheet, previous pass, now), [three-quarter and face](evidence/rammstone/refine/three-quarter.jpg), [scores](evidence/rammstone/refine/compare.json).

**Tried and dropped:** subdividing the face region so painted borders run cleanly; it left the forehead unfaceted and stippled and slit the hood planes.

**Still different from the sheet:** the hood is still one block where the sheet's is built from several overlapping, angular slabs that wrap down past the eyes; the back plates are larger and less banded but not as orderly as the sheet's chevrons; some skin and rock borders still show small teeth; the eye areas are flat skin patches waiting for the eyes.

## Implemented - surface pass on the approved blockout, awaiting owner review, 2026-11-08

**Owner, approving the blockout:** "I'm happy with the overall shape and proportions, so **freeze the major geometry and silhouette**. Do not rebuild the entire model again." Then: armour "too smooth, glossy and horizontally ribbed", to become "solid, faceted volcanic rock, with restrained irregular cracks, darker crevices and more matte surfaces", checking "whether the repetitive bands come from geometry or materials"; the forehead "a stronger, heavier V-shaped brow with a distinct central angular ridge, rather than a broad horizontal band", locally; "smooth the unwanted wrinkles on the exposed beige body and preserve its deliberate V-shaped markings"; horns "a more faceted stone finish"; no "hundreds of tiny cracks or excessive roughness"; eyes, expressions and polish after approval.

**Confirmed (shape gate):** the silhouette blockout's shape and proportions are approved and frozen (`rammstone-blockout.blend`, unchanged).

**Implemented/verified:** [`build_rammstone_surface.py`](../../../tools/slugs/build_rammstone_surface.py) edits that mesh into `rammstone-surface.blend`:
- Bands: every rock vertex had one flat colour, so the bands were geometry. The fine one-pixel ribbing from the row-by-row carve is smoothed out without shrinking (Taubin); the larger bands are the plate rows of the frozen profile and stay.
- Rock and horns: neighbouring faces within 18 and 16 degrees merged into flat facets, shaded flat. Rock is matte (roughness 0.92), varied per facet, darker in crevices (ambient occlusion) and cracked only in a few patches; horns and keel matte charcoal, varied per facet.
- Forehead, depth only: eye areas under a V brow line (`1.30 + 0.75|x|`, eyes at about +-0.275 on the sheet) set back 0.05 so the brow overhangs them; the hood's front set back by `0.18|x|`, leaving a central ridge, with a charcoal keel narrowing to the brow's point.
- Body: smoothed, pushed back out by its average shrink, then the sheet's two V markings (tips at 0.54 and 0.15, slope about 0.5, measured on the front view) as shallow steps with dark creases.
- Silhouette against the sheet, blockout to now: front 0.980 to 0.978, left side 0.987 to 0.978, back 0.838 to 0.840, right side 0.886 to 0.891. [Views](evidence/rammstone/surface/views.jpg) (sheet, blockout, surface), [three-quarter and face](evidence/rammstone/surface/three-quarter-and-face.jpg), [scores](evidence/rammstone/surface/compare.json). About 34,000 triangles. Materials are procedural for review; they must be baked to textures before any Roblox export.

**Still different from the sheet:** the back and sides read as horizontal bands where the sheet has V-shaped chevron rows; those bands are the frozen geometry, so changing them is a local reshape of the back, not a surface fix. The keel reads as a near-parallel bar where the sheet's narrows to a wedge. The eye areas are flat skin patches with a small ledge below; they are where the eyes go. The facets are irregular triangles rather than the sheet's few large, deliberate planes.

## Implemented - image-driven silhouette blockout, at the owner's approval gate, 2026-11-07

**Owner:** stop the procedural model ("we're generating geometry from descriptive assumptions rather than directly matching the visual shapes"); keep it as a backup; import the sheet into Blender, align front and side, block out from the actual silhouettes with simple materials, compare with overlays and silhouette masks, and "stop after the major silhouette blockout". "If the procedural workflow cannot achieve the required geometry, explain the limitation and propose a practical alternative using Blender's direct modelling or sculpting tools."

**Implemented/verified:**
- Backup: `assets/source/slugs/models/rammstone/rammstone-procedural-v1.blend` (the previous model; `build_rammstone.py` unchanged).
- [`rammstone_reference.py`](../../../tools/slugs/rammstone_reference.py) cuts the front, both sides and back out of the sheet, models the background gradient, finds the figure (horns included, by edges as well as colour) and labels rock, skin and horn. All four views share a scale (bases at rows 296 to 297).
- [`rammstone_blockout_volume.py`](../../../tools/slugs/rammstone_blockout_volume.py) carves the volume inside both the front and the left-side silhouettes: a smooth body column (face line in profile, skin width from the front) up to the visor's underside; armour and hood as the rounded carve; horns swept along the side view's medial axis, set and sized by the front view.
- [`build_rammstone_blockout.py`](../../../tools/slugs/build_rammstone_blockout.py) builds `rammstone-blockout.blend` with three flat colours and the four sheet views on aligned reference planes (collection `Reference`, culled from behind so each shows only to its own view; alignment checked in front and side renders) and renders matching orthographic views; [`rammstone_compare.py`](../../../tools/slugs/rammstone_compare.py) makes the comparisons.
- [Comparisons](evidence/rammstone/blockout/) (sheet, blockout, silhouette difference, overlay) and [scores](evidence/rammstone/blockout/compare.json): silhouette overlap 0.980 front and 0.987 left side (these carve the volume, so they match by construction); 0.838 back and 0.886 right side, which equal the sheet's own disagreement between its views (front against mirrored back 0.850, left against mirrored right 0.894).

**Confirmed by the comparison - the limitation:** two silhouettes fix outlines, not masses. From three-quarter ([comparison](evidence/rammstone/blockout/compare-three-quarter.jpg)) the carve is a ringed barrel with a round cap, not the sheet's character: the profile's plate tips sweep round the body as rings, the hood is a closed drum rather than overlapping slabs, and nothing tells the carve how the plates are layered. The sheet's views also disagree by up to 15 percent, so no single shape can match all of them exactly. Also measured: in profile the armour is about half the body's depth, and the depth is close to the front width; the procedural model's thin shell on a narrow column was wrong from the start.

**Considering - proposed next step, not approved:** model the masses directly in `rammstone-blockout.blend` against the aligned reference planes, using the carve only as an outline guide: the body as one low-poly column shaped loop by loop to the front and side; the hood as one mesh cut from a box into the visor wedge and V brow; each major armour plate (about 12 to 16) as its own low-poly wedge, placed from points measured in the side and back views; the horns as a curve with a bevel following both views. Alternatives for the owner: model it by hand in this file; or an image-to-3D service on the sheet's hero view, which sends the sheet outside and may cost credits, so it needs approval first.

## Implemented - first Blender model, awaiting owner review, 2026-11-07

**Owner:** "Please make the following changes directly in Blender": armour plates "significantly larger, longer and less numerous", irregular, with more volume around the cheeks, shoulders and upper body; the hood "heavier, wider and more substantial", the brow lower over the eyes, integrated with the side armour, avoiding "an excessively sharp, narrow triangular forehead"; thicker, faceted horns leaning out; bigger, more visible eyes with irregular molten fissures; then the simpler grin with smirk and neutral, and controlled warm edge highlights. "Do not proceed to final rigging or Roblox export until we've reviewed and approved the model's appearance."

**Implemented/verified (review model only):** [`build_rammstone.py`](../../../tools/slugs/build_rammstone.py) ports the concept to NumPy, as Inferno's builder does, with the structural changes in the shapes: plates 0.40 rows and 0.80 radians apart (from 0.33 and 0.66), 0.66 to 0.82 long, each jittered in height, angle, sweep, width and thickness, thicker towards the head and outer columns; a wedge hood (visor jutting past the face, sloping back to the crown, V brow `1.57 + 0.55|x|`, a narrow flat down the middle); hexagonal-section horns leaning out and arcing back from the rear of the hood; eyes 0.185 x 0.112, brought forward; grin, smirk and neutral mouths; warm highlights painted on plate edges, hood facets and the brow rim (colour only, no emission, so it carries to Roblox). Blender 4.5.14 headless, surface nets at 0.011, voxel remesh, reduced to 140,000 triangles plus subdivided eyes (about 213,000 in all): 0 non-manifold edges, 0 loose vertices for all three expressions. Source: `assets/source/slugs/models/rammstone/rammstone.blend` (grin). [Renders](evidence/rammstone/blender/), [comparison with the sheet](evidence/rammstone/blender-comparison.jpg), [expressions](evidence/rammstone/blender-expressions.jpg). `python tools/verify_slugs.py` passed (it does not cover this builder).

**Still different from the sheet:** the hood is one faceted block where the sheet's is several overlapping slabs, so it still reads slightly as a helmet; the back's chevron rows are less orderly; the body is a little taller and narrower; the grin is smaller at a distance and the smirk subtle. **Not done, by instruction:** rig, weights, mouth controls for switching expressions (each is a separate build now), texture bake, game-budget mesh and Roblox export. The concept page was not updated to these shapes.

## Considering - visual design, third concept, 2026-11-07

**Owner on the second concept** (a written brief with two screenshots and the sheet): the armour "looks like thin, loosely hanging sheets or fabric" and must be "thick, jagged, overlapping volcanic stone, not a helmet with a red cape"; the head "too rounded and soft", wanting a "pronounced, angular V-shaped brow" and swept-back temple plates; horns "too straight, narrow and upright"; eyes "decorative, honeycomb-like", wanting "glowing orange molten fissures"; "Prioritise shape accuracy over surface polish." The sheet is the source of truth.

**Implemented, awaiting owner review** (same page and link; [comparison against the sheet](evidence/rammstone/comparison.jpg)): every plate rebuilt as a solid rock wedge, pointed and thickest at its lower edge, ridged, sweeping down and back, in chevron rows up the spine to the top of the head; armour limited to the back half (1.85 radians from the spine) so the profile shows the tan face and belly, with the outer columns flaring so they edge the front silhouette; an angular hood from intersecting planes, widest at a jutting V brim and narrowing to the top; a broad two-faceted charcoal keel; thicker horns (base radius 0.22) set wider and further back, arcing back; eye fissures from noise, not cells; stepped belly chevrons; a straight column base. Eight render rounds, compared view by view against the sheet's turnaround.

**Still different from the sheet:** its plates are bigger and fewer with longer blades; its hood and brim are heavier and cover the head further down; its horns are faceted and lean outward more; its eyes are bigger and show more in profile; its lit rock has a warm glowing rim. No Blender model, rig or export exists yet, so the brief's technical requirements apply to the Blender build after approval.

## Considering - visual design, second concept, 2026-11-07

**Owner on the first concept:** "The armor layer is too thick. The horns are... too close to each other, not far apart enough. And they're pointing upwards too much... Or curling backwards more rather. The eyes are okay, but they should be shaped more in a predator hunter way. Right now they're too circular... The smile's too wide as well. And the sharp cones on the ears, I don't like."

**Implemented, awaiting owner review** (same page and link): plates about half as thick (lower-edge lift 0.13 to 0.075, hood 0.10 to 0.055); horn roots 0.22 to 0.30 apart from the centre, curling back so the tips point behind him; eyes now slanted almonds, wider than tall, rising to the outer corner and cut flat by the brow; grin 1.35 times narrower; cheek cones removed. First concept kept at the scratch copy only; its renders were replaced.

## Considering - visual design, first concept, 2026-11-07

**Owner, 2026-11-07:** "this is the proposed design for rammstone, make this using our workflow", with a proposal sheet ([owner-proposal.png](evidence/rammstone/owner-proposal.png)). It shows a tall, upright tan slug wearing red rock armour: overlapping chevron plates down the back and sides, a hood with an angry V brow and pointed cheek plates, a charcoal keel down the forehead, two thick charcoal horns sweeping back, dark eyes with glowing lava cracks and a wide, cocky toothy grin. The sheet's three-expression row (smirk, grin, flat) is not modelled yet.

**Implemented, awaiting owner review:** [concept page](evidence/rammstone/rammstone.html), published as [Rammstone](https://claude.ai/artifact/BEec6CWqtvkshR2HrVhC52), with [turntable frames](evidence/rammstone/frames/) from [`render_concept.py`](../../../tools/slugs/render_concept.py) (`--forms base`). Original signed-distance shapes, no imported mesh or texture. Inspected front, three-quarter, side, back and face close-up over three rounds: a too-bright warm rim light lit whole back surfaces as tan streaks (now limited to the silhouette), the cracks read as tiling (now sparse patches), and the plates, hood, horns and eyes were enlarged. Known differences from the sheet: the cheek plates are spikes rather than broad flared plates, the keel is thinner, and the plates are less sharply faceted. No Blender, Roblox or gameplay work.

## Confirmed - owner's direction, 2026-11-05

**Owner:** a basic, strong punching slug. On a player "it would just more so punch you. Like that would literally just be it." Its usefulness comes from the passive:

- **Shoot the ground** to punch a rock wall up as cover, as the ice slug can.
- **Punch out parts of the map:** shoot an arch above and rock falls to cover a pathway; shoot a spire on top and it comes down and damages an opponent.

Maps will be modelled around this rather than the ability fitting an existing map.

**Confirmed main, 2026-11-05: Shove Punch**, a strong punch with a short knockback. Plain Punch was the alternative the assistant had recommended; the owner chose the shove. The passive's working name is Rockbreak, which is the assistant's name and not yet approved.

**Confirmed plain surfaces, 2026-11-05:** a hit on a plain wall or ceiling "should probably just shoot down or like release a bit of rubble. That does a slight little bit of damage. To anyone below it." Someone wall-running on the struck wall gets "knocked off". This makes every shot useful and rewards hitting wall-runners.

## Unresolved

Owner verdict on the first visual concept; the passive's name; how rock wall differs from Ice Wall beyond being stone. Numbers and balance come later.

## History

**Rejected, 2026-11-05:** Battering Ram, Momentum, Breakthrough, Rockfall, Upheaval and Stonestep ("I don't really mess with any"). Source: `tools/slugs/ability-lab/history/before-rockbreak`.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers the punch, dodge, cover and flank, arch block and beating it, and spire hit and dodge. See `build/slugs/ability-lab/qa/`. Browser demonstrations with placeholder players are not physics, balance or Studio evidence. In the lab, the Wall button stands for an arch and the Ceiling button for a spire.

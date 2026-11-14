# Slug design record: Boon Doc

## Confirmed - final base design, 2026-11-14

**Owner:** "save this as the base design. It's really good, well done." **Confirmed (owner):** the base form as of round 14 below is final: the Inferno-Aquabeek crossover head, the Healing mint eye with its gilded lid, the taller reference smile, the halo (thicker, at y 2.50), short gold-tipped antennae flopping back, the inner-and-rising-light belly with its gold edge, and the small fluid angel wings joined at a slim stem. Accepted means stop: change it only on request. **Saved:** page and 26 frames in [evidence/boon-doc/base-final](evidence/boon-doc/base-final/boon-doc-base.html); the template still builds it (`BASESEL` b3, e2, m0, y7), and after the transformed form was added its frames match the snapshot pixel for pixel.

## Confirmed - final transformed design, 2026-11-14

**Owner:** "Okay, it's much better, but remove the gold lines you added coming out of the I ... And then after that, finalize it as the final design." **Done:** the gold line along the painted cap's front edge removed (it ran out from either side of the eye). **Confirmed (owner):** the transformed form below (round 5 without that line) is final: a fat, warty flying toad that is mostly head (sagging gut, double chin, warts over the top, sides and face); one smooth head with the deep teal cap painted on; the Healing mint eye with its gilded lid; the wide reference smile; the halo floating over the forehead; seven spines from the forehead down the back, tipped with glowing ivory-gold bulbs; thick, relaxed arms with drooping hands and glowing ivory fingertip pads; short fat legs dangling; angel wings lying along the upper back with the feathers fanned open; the ivory underside blending softly into the green with an inner light, no line. Accepted means stop: change it only on request. **Saved:** page and all 52 frames (both forms) in [evidence/boon-doc/transformed-final](evidence/boon-doc/transformed-final/boon-doc-final.html); the template still builds it (`XF 1`, form key `comet`); base frames still match the base snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 13.

## History - transformed form, concept 3 round 5: cap as paint (no lump), narrower face, warts on the front, 2026-11-14

**Owner, with a front crop:** "From the front, it looks bad ... you can firstly still see the big lump thing ... This happened with Ramstone as well. It's so flipping annoying. Just fix it now, bro. I'm not doing this again. And then it just looks a bit too fat from the front ... from the sides and back it looks fine ... add more of the bump things ... on the front as well."

- **Lump, fixed at the cause:** any cap built as its own shape (the brow ridge, then the one-piece shell) leaves a ridge where its skin meets the head's: blending moves the line but never removes it (the Rammstone lesson). The cap is no longer geometry: the head is one smooth surface and the cap is painted on it (`capLine`: deep teal above y 1.77, dipping 0.05 over the eye, a fine gold line along its front edge). Zoomed front and three-quarter views show no ridge.
- **Less fat from the front:** head half-width 0.82 to 0.72, chin 0.66 to 0.58, lower chin 0.46 to 0.40; shoulders, elbows and wrists brought in 0.05 to 0.06. Side and back proportions unchanged.
- **Warts on the front:** the warts' front cut-off removed, so they cover the face and cheeks too, kept clear of the eye (an ellipsoid round `EYE_C`) and the mouth band.

**Verified:** full turntable, close-up and top view at 560 px inspected, front zoomed; base frames match the snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 12. **Unresolved:** owner verdict; the painted cap reads more as a gold-edged band than an overhang.

## History - transformed form, concept 3 round 4: smooth forehead, halo clear of the spines, no belly line, 2026-11-14

**Owner, on round 3 (with two crops):** "The wings need to move a little bit more up on the body ... the halos like intervening with the spines. It should be a bit more forward on the forehead. And then maybe raise it up a little bit ... the gold line isn't really doing its thing ... it doesn't make sense to actually have it, because we're going to be blending the white into the blue anyways. So I think remove the gold line and then just blend the white in nicer into that green color ... it's still looking quite blocky ... there's just a lump on the forehead that's visible from all angles ... Make it look like a smooth finish."

- **Forehead:** the lump was the separate brow ridge stacked on the cap. The cap is now one smooth ellipsoid shell (0.58, 0.13, 0.64) at (0, 1.80, 0.20), tipped forward 0.14 rad so its front edge rolls over the eye (`capLocal`); the gold line runs along that front edge.
- **Halo:** forward and up to (0, 2.44, 0.60), floating over the forehead, clear of every spine.
- **Wings:** root moved up and forward onto the upper back (0.32, 1.90, -0.10).
- **Belly:** the gold line removed. The ivory blends over a much longer range (mint from e -0.35, ivory from -0.05 to 0.50, eased), inner light kept.

**Verified:** full turntable, close-up and top view at 560 px inspected, head zoomed; base frames match the snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 11. **Unresolved:** owner verdict.

## History - transformed form, concept 3 round 3: wings flat with spread feathers, halo on the head, blended belly, 2026-11-14

**Owner, on round 2:** "still make the wing stack be like flat on the body, not the way that you done them. Like the way they were before, but just make the actual feathers and stuff look spread out. And then the halo should be moved to like near on top of the forehead, or on top of the actual head. Then make like blend in the white ivory under the body and stuff better, and give it that gold inner line thing and the glow and stuff still." **Considering:** "spread out" means the feathers fanned open, not the wing's pose; the earlier lying-flat pose stays.

- **Wings:** back to lying along the body (raised 0.40 rad, beating 0.10, swept back as concept 2), root (0.32, 1.84, -0.28). Transformed-only feather fan: `fanU` diverges much faster (1.05 per unit depth, base 0.60), the outer edge swings outward with depth (`wingOut` +0.30), and small gaps open between the flight feathers toward their tips (up to 0.030), so the wing reads as fanned open. `WSPAN` (1.15, 1, 1).
- **Halo:** resting just above the head at (0, 2.18, 0.40); the forehead spikes pass up through it.
- **Belly:** painted by how far the smooth body faces down (`bodyN`, the warts-free body normal taken over a wide 0.12 step so the seams between its lumps don't show), mixed 55/45 with height: celadon paling through soft mint into ivory, a fine gold line set inside the ivory, and an inner light growing toward the middle. A first pass on the normal alone made the gold line wobble over the gut and chin seams.

**Verified:** full turntable, close-up and top view at 560 px inspected; base frames match the snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 10. **Unresolved:** owner verdict; from the front the flat wings read as thin lines.

## History - transformed form, concept 3 round 2: wings open, longer spines, limbs with weight, 2026-11-14

**Owner, on concept 3:** "Move the wings further up body and make them look like spread out ... I don't mean spread out by making them wide, but ... make them look like the wings are now out ready to flap. Right now they're still like tucked in ... make the spine things be a bit longer ... maybe like by 20% ... make the positioning of the arms and legs a bit better, like the weight ... the way they're resting form is. Is just very weird."

- **Wings:** root moved up and forward onto the shoulders (0.30, 1.86, -0.12). The wing now stands up off the shoulders facing forward instead of lying flat along the back (why it read as tucked): outward axis raised 0.62 rad (beating 0.16) and swept back (z -0.55), its in-plane "up" kept near vertical, so the top edge rises up and out and the feathers fan down and outward like the base form's angel wings opened. Size 0.72 and `WSPAN` (1.10, 1, 1), so not stretched wide.
- **Spines:** 20% longer (length 0.36 to 0.24); the halo raised to y 2.56 to clear them; the bounding box enlarged.
- **Arms:** held forward but relaxed: upper arm dropping to a bent elbow (0.90, 1.14, 0.36), forearm forward to the wrist (0.80, 1.14, 0.80), the hand tipping down from the wrist, four stubby fingers drooping and curling at the last joint. A first pass dropped the hands below the body and read as front legs.
- **Legs:** dangling under the heavy body, as if the wings only just hold him up: hip (0.44, 1.12, -0.58), knee bent a little outward (0.64, 0.84, -0.66), shin hanging back and down, limp feet pointing down and back.
- **Colour:** limbs' undersides pale by surface normal; the belly lamp no longer lights the limbs.

**Verified:** full turntable, close-up and top view at 560 px inspected; base frames match the snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 9. **Unresolved:** owner verdict; the wings are edge-on from the exact side.

## History - transformed form, concept 3: fat, a little ugly, a glowing spine, 2026-11-14

**Owner, on concept 2:** "looks a bit closer to what I want, but I don't like the legs, and the arms look a bit too thin, and the entire body is just a bit thin ... maybe we should have this slug looking like a little bit ugly ... Its current build is ugly, even though it's elegant. And I think maybe it could be a little joke ... Rather than doing the just horizontal line of spikes on its back ... a line of spikes going down its spine ... from its forehead to its spine. And rather than spikes, let's have them have like illuminated bulbs on the tips. Like the normal Slugterra design has. And then we can make them glow like the yellow ivory thing." **Kept from concept 2:** the cap with its gold brow, the Healing mint eye, the wide reference smile, the halo, the glowing fingertips, the wings, the colours.

- **Body (`bodyMass`, XF 1):** fatter and saggy: torso (0.74, 0.44, 0.84) at (0, 1.40, -0.22), head (0.82, 0.40, 0.60) at (0, 1.52, 0.38), a sagging gut (0.62, 0.30, 0.66) at (0, 1.14, -0.16), a double chin (two masses under the mouth). **Warts (`warts`):** low bumps from crossed sines over the top and sides of the back, displacing 0.014, a shade lighter on top, kept off the face, cap and belly.
- **Spine (`spines`, replaces the tendrils):** seven short spikes along the midline from the forehead (z 0.52) over the cap and down the back (z -0.98), leaning further back toward the tail and shrinking (length 0.30 to 0.20), each tipped with a bulb (radius 0.078 scaled down to 75%) coloured warm gold to ivory, self-lit, with a soft bloom added along the ray round each bulb so they read as lights; they sway in turn. A bounding box gives far points a true distance bound (a first, slab-shaped early-out drew a giant wall and false shadow stripes).
- **Arms:** thick and pudgy (radii 0.15 to 0.085, was 0.075 to 0.042), shoulders further out for the fatter body, four stubby fingers with pads radius 0.042.
- **Legs:** the trailing frog legs replaced by short, fat toad legs folded against the back of the body (thigh radius 0.22), shins tucked underneath, stubby three-toed feet.
- **Placements:** eye (0, 1.54, 0.96), halo raised to (0, 2.46, 0.16) to clear the spine, wings from (0.30, 1.80, -0.40), cap raised 0.04 onto the taller head; the belly colour mask widened.

**Verified:** full 24-frame turntable, close-up and top view at 560 px inspected; base frames still match the saved snapshot exactly (max pixel difference 0); published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> version 8. **Unresolved:** owner verdict; whether the warts are the right kind of ugly; the bulbs read pale ivory-gold rather than yellow; the forehead spikes bunch together from the front.

## History - transformed form, concept 2: the show's flying toad made elegant, 2026-11-14

**Owner, on concept 1:** supplied two stills of the show's transformed form (not stored; study material, no reuse rights): the green form side-on and the white form from the front. "doesnt resemble this at all." **What the stills show:** a compact, wide, flat-headed toad that is mostly head; a flat dark cap over the top of the head overhanging the one eye like a brim; a wide open grin with teeth; long frog arms reaching forward with splayed fingers ending in round pads; frog hind legs trailing; wavy tendrils streaming back from the back; a pale chest and belly; a glowing aura. **Taken:** that silhouette and its parts. **Not taken:** the open toothed mouth (his reference smile instead), the plain green, the rough skin.

- **Body (`bodyMass`, XF 1):** a long flat torso (0.58, 0.30, 0.80) at (0, 1.40, -0.20) merged with a wide head (0.74, 0.36, 0.58) at (0, 1.50, 0.38) and a soft chin; the concept-1 neck, torso, tail and tail fan are history.
- **Cap (`capMass`):** the head's dark teal top (0.54, 0.13, 0.58) curving down at the front into a brow tilted 0.45 rad over the eye, blended 0.22, a gold line along the brow's edge. A first, wider flat shelf read as a jar lid.
- **Face:** the Healing mint eye at (0, 1.53, 0.935) under the brow; the reference smile widened (half-width 0.34, opening 0.10) at y 1.275; the halo at (0, 2.24, 0.18).
- **Arms (`arms`):** from the body's sides (0.50, 1.40, 0.02) out to the elbow and forward to the wrist (0.74, 1.36, 0.92), four splayed fingers 0.30 long ending in small pads paling to glowing ivory (healing hands). First passes hung down like front legs and came out of the mouth corners.
- **Legs (`legs`):** frog legs from the hips (0.36, 1.30, -0.62) out to the knee and back to a webbed three-toed foot, kicking gently.
- **Tendrils:** five feathered tendrils from the back of the head streaming back, gold tips.
- **Wings:** his angel wings at 0.70 size and 1.45x wider than long, from the back (0.26, 1.72, -0.36), raised 0.55 rad and beating slowly.

**Verified:** full 24-frame turntable, close-up and top view inspected; base frames still match the saved snapshot exactly; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict; how elegant it reads; whether the wings belong on this form; the cap's edge from some angles.

## History - transformed form, concept 1 (a lean winged flyer), 2026-11-14

**Owner:** "Now let's move on to the transform design ... we need to find a way to mesh or merge the kind of direction we've taken with this with the Slugterra original design ... the main features I would want is obviously the singular mint eye ... It just needs to look like the one from Slugterra, but just look more elegant. Whilst keeping the same shape ... that's exactly what we've done with [Aquabeek] ... we took the silhouette from the show, but then we just made it look more elegant ... how are we gonna incorporate the wings?" Earlier: the show's transformed form "looks more insect almost". No reference images of the show's transformed form were supplied this round; the silhouette is taken from the thumbnails in the first screenshot (a lean, flying, frog-like creature: a big head and grin, spiky tendrils streaming back from the head, small arms forward, a tapering body).

Built in the base form's code behind `XF 1` (the old axolotl-wyrm code removed), as Aquabeek's transformed form is, so the eye, gilded lid, mouth, wings and halo are shared code.

- **Head:** broad and rounded, flatter than a ball, with a longer snout (head (0.62, 0.38, 0.56) at (0, 1.54, 0.18), crown, snout (0.44, 0.24, 0.36) at (0, 1.40, 0.50)); the eye at (0, 1.62, 0.72), the mouth at y 1.32, the halo at (0, 2.16, 0.12).
- **Wings (the owner's question):** his angel wings grown into flight wings (`WING_S` 0.95, drawn 1.85x wider than long, `WSPAN`), rooted on the shoulders (0.22, 1.62, -0.30), the covert feathers along the leading edge, flight feathers trailing, raised in a V (0.42 rad) and beating slowly. A first pass reused the hanging wing's proportions and read as swept-back fins and planks.
- **Tendrils:** the show's spiky head tendrils as his antennae grown into long feathered tendrils, two a side, streaming back with gold feathery tips.
- **Forelimbs:** the show's small arms as two slender forelimbs folded under the chin, hands held together (mantis-like, or prayer), celadon with ivory hands. A first pass read as landing skids.
- **Body:** a neck setting the head apart, a compact, slightly hunched torso, a slim tail with a slow wave, ivory belly underneath glowing and warming toward the tail; a fan of five ivory tail feathers. A first, torpedo body read as a fish (the owner rejected the fish look in round 1).

**Verified:** full 24-frame turntable, close-up and top view inspected; base frames unchanged; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict; from above it still leans toward a tadpole with wings; how close this is to the show's silhouette without proper references; whether the folded forelimbs read well.

## History - base form round 14, wings further apart and fluid, 2026-11-14

**Owner, on round 13:** "[can't] see them from the front, or maybe need to increase the gap between the wings a bit more again ... make them look more free and fluid. Right now they look just like stiff blocks." (The opening words were cut off; read as the wings not showing from the front.)

- **Gap:** roots from x 0.05 to 0.17 (`WING_ROOT` (0.17, 1.30, -0.44)), turned from 0.66 to 0.50 rad back from the side; the outer feathers now show past the body from the front.
- **Fluid:** the flight feathers fan (`fanU`: measured across, they widen by 0.60 per unit of depth and curve outward by 0.12 depth squared) instead of running in parallel strips; the wing bends, cupped across and its lower feathers curling back (0.08 depth squared), with a slow ripple flowing down them.

**Verified:** full 24-frame turntable; front and back inspected at 900 px; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict; the transformed form; Blender build.

## History - base form round 13, smaller wings with a clean joint and a closer halo, 2026-11-14

**Owner, on round 12:** "At the point where the wings connect, there's like a bulb of green flesh ... It should just be a clean connection"; "reduce the size of the wings, then ... make them kind of push outwards a bit. You made them go a bit too inwards"; "They shouldn't be the main thing"; "make the halo ring not look so thin from the side ... a little thicker ... move it a bit down ... closer to the head." "And then I think we'll be done."

- **Clean joint:** the round-12 stem was skin-coloured and blended (0.04) into a green lump. Now a slim stem (`wingStem`, radius 0.026 to 0.020) coloured like the wing, blended only 0.012; the wing plane leans back toward the bottom (`V` tilted 0.28) so only its root meets the body.
- **Wings smaller and spread a little:** scaled by `WING_S` 0.74; turned from 0.86 to 0.66 rad back from the side; root (0.05, 1.30, -0.47).
- **Halo:** half-thickness 0.022 to 0.034; lowered from y 2.58 to 2.50.

**Verified:** full 24-frame turntable inspected; the joint checked close up from behind at 900 px (no lump); published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict (the owner expects this to finish the base form); the transformed form; Blender build.

## History - base form round 12, wings lower, folded in and in the ivory light, 2026-11-14

**Owner, on round 11:** "Move the wings down and closer together and it also looks like the wings connect to the body on like every part of the back. When they should just connect on like one part"; "make them be more inwards. They're flapping out a bit too much"; "make them the same color as like the ivory inner light thingy ... the same color as like the belly and inside of the eye."

- **Placement:** root moved from (0.10, 1.48, -0.36) to (0.05, 1.28, -0.50) (`WING_ROOT`): lower, nearer the spine and standing just off the skin; the wing plane turned from 0.46 to 0.86 rad back from the side (folded in); sway 0.05 to 0.02.
- **One joint:** the wings no longer blend into the body along their inner edge (`min`, not `smin`); each joins only through a short soft stem from the back to the top of its inner edge.
- **Colour:** the belly's warm ivory (`BELLYC` toward (1.0, 0.93, 0.76)) glowing from within (0.24), warming to gold toward the bottom like the belly's rising light, with warm creases instead of grey.

**Verified:** full 24-frame turntable inspected at front, three-quarter, side, back and close-ups; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict; from the back diagonals the far wing shows edge-on as a thin strip; the transformed form after the base is agreed.

## History - base form round 11, angel wings after the owner's reference, 2026-11-14

**Owner, on round 10:** supplied a stock image of classic angel wings (licensable, not stored: two white feathered wings, rows of small rounded covert feathers along the arching top, long flight feathers hanging below with rounded tips, warm light glints): "The angel wings should look more like this ... because I like them the most"; "the belly should be the combo of both"; "make the smile like wider vertically." **Confirmed (owner):** wings as the body design; belly Both (`BELLYV 7`). Every row is now picked (`BASESEL` b3, e2, m0, y7); the page shows one design with a full 24-frame turntable (`OPTIONS` empty).

- **Angel wings (`BODYV 3`, `angelWing`):** in a plane from the upper back ((0.10, 1.48, -0.36)) turned 0.46 rad back from the side, swaying 0.05; cupped 0.07 toward the back. Outline: top edge `0.04 + 0.56 sin(pi u)^0.75 (1 - 0.25u)` arching up and out, outer edge narrowing toward the top (0.80 to 0.66), bottom edge dropping from -0.28 at the root to -0.94 at the outer tip, scalloped by the flight feathers' rounded tips. Feathers sculpted: covert rows (0.135 wide, rows 0.090) over the top 0.30, flight feathers 0.115 wide below, overlapping sideways; ivory with soft grey creases, warm gold in the covert band, a soft glow so they stay ivory in the cave light. Taken from the reference: the silhouette and the covert-over-flight-feather layering. Not taken: its exact feather count, the light glints. First passes: narrow flight feathers and dark creases read as grey stripes; small coverts read as fish scales; wings too swept back; all corrected.
- **Smile taller:** the reference smile's opening 0.066 to 0.092, carve 0.026.

**Verified:** full 24-frame turntable, face and belly close-ups inspected at front, three-quarter, side, back and close-up; published to <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM>. **Unresolved:** owner verdict; wing size against the halo and antennae in game; the transformed form (more insect-like) after the base is agreed; Blender build.

## History - base form round 10, the owner's picks and sculpted body options, 2026-11-14

**Owner, on the gallery:** "for the [eye], actually liked Healing Mint the most"; "for the bodies, I'll be honest, I didn't like any of them. They're all just trash"; "For the mouth, the reference smile"; "for the bellies, I liked the inner light one, or the rising light one, they were both nice"; "the main issue is the body ... none of the things you done were nice. They all felt just either just plain or random or just slapped on for the sake of it. Or just didn't blend in nice ... Didn't fit the theme of the slug nice. Just putting golden lines for no reason." **Confirmed (owner):** Healing mint eye (`EYEV 2`); the reference smile (`MOUTHV 0`); belly Inner light or Rising light. **Rejected:** all six painted bodies (folded-wing drawing, gold filigree, pearl sheen, veins of light, ivory mantle, glowing hem); their code is removed.

- **Locked picks:** `BASESEL` in the build script (e2, m0); the page now shows only Body and Belly rows.
- **Bellies:** Inner light (default), Rising light, and Both (`BELLYV 7`).
- **Bodies, all sculpted with colour following the shape (celadon root to ivory edge):** **Lotus base** (`lotus`: two rings of seven broad cupped petals round the base, outer at radius 0.64 leaning 0.95 rad, inner at 0.52 leaning 0.42); **Feathered back** (`featherBack`: overlapping feathers 0.21 wide in rows of 0.13 sculpted 0.016 down the back from y 0.26 to 2.0); **Folded wing-fins** (`wingFin`: three broad overlapping feather blades per side lying against the upper back from the shoulder (0.24, 1.46, -0.32)); **Ribbon fin** (`ribbon`: a thin fin up to 0.26 off the middle of the back from the crown to the tail, rippling, glowing at the edge); **Inner glow** (light through thin skin, measured by the body's thickness 0.14 inward); **Petal capelet** (`capelet`: seven broad petals hanging from the neck over the shoulders and back). The body masses are now `bodyMass`, so options can follow the surface. First passes: thin spiky lotus petals read as a crown of flames; single tusk-like wing-fins; a narrow ruff of petals (jester collar); a fin too low to see; all broadened.

**Verified:** each option rendered alone (54 frames) and inspected at three-quarter, back and side; published as a new private artifact, <https://claude.ai/artifact/PYsi3ex2cg833T8wTQpnuM> (1.1 MB; the earlier link belonged to the previous signed-in account and no longer opens). **Unresolved:** the owner's body and belly picks. Lotus and folded wing-fins read best; the feathered back still reads partly as scales (the comic ink catches each feather's edge); ribbon fin and inner glow are subtle.

## History - base form round 9, a bigger mouth and an options gallery, 2026-11-14

**Owner, on round 8:** "it's better now. Let's make the mouth bigger. And I like the eyelid design thingy done"; then "generate multiple different body designs, multiple different eye designs ... quite a few ... All that would make the angel look more healing, angelic, and just nicer ... if you think there's better mouth designs or teeth designs ... I'll check those out as well. Also do like different belly designs." **Confirmed (owner):** the crossover head is better; the gilded lid.

- **Mouth bigger:** the reference smile's half-width 0.235 to 0.285, opening 0.056 to 0.066, corner lift 0.022 to 0.026.
- **Options gallery:** shader switches `BODYV`, `EYEV`, `MOUTHV`, `BELLYV` (0 = the current design); page rows of option buttons; each option rendered on its own against the current design (front, three-quarter, side, back, face close-up and a new belly close-up; keys `b{body}e{eye}m{mouth}y{belly}`); Live 3D draws any combination of picks. Options: **eyes** Radiant (current), Dawn, Healing mint, Liquid gold, Starlight, Rising light, Pearl, Stained glass; **bodies** Plain (current), Folded wings, Gold filigree, Pearl sheen, Veins of light, Ivory mantle, Glowing hem; **mouths** Reference smile (current), Serene, Open with tongue, Lopsided, Top-teeth grin; **bellies** Gold-edged (current), Inner light, Gold heart, Feather scales, Gold stole, Rising light, Plain ivory. Tuned before publishing: Dawn rosier; Healing mint's mint band widened; Starlight's stars bigger; Stained glass's round centre pane removed (read as a pupil); Folded wings enlarged to the shoulders; Pearl sheen strengthened (still subtle); Feather scales given more contrast; the heart enlarged.

**Verified:** 24 option renders (144 frames) inspected in contact sheets per group; published as the options version of the private artifact (2.8 MB). Live 3D combinations not rendered offline. **Unresolved:** the owner's picks; Pearl sheen may be too subtle to judge; transformed form after the base is agreed.

## History - base form round 8, an Inferno-Aquabeek crossover head and a gilded lid, 2026-11-14

**Owner, on round 7:** "the head is fully fucked now. Make it look more like Inferno's ... like a crossover between Inferno and [Aquabeek]"; "I don't like the thing you put on top of the eye. I don't know what you can do, but you gotta do something."

- **Head and body, a crossover:** every mass the average of Inferno's (`evidence/inferno/inferno.html`) and Aquabeek's (committed `aquabeek_concept/template.html`): base (0.57, 0.30, 0.58); body (0.45, 0.70, 0.42) at (0, 0.80, 0.01); neck (0.49, 0.47, 0.44) at (0, 1.22, 0.02); flare (0.71, 0.06, 0.70); head (0.67, 0.42, 0.56) at (0, 1.68, 0.04), blend 0.20; crown (0.53, 0.38, 0.48) at (0, 1.83, -0.02), blend 0.21; muzzle (0.48, 0.30, 0.39) at (0, 1.39, 0.19), blend 0.30. The Round, Tall egg and Broad brow heads, the robe-wide body and the widened lower head are history. Eye at (0, 1.66, 0.58), mouth at y 1.255, belly top 0.96, antennae roots (0.38, 1.94), halo at y 2.58.
- **Over the eye, a gilded lid:** the gold arch removed. The rolled upper lid is gold, 0.085 wide at the top tapering to 0.012 at the corners, lighter along its roll, with a fine ink line; lid relief 0.020 at the top, `LID_W` 0.054, `LIDK` 0.84. It reads as a gold rim on the eye, subtle at game distance.

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 8 of the private artifact. **Unresolved:** owner verdict on the head and the gilded lid; transformed form after the base is agreed.

## History - base form round 7, the reference smile and a gold arch over the eye, 2026-11-14

**Owner, on round 6:** supplied a small drawn reference of a cartoon smile (not stored: a nearly straight upper line with a slight central dip, a curved lower line, one solid white shape with grey shading under the top and at the corners, a bold outline, a flick at one corner, a short line under the lower lip): "Let's do smile like this, just a bit wider ... a bit more calm"; the head "needs to go out wider a bit ... Not at the tip top though, like maybe lower down"; "for the eye, we need to do something on top of the eye, not on the sides. And maybe open the eye up a bit more." No head was picked from the three; Round was taken as the base (Tall egg and Broad brow stay in the template behind `HEADV` as history; the page shows one form).

- **Mouth:** half-width 0.235 at y 1.31; upper line `0.022 u^2` with a 0.004 central dip; lower line 0.056 below at the centre, meeting it in points (calmer than the reference's depth); set 0.022 into the face; one solid white shape with a light grey band under the top (0.35) and toward the corners (0.45); ink outline heavier on top, a flick at his right corner, a short line under the lower lip. Lip rolls, cheek and chin relief removed. A first, heavier grey band read as gritted teeth.
- **Head wider lower down:** an extra mass (0.72, 0.36, 0.50) at (0, 1.46, -0.04), set back so the face does not push forward.
- **Eye opened up:** `LIDK` 0.74 to 0.86, `ETOP` 0.255 to 0.270.
- **Over the eye (`arch`):** a gold band over the top of the eye only, from corner to corner, 0.022 above the eye's arch, rising 0.040 to a soft point above the middle, 0.012 thick at the corners to 0.046 at the top, raised 0.006, ink edges. A first, thinner chevron read as a raised eyebrow.

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 7 of the private artifact. **Unresolved:** owner verdict; transformed form after the base is agreed.

## History - base form round 6, three heads and a calmer mouth, 2026-11-14

**Owner, on round 5:** "remove the wings on the eyes. I don't like them. Everything else is almost good. I still don't really like the head shape that much. Or maybe some mouth. Mouth just looks goofy ... with his cheeks, chubby ... cheeks." **Confirmed (owner):** everything else "almost good" (the eye of pure light, halo, sparkles, floppy antennae, gold-edged belly, colours).

- **No design round the eye:** the winged sun is removed; the face round the eye is plain. Four treatments have now been rejected there (mandorla and rays, ivory band, diamonds, wings).
- **Mouth:** a small, symmetric, closed smile: half-width 0.235 to 0.180, `MA` 0.55 to 0.85, `MB` 0.30 to 0; lips thinner (upper 0.018 to 0.012, lower 0.030 to 0.018, relief 0.0075/0.011 to 0.0055/0.0065); cheek lifts and dimples removed; short level corner tucks.
- **No muzzle:** the ellipsoid under the eye pushed out the chubby cheeks; removed from every head.
- **Three heads (`HEADV`, page buttons, forms `base0` to `base2`):** **Round** (head (0.66, 0.54, 0.56) at 1.70, crown (0.48, 0.38, 0.45) at 1.94; the last round's dome); **Tall egg** (head (0.62, 0.58, 0.55) at 1.74, crown (0.44, 0.46, 0.43) at 2.02, antennae raised 0.12, halo at 2.76); **Broad brow** (head (0.70, 0.46, 0.56) at 1.76 with a softer 0.28 blend, crown (0.56, 0.30, 0.46) at 1.96). Offered side by side after the head missed twice, per the lesson index.

**Verified:** full 24-frame turntables of all three heads and face close-ups, inspected at front, three-quarter, back and close-up; published as version 6 of the private artifact. **Unresolved:** the owner's head pick; whether the plainer face needs anything round the eye; transformed form after the base is agreed.

## History - base form round 5, a winged eye, 2026-11-14

**Owner, on round 4:** "Make the antennas flop back more"; the belly: "I don't mind the shape, but I just didn't like the lines. So probably bring back the old like normal shape and then keep the gold outline on it. I like that"; the eye "is nice, but I don't really like the eyelash gold outline thing. Around it, do something different. And then I don't like the two little diamonds as well. And make the eye ... a bit bigger." **Confirmed (owner):** the eye of pure light; the gold outline on the belly.

- **Eye bigger:** `EW` 0.340 to 0.375, `ETOP` 0.228 to 0.255, `EBOT` 0.160 to 0.178; gleam moved with it.
- **Round the eye, a winged sun (`faceGlory`):** the mandorla, its rays (read as lashes) and both diamonds removed. From each corner, three broad gold feathers (`feather`: a Bezier blade about a quarter as wide as long, pointed tip, darker shaft and edge, ink outline) fan up and out, top one longest (to about (0.235, 0.200) past the corner before scaling), under a rounded gold covert at the corner; drawn at a fixed size and scaled up by `WS` 0.80. A first pass of thin horizontal feathers read as cat whiskers; a pale covert read as a bow.
- **Antennae flop back:** root (0.36, 1.98, -0.06), through (0.48, 2.36, -0.24) to (0.57, 2.38, -0.62).
- **Belly:** back to the round-2/3 shape (angle round the body, a soft U top at y 1.00), smooth ivory with no rolls or seams, the fine gold line inside its edge kept; no diamond.

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 5 of the private artifact. **Unresolved:** owner verdict on the winged eye; from the front the flopping antennae show as short stubs; transformed form after the base is agreed.

## History - base form round 4, an eye of pure light, 2026-11-14

**Owner, on round 3:** "I don't want it to look like an eye ... it still has a pupil and the white outside. I want it to just be like a design ... the way [Burpy] has eyes, [Rammstone] has eyes ... It's a pure fire eye or pure molten rock eye. This should be the same ... I love the design you've done, but it still looks like a human eye. Which is very uncanny and off-putting." Also: "I don't like the belly design. And I don't like the glowing streak that's just going across the bottom"; "the head shape is weird ... The brother [read as brow] looks goofy"; antennae "spread further apart ... more like on the edges of the head"; "the halo can move down a bit." **Confirmed (owner):** an elemental eye with no eye anatomy.

- **Eye:** after Inferno's fire eye (`build_inferno.py` `eye_colour`: one radial gradient, faint rays): one gradient over the eye's own shape from a white-gold heart (1.00, 0.98, 0.90) through gold (1.00, 0.84, 0.46) and rich gold (0.92, 0.56, 0.14) to deep amber (0.46, 0.20, 0.03) at the rim, fourteen faint rays turning slowly, a four-point gleam at (-0.105, 0.040), glow strongest at the heart. The ring, studs, pupil star and white core are history.
- **Lid lighter, no crease** (read as the "brow"): `LIDK` 0.66 to 0.74, lid relief 0.010-0.030 to 0.006-0.016.
- **Head:** a rounder dome a little wider than the neck: head (0.66, 0.54, 0.56) at y 1.70, crown (0.48, 0.38, 0.45) at 1.94, neck 0.55 wide.
- **Antennae:** roots out toward the edges (x 0.36), rising nearly upright to (0.60, 2.60, -0.28). Halo lowered to y 2.64.
- **Belly:** the rolls, seams, trim and breath of light removed; now a tall pointed almond of ivory light (mandorla, `BEL_W` 0.34 half-width along the surface, y 0.04 to 1.06, width `sin(pi t^0.85)`), glowing faintly from within, a fine gold line inside its edge, a diamond of light above its top point. Bounded by height too: without it a pale sliver ran up the middle of the head.
- **Gold hem line removed.**

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 4 of the private artifact. **Unresolved:** owner verdict; whether "brother" meant the lid; transformed form (more insect-like) after the base is agreed.

## History - base form round 3, a pupil-less gold eye in a gilded sunburst, 2026-11-14

**Owner, on round 2:** "Increase the length of the antennas a bit. I like the halo idea a lot"; "I don't like it having the pupil"; "we need to adjust the head size to match [the one eye], otherwise it just looks like the slug has a really fat head. And we need to do some type of design for the empty space around it so it doesn't just look empty ... I like the halo and the sparkles"; "some sort of glowing gold and white design. Because it goes really nice with the green of the skin, like an ivory gold type of thing." **Confirmed (owner):** the halo and the sparkles; gold and ivory with the celadon skin.

- **Eye:** no pupil and no mint iris. Ivory light (1.00, 0.93, 0.76) warming to gold at the corners; the gold ring (darker gold band with ink-brown edges, four diamond studs) round a radiant core, white at the heart and pale gold toward the ring, with sixteen fine gold rays, alternately long (0.146) and short (0.110); a four-point star of light (arm 0.064) at the centre. A first pass with a near-white surround and strong glow read as a blank white blob at game distance; the warmer surround, darker ring edges and less glow fixed it.
- **Round the eye (`faceGlory`):** crisp gilding, not a glow: a mandorla line (almond `EW` + 0.075, `ETOP` + 0.070, `EBOT` + 0.050), nine rays fanning up from it across the forehead (alternately 0.150 and 0.085 long, scaled up toward the top, tapering from 0.012 wide), a diamond of light above the rays and a small one below the eye. A first pass with an ivory band inside the mandorla read as goggles and was removed.
- **Head sized to the eye:** head radii (0.72, 0.52, 0.57) to (0.63, 0.50, 0.55), crown (0.54, 0.36, 0.47) to (0.47, 0.34, 0.45) at y 1.88, neck 0.60 to 0.57 wide, muzzle 0.50 to 0.46.
- **Antennae:** longer than round 2, shorter than round 1: tip (0.47, 2.60, -0.34) from root (0.22, 2.00). Halo raised to y 2.80, radius 0.36, to clear them.

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 3 of the private artifact. **Unresolved:** owner verdict; the transformed form (more insect-like) after the base is agreed.

## History - base form round 2, a healing angel, 2026-11-14

**Owner, on round 1:** "The base design looks way too similar to the normal Boondock ... It also looks way too basic. Emphasize the healing aspect more. I don't really like the spots on the back. The single eye is obviously good. We should keep that. But the eye itself just looks a bit weird ... we should do something similar to like Inferno and Ramstone, where we did like a cool design that is unique to it. So maybe do something like healing eyes ... It should almost look divine ... The antennas are also quite long ... Do shorter antennas ... it should just look like a healing angel almost. I'm not saying give it wings." The transformed form was "really bad. It looks like a fish. It looks like Aquabeak", and should look "more insect almost" like the franchise transformed form, but "first let's forget about the transform dilemma ... let's just get this form first". **Confirmed (owner):** keep the single eye. **Set aside:** the transformed form; the page shows the base form only (`COMET = None` in the build script).

**Research (web, 2026-11-14):** searches for divine and angelic eye designs found mostly low-quality pages; the recurring motifs were concentric rings round an eye (the "wheels within wheels" angel), radiant sunburst irises, four-point star sparkles, halos, and pale gold with deep greens ([pixie.haus](https://pixie.haus/pixelart/525044/cosmic-ophanim-many-eyes-watchful-presence), [aesdes.org](https://www.aesdes.org/?p=75811), [Thrivent art collection](https://artcollection.thrivent.com/exhibitions/angels-and-divine-light), [Ksenia Odintsova](https://kseniaodintsova.com/blogs/tales/all-seeing-eyes-in-slavic-pagan-symbolism-and-modern-drawings)).

- **Eye (divine):** no white; the eye is soft light, ivory warming to gold at the corners. A solid gold ring (radius 0.150 to 0.172 in pattern units, scaled `IS` 0.9375 to the eye) with four diamond studs of light, turning slowly; the iris deep teal under the lid to healing mint with twelve tapering sunburst rays; a deep pupil (0.058) with a mint rim and a four-point star of light caught in it. Shape: a more pointed almond (exponents 0.62 upper, 0.85 lower) whose ends lift (`eyeMid` 0.030 u^4), `EW` 0.340, `ETOP` 0.228, `EBOT` 0.160, lid `LIDK` 0.66. Tried and dropped this round: a notched dial ring (read as a clock face) and a dashed inner ring (crossed the rays into a ship's wheel). The pale look was the skin's wet sheen and the surround's glow spreading over the iris and pupil; both are now masked to their own parts (`gEye`).
- **Halo:** a flat gold band (radius 0.38, half-width 0.058, half-thickness 0.022) at (0, 2.68, -0.12), tilted 0.36 rad toward the viewer, glowing and bobbing.
- **Body:** fuller and lower than the reference's tall bean: body (0.54, 0.68, 0.48) at y 0.76, neck (0.60, 0.46, 0.50) at 1.24, head (0.72, 0.52, 0.57) at 1.68, crown at 1.90, mouth at 1.30. The pooled base spreads wider (0.78) in seven soft robe-like folds with a gold hem line.
- **Antennae:** short (tip at (0.46, 2.46, -0.30)), gold tips.
- **Colour:** celadon (#6FB89A) deepening to teal (#2C6E6A) down the back and over the crown; ivory belly (#F2EEDD) with a gold trim inside its edge and gold-glowing seams with a slow breath of light; gold (#F4C96A) is the divine light, mint the healing light. Back spots removed.
- **Healing light:** seven small four-point gold sparkles drifting up round him.

**Verified:** full 24-frame turntable and face close-up inspected at front, three-quarter, side, back and close-up; published as version 2 of the private artifact. **Unresolved:** owner verdict; whether the turquoise still reads too close to the reference's green; whether the plain back is now too plain; the transformed form (owner direction: more insect-like, echoing the base form).

## History - round 1, 2026-11-14

Superseded by round 2 above: the jade colours, normal eye, tall antennae, back spots and the axolotl-wyrm transformed form below are history.

## Implemented - base and transformed concept, round 1, awaiting owner review, 2026-11-14

**Owner request:** "Make a boon.slug design based on everything we've learned ... inspired of the images I sent ... Do the base and transform version ... it needs to be inspired, not exactly the same. You can change some colors or change the design." The owner supplied a screenshot of image-search results for the franchise healing slug: a mint-green, tall, one-eyed slug with long upright antennae, a pale and a white variant with a belly swirl, and a green frog-like transformed form with frond tendrils, a toothy grin and claws. It is study material with no reuse rights and is not stored here.

One design, both forms, as a signed-distance concept page built by [`build_boon_doc_concept.py`](../../../tools/slugs/build_boon_doc_concept.py) from its own [template](../../../tools/slugs/boon_doc_concept/template.html) (`XF 0` base, `XF 1` transformed, sharing the eye code so the identity carries over). Page and turntables: [evidence/boon-doc](evidence/boon-doc/boon-doc.html); private artifact <https://claude.ai/artifact/XsUKTkE5tfSroQiF1JB19m>.

**Idea:** the healer retold through the axolotl, the animal that regrows lost limbs. Palette: deep jade body (`BODYC` #3D9C68), deeper jade back, pale seafoam belly, mint healing light (`GLOWC` #7CFFD2) on the eye, antenna tips, belly seams and back spots, so every glow is one colour (the Tazerling round-13 lesson).

- **Base body:** Inferno's plan, lean 0.10 (calmer); body (0.48, 0.72, 0.44) at y 0.82, a thick neck (0.58, 0.48, 0.48) at y 1.32, head (0.70, 0.52, 0.56) at y 1.78, crown (0.52, 0.36, 0.46) at y 2.00, muzzle (0.48, 0.27, 0.40); short plain rounded tail. A first, narrower neck (0.50) under the widened head read as a light bulb and was thickened.
- **Eye:** one centred almond, Aquabeek's method (surface follows the head, dome 0.026, rolled lid, crease, nothing bulging): `EW` 0.320, `ETOP` 0.215, `EBOT` 0.150, heavy lid at `LIDK` 0.66 for a calm, kind look; ink line on the lid. Iris radius 0.150 on the eye's own surface, deep jade under the lid to glowing mint below, streaks spiralling in, a lighter ring, pupil 0.056, two highlights. A first eye at `EW` 0.265 read too small for a one-eyed face.
- **Mouth:** a closed, carved resting smile (half-width 0.235 at y 1.40; corners lifted `MA` 0.55, his right `MB` 0.30), lips just meeting, cut 0.09 under the skin, dimpled corners; no lip tint.
- **Antennae:** tall, soft, jade Beziers from (0.22, 2.14, -0.04) to (0.48, 3.04, -0.34), radius 0.100 to 0.042, flattened 1.35 front to back; the last stretch glows mint, no bulb.
- **Belly:** pale seafoam measured round the body, top at y 1.08, four soft rolls (bulge 0.010) whose three seams (groove 0.012) glow mint with a lub-dub heartbeat climbing them.
- **Back:** five soft glowing mint spots a side in a staggered pattern; a first 16-spot grid read as polka dots.
- **Transformed, an axolotl wyrm:** a broad, flat head (skull (0.64, 0.35, 0.62), snout (0.54, 0.24, 0.36), brow mound) with the same eye on the sloping forehead (axis (0, 0.5, 1)) and a wide closed smile running round the snout and back along the sides, its ends curling up; three pairs of gill fronds (his antennae grown) from the back corners of the head, flat blades (squashed 4x) widest a third along with a scalloped feathery edge, jade to glowing mint tips, swaying; a body head-wide at the join (half-width 0.465) tapering over 2.75 to a tail flattened side to side, with a swimming wave; one glassy mint fin low down the back, deepening over the tail, round a paddle tip and along the underside; healing spots continue down the back. First fronds combed all round a round tube read as spiky caterpillar pods; flattening them fixed it.
- **Kept familiar:** green, one big eye, tall antennae, pale belly, a frog-like transformed form with fronds. **Avoided:** the smug open grin, the light mint colour, the belly swirl, the transformed form's teeth, claws, arms and spiky tendrils.

**Verified:** full 24-frame turntables of both forms plus face close-ups and a top view of the transformed form, inspected at front, three-quarter, side, back and close-up; a faint seam under the eye (the mouth's sculpting window ending while its cheek lift was still non-zero) found and fixed. **Unresolved:** owner verdict on both forms; whether one eye is too close to the reference (name/IP check); whether the frond fringe reads as feathery or serrated in game; the heartbeat's speed; Blender build and Roblox look.

## Confirmed - Mending Shot and Healing Spring, 2026-11-05

**Owner:** "you can shoot your teammate to heal them, or you can shoot at an opponent to heal yourself", combining two proposals into one main. The passive stays healing-based: "I prefer the healing spring just because it's it's a bit more different since it's a spring rather than a individual-based thing", with "the healing capabilities of the passive version lower".

- **Main - Mending Shot:** hit a teammate to heal them; hit an enemy to heal yourself. Like every main it also damages an enemy it hits; that part is the assistant's assumption, carried from Leech.
- **Passive - Healing Spring:** a pool on or below the surface hit. You and your teammates heal while standing in it, less strongly than the main.

Mending Shot and Healing Spring are the assistant's names, kept unless the owner changes them.

**Confirmed, 2026-11-05:** Mending Shot clears burns and binds, so it answers Snapbind, Dragon's Breath and Fire Curtain.

**Unresolved:** numbers; final forms; native implementation.

## History

**Not selected, 2026-11-05:** Leech as a separate main (merged in) and Health Pod. Proposed from the [ability playbook](../ability-playbook.md); kept in `tools/slugs/ability-lab/boon-studies.js`.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers the teammate heal, the self-heal from an enemy hit, cover and dodging, and the spring on floor, wall and ceiling. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

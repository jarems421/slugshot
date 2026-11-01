# Owner design language and working lessons

Read this before any creature, blaster or animation task. It translates how the owner phrases feedback into what actually satisfied them in recorded rounds, so the next slug starts from what was learned on Floppy instead of rediscovering it. Each entry cites a recorded round; it is a starting interpretation, not a rule. When a phrase is ambiguous for the task in hand, show one option and ask.

Sources: [Floppy catalogue entry](catalog/flopper-inspired.md), [Blender lessons](blender-lessons.md), [blaster refinement](blaster-refinement.md), [chamber repair](floppy-chamber-repair.md), and the 2026-10-31 draw/holster session (code on `experiment/rocklock-unified`, notes in that branch's `docs/memory.md`).

## How the owner works

- **Fast, visual, iterative.** Feedback comes in short rounds, usually with Studio screenshots or reference photos. Treat a screenshot as precise evidence of the problem (where, how big, which way) and a reference photo as the target geometry. Ask for a screenshot when a report is ambiguous, rather than guessing twice.
- **Agree the design as a live 3D concept before Blender.** On Floppy, repeated scripted passes on a lofted profile passed every check and were still rejected ("just looks horrible"). A rotatable real-time concept page, agreed first and then rebuilt in Blender from the same maths, ended that cycle. Do this for every new slug.
- **Show the views that matter.** Shape and slope feedback needs front **and side**; sloped or angled parts need a side profile; anything seen in game needs the third-person view from behind and above.
- **One change per round, small steps.** The owner tunes by feel ("a tad", "a little bit", "a bit further up"). Change one thing by a modest amount, keep the previous version available, and state the number changed so it can be nudged again.
- **He tests in Studio himself.** One clean Studio window with the current build is expected; close old ones first. Opening many windows has hit Studio's window limit and low-resource prompts.
- **Accepted means stop.** "Perfect", "that's the Floppy design", "it's all good now" are approvals: preserve that state as the baseline and change only what is asked next.
- **"Perfect" is often followed by "only thing is…" or "last little change".** In the Floppy concept chat, "perfect", "genuinely almost perfect" and "basically perfect" each came with one or two small tweaks in the same message. Treat it as "keep everything, apply just these". "Save this… delete the previous ones… this is our Floppy" meant: lock it, rename it, remove older drafts, then continue.
- **Options only when he asks "what should we do instead?" or "what do you think?".** He picked from three belly options when he asked. When he asked "what do you think?" about shrink-on-load, he wanted my honest opinion and then the change made. Otherwise he expects one direct fix.
- **He interjects mid-task.** Corrections arrive while work is running ("And no, I want a short tail still"). Fold them in before showing results.
- **He passes on outside critiques.** He pasted a third-party critique (anatomy reads as a "melted candle", face too flat, appendages like "handles", muddy markings, disconnected mouth/drool) and expected each point addressed, plus his own additions.
- **He asks me to research when a problem keeps recurring** ("do research on how to make these type of things look squishy"). In this chat the search results were thin (paid soft-body add-ons, eyelid-shell advice); being honest about that was fine.
- **Studio handoff rule (Confirmed, restated in this chat):** "whenever you add something to Studio… close the old Studio tabs and open a new one for me to test." Leave unrelated windows (e.g. Rocklock) open.
- **"Open it in Blender so I can see it."** He reviews in his own Blender as well as in renders; load the current file into his live session after each build.

## Voice-dictation slips (this chat)

He dictates; read for sound, not spelling. Seen: "drawl"/"Drew" = drool, "spider animation" = spiral animation, "glue" = glow, "class" = glass, "doc under eyes" = dark under-eyes, "slime fits inside the shell" = slug, "slug terror" = Slugterra, "floppy" = the slug's name (not a description), "Veilume"/"volume" = Veylume (the exploration world), "jewel board" = duel board, "Cosmic Cavern"/"Living Cosmic" = Comic Cavern/Living Comic, "Badlands"/"Badland" = Borderlands (the comic-ink art style; see [style guide](../art/style-guide.md)). Ask only if the sound-alike is still ambiguous.

## What phrases have meant

| The owner says | What satisfied it (recorded) | What failed or was rejected |
| --- | --- | --- |
| "too hard", "not squishy", "looks solid" | Shape first: belly sag, neck roll, soft spread ground contact, rolls of skin. Motion squash/wobble big enough to read (10–20%). | 2–3% motion and Blender scattering/sheen: invisible in the viewport and not carried to Roblox. |
| "looks stuck on", "glued on" (eyes, antennae, features) | Features sunk into the body: recessed sockets, lid shells slightly larger than the eye that sink into the skin rim, antenna roots flaring from inside the head. | Flat discs or stickers on a curved surface; flat lid slabs; narrow appendage roots. |
| "dark/muddy spots", "darker markings" | Darker, muted, earthy marks: first muted olive (linear `0.16, 0.34, 0.075`), finally moss-brown `#6A6B45` back markings as five soft rounded lozenges shrinking toward the tail. | Bright or vibrant greens; painted brown stripes; freckles (turned off). |
| "too white", "wrong colour", "way too blue" | Colour **sampled from the reference image** he supplied, judged in neutral light; then shifted the way he names (green/brown). | Guessed colours (warm off-white, dirty yellow) were rejected. Don't guess; sample, then adjust. |
| "more depth" (colour), "too pale" | Baked ambient occlusion in folds, lids and creases, a slightly richer/deeper grade, less scattering and sheen. | Simply darkening everything. |
| "more depth" (shape), "flat from the side" | A rounded forward forehead, deeper cheeks and crown, checked in side view. | Front-only reviews. |
| "too long" (tail), "no feet" | A very short, low, soft triangular continuation of the body. | Separate tails, nubs, foot lobes. |
| "flop heap" (dictation) | Floppy. | — |
| "bulbs… slightly luminous… a little glow" (2026-11-01) | Antenna bulbs keep their moss-brown colour and add a soft yellow-green emission (`0.62, 0.80, 0.28`), meant to show where a slug is in a dark cavern. | Pending owner review. |
| "greenish brownish spores… diffused spots… medium-sized… just on the plain body" (2026-11-01) | Sixteen soft spots (radius about 0.11 to 0.16 concept units, solid half-core with a fading edge) in `#7C7D4C`, placed on the surface away from the belly, its outline, the back marks, eyes, mouth and antennae. | Smaller spots with a tighter core read as dots; the first even spots were "not noticeable" (owner could not see them at all). |
| "supposed to make the floppy look more sick… sickly… diffused spores slash spots… that blend in a bit" (2026-11-01) | Pending: 22 irregular blotches (each a primary plus one or two satellites), dark olive-brown core `0.115, 0.105, 0.035` inside a yellowed halo `0.47, 0.46, 0.15` that fades into the skin; also placed where the front three-quarter view sees them (cheeks, head). | Even, single-tone spots mostly on the back and sides. |
| "looks more dirty than sick… the color mainly" (2026-11-01) | Pending: inverted value. Sick reads as sallow pallor, a thin bruised rim and a **lighter**, wet, bilious yellow-green centre with a faint glow; dark brown blotches read as grime. Research basis: sick palettes lean to bilious yellow-green and bruise accents with desaturated pallor, while dirty palettes are browns, greys and grime in recesses; sores read best as a lighter or saturated accent against the body. No spot on the face above the mouth. | Dark olive-brown cores ("dirty"). |
| "dispose [the spots] feel out of place… match the color of the top eyelids… keep the glowing thing" (2026-11-01) | Sore centres in the upper-lid sage `0.250, 0.280, 0.140`, kept glowing (lit centre inside a thin bruised rim and sallow halo, plus emission in their own colour). Owner then: "I like this design a lot" and asked for it in Roblox. | Bilious yellow-green centres ("out of place"). |
| "because of the glue [glow], this still will look a lot lighter than the eyelid… fix that while still remaining with the light glow" (2026-11-01) | Sore glow lowered from 0.45 to 0.15 of the mask (concept glow 0.9 to 0.3), so the centres read as the eyelid sage with a light glow. Dictation: "glue" = glow. | Glow strong enough to lift the sage well above the eyelid colour. |
| "the bulbs… right now they're not glowing… very dull… they need to glow… so slugs are more visible" (2026-11-01) | Roblox emission is surface colour x mask x strength, so dark moss bulbs stayed dull at full mask. Fix: luminous yellow-green bulb cores (`0.52, 0.68, 0.22`) plus a soft yellow-green PointLight on the head bone (range 5, brightness 0.9). Owner then made this the final Floppy design. | A stronger mask on dark bulbs; assuming the sore change had dimmed them (it had not). |
| "an extra glow on the skin next to… where the glowing light is hanging" | It was real: the glow mask used 3D distance from the bulb centre and reached the skin the bulb hangs beside. Glow now covers only the bulb sphere. | — |
| Blaster tips: "that slant just feels wrong… trying to be sharp but it's not… or it should be curved"; "the bottom part… should slant up"; "I don't like the corner"; "from the front… just a flat slab of orange" (2026-11-01) | Pending: tips rebuilt as smooth curves from the prongs' own cross-section (top down, bottom **up**, no corner), rounded points facing each other, and a groove or ridge on the sloped faces for the front view. This **replaces** the earlier "points slope down, never up" rule for the bottom prong. | Planar downward bevels with a hard corner (all earlier barrels, including steel claw tips); bevel faces with no detail from the front. |
| "pointy, sloping down" | Planar downward bevel cuts, firing gap preserved, judged from the side profile. | An outward/upward flare or bending the prongs: the wrong interpretation. |
| "too big" / "too tiny" / scale | He sets size by reacting to it in Studio. Floppy's sequence: 2.5 studs "way too big" → 0.22 "so tiny you can't even see it" → 1.0 → "reduce by about 33%… more so thin" plus "the base is just too wide" (narrowed base, 0.75) → "smallest they can be… a little bit taller, no thicker" (torso-only stretch, 0.83) → his own proposal: a little larger on the ground, shrink when loaded. Chat ended at 0.67 × 0.60 × 0.92 studs on the ground, scaled to fit the canister when loaded. Offer concrete sizes in studs. | Scaling other things to fit: shrinking the slug to the existing gun (invisible), or scaling the gun 3× to hold the slug ("ridiculously big"). |
| "too bouncy and squishy" (motion) | Wobble cut to about a third and slowed; head barely sways; antennae drift gently. | The idle wobble after he'd asked for "squishy": he wanted soft-looking, not jiggly. |
| "too solid… two D shapes on a 3D silhouette… you can't tell it's 3D from the front… belly not visible" (concept drawings) | A rotatable real-time 3D concept built from blended soft volumes (signed-distance smooth unions), with the lids, cheeks and antennae grown out of the skin and a belly bulge visible from the front. | Flat 2D front/side SVG drawings of four body plans: useful for picking a body (he chose C, "Slumped Sleeper") but rejected as the look. |
| "bulging out way too much, like bug eyes" / later "bulge out ever so slightly more" | Shallow lens-shaped eyes: depth 0.11 → 0.07 (accepted as calmer), later 0.07 → 0.085 with the soft blended rim kept ("I really like that"). | Domed eyeballs that stand proud of the face. |
| "eyes poking out from the bottom of the eyelids" | Add lower lids as well as heavy, half-closed, uneven upper lids. | Upper lids only. |
| "more crazy rather than drowsy, tired and drunk" (eyes) | Slower spin (≈0.5 rad/s, opposite directions) and thinner rings. | Fast spin (1.4/1.1 rad/s) and bold rings at that stage. |
| "rings… each eye different organization… the end would be connected" | Closed concentric rings, off-centre so the spin reads, a different set per eye, spinning opposite ways. Later "thicker, vary in thickness, one eye clearly bigger rings": the more open eye got three bold rings, the droopier eye four finer ones, every ring a different width. | The original spiral ("disconnected end"). |
| "spread them apart wider" / "spread them apart ever so slightly" (eyes) | x ±0.34 → ±0.37 (about 9%) was enough the second time. | — |
| "the mouth doesn't look like it's got life to it" (he clarified: not moving, expressive) / "drowsy and high off weed looking" / "tiny, slack, lopsided grin" (pasted critique) | A small slack lopsided grin, one side lifted, the rest hanging lazily. "Reaching into the eyelid" → shorten the raised side and lower the mouth slightly. | A thin downturned line; an exaggerated open mouth. |
| "drool" (see misreadings below) | A pale strand drawn on the skin, hanging from the bottom lip a tad in from the low corner, outlined by the same dark line as the mouth so lip and drool read as one shape, comic style. "A tad to the right" ≈ 0.02 units. | A separate blue 3D blob; a dark brown 3D drip; a raised strand with a "top bulb" that "pokes out". |
| "small dark patches under its eyes" → "looks like bruising" → "looks like shadowing, not eye bags" | A crescent of darker, slightly mauve-brown skin under each lower lid (linear `0.34, 0.22, 0.24`), following the eye's round outline, thickest in the middle and tapering at the corners. It fades up onto the lower lid and out into the skin with a Gaussian falloff, at about 0.31 × 0.21 units. | Purple/brown ovals (bruise); diffuse uneven patches (bruise); a faint grey ring (shadow); a geometric under-eye puff ("second bulge"); hard colour edges near the lid ("multiple layers"). |
| "looks like an eyebrow or something… looks weird" (above the eyes) | Smooth skin above the lids: remove the brow ridges. | Sculpted brow bumps. |
| "cheeks too chubby/puffed up" (said twice) | Cheek volumes shrunk twice, to a slight fullness only. | — |
| "head too wide and bulbous" / "top looks flat from the front" / "corners below the antennas too sunken… ruins the spherical shape" / "bring the top up a little more" | Narrower head; a taller crown dome; a wider crown volume filling the upper corners so the head reads as one round dome; then raised once more. | A flat-topped head with antennae roots pinching in the corners. |
| "antennas look angular" / "stuck to the head" / "handles attached to its head" (critique) / "up the head" / "forward onto the forehead… same distance apart" | Each antenna as one smooth tapering curve arcing out and flopping down to a soft bulb; roots moved up and then forward onto the forehead (twice), spacing unchanged. | Joined straight segments; thin hooks from the top of the head. |
| "chess piece rather than a slug sticking to the floor" → "rounded off" → "too flat, uniform, cleanly flared… cut off… a smooth bell" | A heavy lower mass that sags slightly forward and to one side, widest just above the floor, with a thin pooled edge spreading in soft uneven lobes ("I love the base"). Later "the base is too wide… that's what's making it look so big": narrower lobes, same character. | A wide flat plate (read as a candle holder); a thin flared sole (a smooth bell). |
| "subtle slime base" | Offered as a see-through slime film; then "remove the slime stuff for now… a little trail we add later" (Considering). | — |
| palette paste, then "way too blue… green/brown" | Warm sage body; later "more pale and yellow, closer to the belly but not too close" (`#BAC1A2`), then "a tiny tad darker… splash more yellowish brownish greenish" (`#B0B48A`). | His own first blue-green palette applied literally. |
| "upper eyelids too light… darker green… darker than the skin, lighter than the under-eye" (repeated across several rounds) | A green a shade darker than whatever the skin currently is: final `#888F68` against a `#B0B48A` body and `#5A5934` lower lids. Re-check after every body-colour change. | Taupe/lavender lids; a shade so close to the skin it vanished under light. |
| "muddy green, brownish green" (lower lids) | `#5A5934`. | Deep moss `#3E5234`, petrol teal. |
| "stripes on the antennas" → "scrap the stripes… colour the bulb at the tips" | Moss-brown tip bulbs. | Petrol-teal stripes along the antennae. |
| belly: "add stripes" → "too light, more prominent but blend" → "same colour thickness" → "brown outline… around the perimeter" → "brown outline ugly… brownish green" → "don't like the brown lines inside" → (options) "soft belly folds" → "less like creases, more like folds" | A warm stone belly (`#D8D3BE`) inside a soft muddy brown-green outline (`#6E6B3E`), with real geometric folds: full rolls of skin that bulge out and tuck under the roll below, slightly uneven, curving up at the sides. | Painted tan/brown stripes (uneven strength, then disliked); a brown outline; grooves that read as creases. |
| "remove all the green dots for now" | Freckles off; they clashed with the under-eye darkness. | — |
| "more shiny… slimy… not crazy shine… glossy" / "bottom half isn't as glossy" | Roughness ~0.22 on the skin and 0.08 on the eyes, then graded from 0.10 at the base up to 0.22 on the head. | Flat roughness (gloss only read on the top half). |
| "goofy", "basic" (poses) | A natural, relaxed pose: arm hanging slightly forward, gun angled down and ahead. | Set "style" poses (Gunslinger, Hero, Bladed). |
| "restrictive" (movement) | A light item leaves locomotion untouched: the arm swings exactly as an empty one while moving. | Partial hold weights layered over the run cycle. |
| "on the hip" (with reference photos) | Match the photo's shape: muzzle down, slightly canted forward, grip up and back, side facing out, riding the right leg, top near the hip joint. | Level "belt" placement, muzzle backward ("reversed"), tucked behind the arm ("floating"). |
| "don't shrink it" | Keep about 95% or more of full size. | 65–70%: "reduces by an obvious amount". |
| "a tad faster" | About 12% (accepted as "perfect"). | Speed that varies with input timing. |
| "consistent" | Same result regardless of how fast he clicks or moves. | Anything timing-dependent: spam speed-ups, state left over from interrupted actions. |
| "Slugterra-esque" (animation) | Original acrobatic gun flourish: a short toss and forward flip, quick but readable. | Copying a show's specific choreography (avoid); a backflip that reads as flipping downward from the third-person camera. |
| "acrobatic but not disruptive" | Short flourishes (~0.5 s) with no input locks, readable from behind while running, arm visibly carrying the motion. | A static arm with only the gun moving; flourishes hidden low in front of the hip. |

## Misreadings and how they were resolved (Floppy design chat, 2026-10-31)

| He said | I first took it as | What he meant, and how it became clear |
| --- | --- | --- |
| "they need to fit in the shooters" | Shrink the slug to the existing 2.2-stud blaster (0.22 studs). | Slugs must be visible first; the gun gets resized to them. Clear when he said "so tiny you can't even see it… we'll adjust the gun size accordingly". He later settled it himself: shrink when loaded. |
| "connected brown… like drool in comics… a black/brown silhouette that matches the mouth" | A solid dark-brown drip. | A pale strand whose **outline** continues the mouth line. Clear only from the anime reference image he sent; then "a continuation of the bottom lip… no top bulb". Ask for a reference image early for stylised features. |
| "the mouth… animated" | (He pre-empted this.) | Expressive, "full of life", not moving. |
| "rings… the end would be connected" | — | Closed concentric rings instead of a spiral; "connected" meant the spiral's loose end. |
| "the right eye… the big eye… has more space" | Ambiguous viewer vs character side. | I chose the more open eye (viewer's left, character's right) and said so; he moved on without objecting. *Uncertain* whether he meant that side; state the side explicitly next time. |
| "the glass should glow" / "brighten up inside the chamber" | A transparent neon tube, then neon trim plus interior lights. | The glass should read as the light source **and** the slug inside should be lit in his true colours, calmly, without tint, flicker or flare. Neon over the slug tinted him blue or pale; a white Highlight washed him out; tiny lights flickered and flared the orange prongs. A softened sage-coloured fill was the last state in this chat; the final fix was done later (see Blender lessons, "Lighting dropouts"). |
| "folds" (belly) | Grooves cut into the surface. | Bulging rolls that hang over the next one ("less like creases, more like folds"). |
| "dark under eyes" | Coloured patches. | Normal tired eye bags: darker skin under the lower lid following the eye outline, blended onto the lid. Took four rounds (bruise → bruise → shadow → layered edges). |
| "reduce its size by about 33%… thinner and shorter, more so thin" | An overall scale change. | Mostly the wide base: "this is mainly on the base… the base is just too wide". |

## How big "a bit" has been (this chat)

- "ever so slightly more bulge" ≈ +20% eye depth; "spread ever so slightly" ≈ +9% spacing; "tiny bit taller" ≈ +10% height (0.75 → 0.83 studs).
- "a tiny tad darker" = one small step in hue/value (`#BAC1A2` → `#B0B48A`); "a tad to the right" ≈ 0.02 source units.
- Shrinking the eye bags by ~13% each way was "way too much": go back about halfway when he says "shrunk it way too much".
- "increase it by like 70%… that isn't an exact number": fill the obvious empty space, not an exact percentage.

## Animation and Roblox runtime lessons (draw/holster, 2026-10-31)

| Problem and cause | Fix | Prevention |
| --- | --- | --- |
| Gun held out to the side after re-equips, flourish invisible: two scripts both wrote `RightGrip.C0`, and one captured the other's first draw frame as its rest pose. | The draw driver writes only `C1` (the tool's Grip side); the hold layer owns `C0`. | One owner per joint property. Never re-read a live joint value as "rest" while anything else may be animating it. |
| Arm stuck at a random angle after fast equip/unequip, varying with click timing: Presentation rescanned joints 0.1 s after parts were added and re-read live shoulder `C0` to build its conversion frames, baking in a mid-flourish tilt. | Joint frames are read once per joint and reused. | Same principle: capture rest values once. Use a diagnostic that reports which layer holds an offset (C0 vs Transform vs the system's own output) before guessing. |
| Same symptom, earlier partial cause: hold layers edited a reused clip-sample table in place, so per-frame multipliers accumulated. | Layers work on a per-frame copy of the pose. | Never mutate a shared scratch table that is only partly refreshed each frame. |
| Gun vanished from the hotbar after holstering: the hip copy was a stripped tool clone in the workspace with a part named `Handle`. Later, welding the copy to the character also blocked re-equipping. | Client-only copy under the camera, handle renamed, anchored (no welds). | Visual stand-ins must not resemble tools or join the character assembly. |
| Holstered copy trailed the body when running/jumping: it was positioned in the render step, a physics step behind. | Re-place it in `PostSimulation` from the part it follows (the right leg). | Attach visuals to the limb they belong to and update after animation/physics. |
| Flourish hidden while running: the run arm swing and the low hip position kept it out of the camera's view. | The arm lifts into the hold during the flourish; a moving variant raises the arm forward (not out) and tosses higher. | Review animation from the gameplay camera (behind and above, while running), not only standing. |
| No Studio MCP connection all session. | Studio log files (`%LOCALAPPDATA%\Roblox\logs`) carry Output, warnings and prints; targeted `warn` diagnostics plus one owner reproduction found every runtime bug. | When MCP is unavailable, instrument and read the log rather than iterating blind. |

## Combat and first person (2026-10-31, `experiment/rocklock-unified`, see its `docs/combat.md`)

| The owner says | What satisfied it (recorded) | What failed or was rejected |
| --- | --- | --- |
| "frictionless", "fast-paced", "easy to keep track of" (ammo) | Cooldown from firing (currently 1.5 s), shown on the ammo slot. **2026-11-01 confirmed design, Floppy implemented for review:** local recovery animation can finish independently; the slug burrows at its landing site. | A visible travel return that decides reload timing or races to meet the cooldown. |
| "hop back" (historical request, superseded 2026-11-01) | Earlier versions used quick returning hops, later retuned to 0.94 s. The owner has now approved **local burrow recovery** instead. [Current decision](recovery.md). | The owner rejected the timer-driven puff. Map-spanning recalls would be too hectic with many shooters. |
| Floppy "lands on its belly", "wriggles", "jumps up and burrows" | **Confirmed design; implemented for owner testing:** belly-first landing, brief wriggle, little upward hop and head-first dive/burrow at the landing site. Its exit should read as a creature action representing return to inventory. A native target-hit sequence passed; subjective timing and animation approval remain pending. | Renaming the puff, shrinking out of sight, or sprinting/recalling across the map to satisfy a timer. |
| "tiny bit of damage" | Weak, no knockback: 5 of 100 HP at first, raised to 7 on 2026-11-01 ("not completely useless"). | Knockback. |
| Tap vs hold | A tap still fires decently and (for later slugs) transforms; holding = faster, earlier transform, less drop. No failed transforms. | Requiring a charge to transform. |
| "temporary" (test spaces) | Label it everywhere: file name, banner, in-world sign. The map is a placeholder, never a source of truth. | Unlabelled test areas. |
| "Rivals-style first person", "not a setting" | Scroll in snaps to first person, scroll out snaps back. Settings (M) hold FOV and the holster choice. | A first-person toggle; extra option keys. |
| "one-handed" | A light pistol is held in one hand. | A two-handed hold ("very inconsistent"). |
| "feel the legs, not a floating camera" | Camera driven by the animated body (head motion), legs visible, gun reacting to that motion. | Added screen shake or a synthetic bob. |
| "feels like an aneurysm", "forced to look at the ground/sky" | Root cause was a camera feedback bug (additions compounding through Roblox's camera scripts), fixed by undoing them each frame. | Repeating the tilt every frame on top of the read-back camera. |
| "choppy", "crosshair flying around" (flips) | Spot: a brief directional bank that levels early, with aim steady. [Details](../combat.md#current-owner-decision-and-acceptance). | Following the head's full flip rotation as the default. |
| "arms look elongated" | Real animated arm motion on slimmer square first-person copies, reframed. Full wording history is in [combat notes](../combat.md#owner-language-contextual-interpretations-to-carry-forward). | Thin, long viewmodel arm blocks; rounded shoulders. |
| "almost perfect" (wall run), "fine" (slide) | 10 degree roll away from the wall, gun hand never grabs the wall on its side; slide lean and canted gun. | — |

Working style seen this session: the owner judges by playtest and reports in short rounds; research what successful games do before building ("do research", "what makes it feel good"), cite it, then implement; keep one option per thing ("concrete foundation"); confirm fixes from the Studio log (`%LOCALAPPDATA%\Roblox\logs`) when MCP is unavailable.

## Environment and art direction (2026-10-31 to 11-01)

From the lobby art-direction and asset-library rounds. Process lessons are in [art lessons](../art/lessons.md).

| The owner says | What satisfied it | What failed or was rejected |
| --- | --- | --- |
| "Badlands-esque finish", "outline everything so nothing goes unnoticed" | Borderlands-style dark ink outlines over real 3D lighting. | — |
| "vibrant like Slugterra, not neon", "calm and vibrant mix" | Calm dark stone base with selective glowing accents (about 70/20/10). | Saturated colour everywhere. |
| "something between Comic Cavern and Living Comic, closer to Comic Cavern" | Living Comic's *clean* surfaces with Comic Cavern's *thick near-black ink and deep shadows*, plus a crisp comic light-to-shadow edge ("you nailed it"). | A straight numeric blend of the two presets ("not there enough"). |
| "it looks better with Comic Cavern" (rocks) vs "glowy clear stuff needs Inked Cavern" | A per-material treatment rule; characters always Inked Cavern. | One treatment for everything. |
| "engulfs the design" | Heavy ink hiding small details; fix with light interior lines on details or flush painted/emissive detail. | Bold raised symbols. |
| "too basic", "plain" (rock wall) | Simple masses **plus** dressing: moss, broken cracks, small mushrooms, crystals poking out. | Bigger geometric changes (spires, ledges, alcoves, strata): "the worst one". |
| "the lines going through look weird" | Remove long carved lines across forms; keep cracks short and painted. | Horizontal strata grooves. |
| "V1 might have been the best because it was the most simple" | Roll back to the liked version and add only the listed items. | Iterating forward from a disliked version. |
| "hovering on the wall" | Dressing projected onto the real surface, roots sunk into the rock. | Hand-placed coordinates. |
| "more variations… we need a lot of variety" | A selectable bank (14 crystal designs, 14 mushroom colours); small props pick random colours from the bank. | — |
| "more unique and cool" (crystals) | Hand-built distinct silhouettes: geode, floating heart, crystal tree, spiral, split boulder, hanging cluster, urchin. | Parameter variations of one cluster. |
| "too much mushroom" | Stop adding a motif once it appears in several places. | Bark mushrooms on the giant mushroom (withdrawn). |
| "more attached to the ground" (big plant/fungus) | Roots spreading and diving into the floor, a mossy mound, small growth around the base. | A stem simply standing on the floor. |
| "something cool in the centre… dramatic and natural" | An opening above (Sky Well) and a swirling pit below (Maelstrom), with spawn on a floating rock. | Slug-themed centrepieces (canister tree, colossus, orrery, energy well) and biome features (crystal, mushroom). |
| "droopy" bridges | Sagging wooden suspension bridges. | — |
| "make it render upon being opened" | Load one asset at a time; offline-rendered turntables by default, live 3D opt-in. | One shader with every asset (froze Chrome). |
| "buggy, laggy" after a performance fix | Restore smoothness: more turntable frames on a canvas; live 3D back to its original settings. | Over-throttled live view and 16-frame CSS sprites. |

| "walls too dark and far", "glows don't light the wall" | Placed lights at the glows and over the walls. | Brighter blue ambient ("don't just make the rocks blue"). |
| "black voids" (mushrooms), "sparkles from nowhere" | Technical faults, not taste: inside-out mesh pieces and mirrored effect positions. | — |
| "the lighting keeps changing" | Studio's automatic graphics quality toggling shadows, plus too many lights and zone exposure changes. Fix the cause; also suggest Graphics Mode: Manual for judging. | — |
| "the rocks just look so basic" | Real carved cracks on a share of rocks, spread evenly; surface grain, worn edges, crevice hatching on all. | Squiggly painted cracks ("you just wiggled around"), deformed rocks, fossils ("mid"). |
| "Slugterra style cracks" | Straight segments with sharp alternating turns and one fork, wide at the rim tapering to a hairline, inked inside with a pale lip. | Smooth zigzag waves. |
| "every corner has something" | Six face regions, each with a crystal or mushroom cluster, plus tiny mushrooms; different per wall. | One hand layout repeated. |
| "it should be evenly random" | Pick per region, not per column with exclusions. | Rules that silently starve one area (top row never cracking). |
| "looks like a toy" (blaster) | Sharper, curved, purposeful shapes; detail on plain faces. | Planar bevels "trying to be sharp but it's not"; hard corners where a slope starts; a dip before the blade. |
| "more dirty than sick" | Lighter lit centres, bruised rim, sallow halo. | Dark brown blotches. |

More dictation slips: "roadblocks"/"roadblock studio" = Roblox/Roblox Studio, "flop heap" = Floppy, "glue" = glow, "dispose" = the spots, "Veilume"/"volume" = Veylume, "jewel board" = duel board, "Cosmic Cavern"/"Living Cosmic" = Comic Cavern/Living Comic, "slug terror" = Slugterra, "dimish map" = a map of merging biomes (exact word unclear).

**Working pattern in these rounds:** the owner critiques one asset at a time, praises with "perfect"/"beautiful" while adding one more tweak, interjects mid-task (the colour bank, then withdrawing bark mushrooms), and only offers options when stuck ("not sure what we could do"). When stuck, offer four or five clearly different directions with a recommendation. If all are rejected, ask what *kind* of thing (built, alive, natural, open) before offering more.

## Burrowing ground friction (2026-11-01)

**Confirmed contextual meaning:** "not enough friction" means the ground should visibly move while the creature digs, followed by dirt and rock piling up; sinking first and particles appearing later feels disconnected. "More messy" means varied sizes, uneven clustered spacing and staggered debris motion. **Implemented/verified for review:** seven heaving/tilting surface patches and 24 tumbling dirt/rock pieces; native motion/cleanup checks passed. This interpretation awaits the owner's artistic verdict. [Evidence](../evidence/2026-11-01-floppy-ground-friction.json).

## Gun feel and slug recovery (2026-11-01)

These are readings of this chat's context, not universal definitions. Prefer the owner's latest concrete correction.

| The owner says | What it turned out to mean | What failed |
| --- | --- | --- |
| "small tweaks", "shouldn't look too much different, but it should look different" (grip) | The change must be obvious when comparing two screenshots. 9° and 0.18 studs landed. | 3° and 0.07 studs: "way too small of a difference". |
| "slight kick", "nothing crazy" (recoil) | Still needs to read while running. It ended as a "big kick up": 22-32° on the gun. | 3.2°, 7.5° and 11° kicks, and a reshaped curve at similar size ("basically the same"). Part of this was a real bug: recoil was not reaching the visible gun properly. |
| "more animated" (recoil) | Mainly bigger and more readable. Timing polish alone was not noticed. | Sharper attack and settle at small amplitude. |
| "Slugterra-esque" (gun motion) | Expressive and flourish-like: reuse the accepted draw toss rather than inventing a motion. | — |
| "absorbed into the body", "meshes in" (aiming arm) | The arm crossing into the torso at extreme aim. Some overlap is fine; a screenshot from the owner marks the limit. | Pointing straight ahead at rear targets ("too far in the opposite direction"). |
| "shoulder looks way too detached" | Keep the shoulder near its normal place even if the arm overlaps a little. | Full clearance by moving the shoulder out of the torso. |
| "excess tilt", "off-putting" (first-person gun) | The gun's angle, not the arm: keep the arm moving and settle the gun toward aim. | — |
| "150% slower", then "33% faster" | 150% more time (0.5 → 1.25 s), then 1.25 / 1.33 = 0.94 s. Superseded by burrowing. | — |
| "speed of light" | Too fast to follow; also the objection to any return timed to the cooldown. | Fast recall streaks. |
| "poof", "feels like the poof" | Any exit where the slug just vanishes, even with a nicer effect. It must be something the creature does. | Puff; shrink at the hip. |
| "roll around onto its back" | A visible belly-to-back roll before the hop. | Going straight from belly to hop. |
| "not enough friction" (burrow) | The ground itself moves while it digs, then dirt piles up. In the charge ring, "friction" meant visible tension instead. Same word, different meaning. | Sinking first with dirt simply appearing. |
| "more messy", "less uniform" (dirt) | Lumpy clods and angular rocks in uneven clusters at varied sizes. | An even ring, round marbles, flat plank-like patches. |
| "imagine a 4v4v4v4" | A readability stress test for design decisions, not a confirmed match format. | — |

**Working pattern in these rounds:** the owner asks for an opinion before committing ("what do you think?"), and "that makes sense" means go ahead. "If you can't think of a nice workaround, leave it" is genuine permission to leave it. Moving to the next item without comment usually means the last result is acceptable for now, but it is not formal approval, so don't record it as approved. When the owner says "this is how it's gonna be", write it down immediately as a confirmed decision.

More dictation slips: "mehdy" = meh, "extenuate" = accentuate, "target area" = the training range, "Slug Terra" = Slugterra.

**Added after the review (2026-11-01):** "more animated/wiggly" for a creature means large overlapping motion through every bone, not a slightly bigger version of the same wobble; verdict pending. "Arms by your side but you can still see them" is a real geometry conflict at a level look: truly hanging hands sit below the frame, so the arms are framed low in the corners with the gun tipped down, and the owner can settle it on the P panel. "It stiffens the bottom" tied the model's flat base to how the animation reads, so check the model before only tuning motion. "We'll add sound later" and "I won't do 16 players" close those items rather than defer them to the next pass.

**Second round (2026-11-01):**

| The owner says | What it turned out to mean | What failed |
| --- | --- | --- |
| "looks like it has a butthole" | Anything converging on the centre of the underside: mesh rows, radial creases, a dark surround. | Rings to one point; dark dome. |
| "sluggish foldy texture" | Soft rolls straight across, in the body's own colour. | Radial or darker treatment. |
| "the spiral should spin" then "just the light inside" | The mechanism stays still and a light moves inside it, so it reads as charging. Confirm which part moves before building. | Spinning the vanes: "like a fidget spinner". |
| "less loud, less shapy, more of a gloom" | No visible edge or growing object: a faint haze and soft light that swell and fade. | A neon sphere that grows and fades. |
| "arms a little too forward", "put the arms down" | Lower in the frame, not a new pose. | — |
| "permanent ... for all slugs. I mean, not for all slugs, but for the floppy" | Dictated self-correction: the later clause wins. Record it as Floppy's own design, not a species rule. | — |
| "shake or vibration" (charging gun) | Fine fast movement of the gun alone that grows with charge, never the aim. | — |

**Third round (2026-11-01):** "I don't know how we could even make it look good as a concept" is a request for clearly different directions and a recommendation, not for another polish pass. "A free cursor that's just a cursor for optimum accuracy" means nothing around the aim point while aiming. "Lightweight, quick, frictionless" (ADS) means a raise of about 0.1 s and no movement penalty.

**ADS (2026-11-01):** "the ADS is flipping horrible... just a square" was about shape and origin. A reference screenshot means use that exact shape, so measure it. "Pulled out of nowhere" means a visible object needs a physical source on the gun. "Very modern techie animation" landed as clean mechanical stages followed by a frame that draws itself. When something is "very buggy" in a mode, the owner may simply remove that mode rather than iterate.

**ADS follow-up (2026-11-01):** "a clear outline that sticks to the eyelids" means painted on the skin, not an effect that depends on the camera. "Fully transparent" means no pane at all, even at 8% opacity. "Animative, transitional" means overlapping eased stages and fades rather than parts snapping into place.

**Floppy's eyes (2026-11-01):** "offsetting", "off-putting" (resting eyes and blink) means the mood is wrong for the character: alert or angry rather than "tired and sick and lazy". It landed on slower motion, drooping outer corners and softer lines, rather than more geometry. "Malformed" pointed to a real mesh flaw, so look for one before retuning.

**Crosshair feedback (2026-11-01):** "a sphere around it" means the glow has a visible edge, so bunch the falloff toward the centre. "Ping and go away" means a brief event, never a state that lasts while holding. The owner keeps the crosshair area clean: every ring proposed around it has eventually been rejected, so try cues elsewhere first.

**Charge feedback (2026-11-01):** after a bar, many rings, a glow and a ping, the owner's real need was stated plainly: vibration is "how you kind of gauge how much power is behind your shot", and it must survive running. "I don't know what I'm compromising" signals to stop tuning and offer clearly different directions. Discrete counted steps were chosen because they read better than a continuous level and are "more skill based". "Feel" on keyboard and mouse can only be visual, so it means whole-view and arm motion as well as the gun.

**Accuracy and steps (2026-11-01):** "a little to the bottom right" had one physical cause, droop while still on the gun's side of the aim line, so measure landing offsets before tuning. "Bap bap bap" rejects sharp, quick repeated hits, even when they are readable: prefer eased steps that hold. "Make these the new base settings" with a panel screenshot means bake every changed value; the panel is working as intended.

**Shot levels (2026-11-01):** "first phase" and "a quick tap" are the same level; "two holds" means reaching the second kick. "100% accurate" was qualified by the owner: "won't obviously be fully bullet tracing, but it'll hit the area" the cursor is on. So the arc stays visible and the landing point is what must be right.

**Slide gun position (2026-11-01):** "corrupts the gun shooting position" when "sliding to the left and to the right, and like diagonally backwards" meant the gun following the body, which turns to face the slide. The owner's direction detail located it: forward slides looked fine, so forward-only tests could not show it.

**Overshoot (2026-11-01):** "past a certain height the gun moves up a lot" and "overshoot" were a real jump: the arc followed the distance under the crosshair, which changes abruptly at a target's edge. Screenshots from the owner located it immediately. Anything driven by the crosshair's hit distance needs checking at target edges.

**Strafing accuracy (2026-11-01):** "when strafing the shooting is inaccurate, slugs fall very short" did not reproduce with a target behind the crosshair at any movement state. Test with nothing behind the crosshair too, because moving makes the aim leave the target.

**Running vibration (2026-11-01):** 2.2x was barely noticeable and 3.5x with the arm "kicks your arm up" and throws the aim. The gun can carry the vibration; keep the arm calm.

**ADS shake (2026-11-01):** "stable" followed by "ever so slight, just so you can feel the charge" means the sight keeps its place and only a tiny tremor remains. Earlier, a first-person shake of 0.006 studs was too light to notice, so an "ever so slight" effect still has to be visible.

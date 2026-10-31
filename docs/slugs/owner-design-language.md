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

He dictates; read for sound, not spelling. Seen: "drawl"/"Drew" = drool, "spider animation" = spiral animation, "glue" = glow, "class" = glass, "doc under eyes" = dark under-eyes, "slime fits inside the shell" = slug, "slug terror" = Slugterra, "floppy" = the slug's name (not a description). Ask only if the sound-alike is still ambiguous.

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

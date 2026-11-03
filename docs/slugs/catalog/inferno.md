# Slug design record: Inferno

## Final design — owner, 2026-11-03

**Confirmed:** "Make them the final designs" for Inferno and Floppy. Both Inferno forms are final as they stand in `tools/slugs/build_inferno.py`.

- **Size:** the base form matches Floppy's game size, 0.69 wide and 1.06 tall (`GAME_SCALE` 0.4218).
- **Transformed form:** body behind the shoulders at 80% of the concept's length and tail at 50%; eyes lowered; thinner lip band; belly folds.
- **Tail fire:** flame built into the body mesh from the concept's formula, moved by seven bones, with a soft two-layer glow behind it.
- **Face:** skin lids, morphing mouth, furrowed brows when angry, and no blink in either form.

**Implemented/verified:** offline export sizes, `verify_slugs.py` and Studio Play captures of the display place. **Unresolved:** Inferno is not in the game yet; shot numbers and the ability; the glow can look square for a moment when the tail points almost straight at the camera; the outline's Highlight limit in a crowded scene; game-size tuning of the fire; and a side-by-side and name/IP check before publication, because "Inferno" sounds like the franchise's Infurnus.

**In the game, 2026-11-03 (proposal numbers, owner playtest pending):** slot 2 of the loadout. Damage 25, speed 300/420/500, gravity 20, drag 0.05, exact aim from the second kick. Owner: he fires in his base form until the transformation is built, and the base form also shows in icons and the canister. The fire sizes itself from his bones, so it scales down with the model. Verified: combat and creature checks pass, and the merged range loads in Studio Play with his icon in slot 2. Not verified: firing him, the canister view, recovery on landing, multiplayer. Landing reuses Floppy's recovery. The transformation animation is next.

The sections below are the design history, oldest first. Where they differ, this section wins.

## Confirmed — owner direction, 2026-11-02

- **Role:** the second slug, and one of the more powerful ones. It is inspired by Burpy from Slugterra but must be its own design.
- **Name:** **Inferno** (Confirmed by the owner, 2026-11-02). The research report's proposed names (Scorchet, Cinderwick) were not taken.
- **Shot:** it spins when fired, then transforms into a bigger form. "Shoots fast" means **shorter flight time**, so it feels closer to hitscan. It is not a rapid-fire slug.
- **Accuracy:** a shot lands exactly on the crosshair from the **second charge kick**. Floppy needs the third.
- **Damage:** it hits a lot harder than Floppy, without being broken.
- **Ability:** one per slug. See [ability rule](index.md#ability-rule).
- **Anatomy, to stay distinct from the reference:** no feet, no arms, and a small tail like Floppy's.

## Reference research and rights

- **Research:** [Burpy report](../../../reports/Burpy%20slug%20design%20research.md) and its notes in `research_notes/`. The fan wiki was blocked, so wiki facts are second-hand from search summaries. No episodes were watched. Parts of the report are superseded by the owner direction above, including the name and the Kindle ability.
- **Owner references, 2026-11-02:** the owner supplied screenshots of the franchise slug's base and transformed forms, plus one of Flopper. They show a bright orange slug with a pale flame-shaped belly, white and yellow lightning crown, large round eyes, horn-like antennae, small arms and feet, and a phoenix-dragon flying form with flame limbs. They are third-party study material with no reuse rights and are not stored in this repository.
- **What Inferno avoids:** every trait listed above. It takes only the general idea of a fire slug that transforms when fired.
- **Name risk (Unresolved):** "Inferno" sounds like the franchise species name, Infurnus. A name and IP check is still needed before any publication.

## Confirmed — owner revision, 2026-11-02

The owner rejected the first concept (charred black crust, thin antennae with pilot lights, soot band, round head): "from the front, it just looks like a joke". This slug is meant to be **the predator**. New direction:
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Confirmed — owner revision 7, 2026-11-02

The owner replaced the long forehead mark with a **small ember crest**: a compact emblem that keeps the forehead smooth. For the belly, a pasted critique asked for a soft golden patch running down the front and widening towards the lower torso, with a soft transition, no hard border, no extra geometry and no glow. It also suggested a flame-inspired outline.

## Confirmed — owner-supplied critique 4, 2026-11-02

Move the emblem lower and slightly smaller, between the upper eyes. Tone the lids down so they read as natural lids, not eyeliner: thinner, less arched, no decorative brow. Target look: cute, confident and cheeky. Make the belly an intentional flame motif, broader low down, narrowing to a point, soft-edged, with a subtle inner highlight, not a gradient.

## Confirmed — owner-supplied critique 5, 2026-11-02

Make the emblem bigger and clearer. Remove the wrinkle-like creases at the outer upper eye corners, which read as crow's feet and bring back the uncanny look. The belly read as a teardrop, and the critique asked for a three-point flame.

**Not followed:** the three-point belly flame. A multi-tongued flame belly is the franchise reference's most recognisable marking, and AGENTS.md requires original IP. The underlying complaint (a static droplet) was addressed with an original motif instead, and the owner was told.

## Confirmed — owner-supplied critique 6, 2026-11-02

Make the eyes about 10–15% larger, mostly vertically, in a rounder almond with less slant and soft upper lids, with no creases, keeping the glow and spacing. Clear the belly diamonds and leave the orange-to-yellow colouring. The owner then supplied three stock images of multi-tongued cartoon flames as a belly reference.

**Not followed:** a multi-tongued belly flame, for the reason in critique 5. The stock images are watermarked or licensable, and aren't stored or reproduced here. The belly stays unmarked, pending the owner's choice of an original alternative. Proposed use for that flame style: the transformed form's fire and impact effects.

## Confirmed — owner revision 8, 2026-11-02

Plain belly. A heavier lid on one eye. The face looks too flat and 2D from the front.

## Confirmed — owner revision 9, 2026-11-02

The forward masses were wrong: "he looks like a chud", and the rounding looked weird, especially from the side. Make the eyes a little more cutesy-fierce, a bit wider. Add depth to the smile and a bit more detail.

## Confirmed — final base design, 2026-11-02

The owner confirmed this as the finalised base form, after moving the nose freckles slightly down: "make it the finalised base design and add it to the codebase, it is inferno". This is a rotatable concept, not yet the game model, as Floppy's was at this stage. Later concept rounds are preserved in this record's history above.

## Implemented — final base concept

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Ember crest:** a flat, solid deep-red rounded ember with a spark either side and no glow, about 50% bigger than the previous round.
- **Belly:** a plain orange-to-yellow gradient with no marking.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Confirmed — owner revision 7, 2026-11-02

The owner replaced the long forehead mark with a **small ember crest**: a compact emblem that keeps the forehead smooth. For the belly, a pasted critique asked for a soft golden patch running down the front and widening towards the lower torso, with a soft transition, no hard border, no extra geometry and no glow. It also suggested a flame-inspired outline.

## Confirmed — owner-supplied critique 4, 2026-11-02

Move the emblem lower and slightly smaller, between the upper eyes. Tone the lids down so they read as natural lids, not eyeliner: thinner, less arched, no decorative brow. Target look: cute, confident and cheeky. Make the belly an intentional flame motif, broader low down, narrowing to a point, soft-edged, with a subtle inner highlight, not a gradient.

## Confirmed — owner-supplied critique 5, 2026-11-02

Make the emblem bigger and clearer. Remove the wrinkle-like creases at the outer upper eye corners, which read as crow's feet and bring back the uncanny look. The belly read as a teardrop, and the critique asked for a three-point flame.

**Not followed:** the three-point belly flame. A multi-tongued flame belly is the franchise reference's most recognisable marking, and AGENTS.md requires original IP. The underlying complaint (a static droplet) was addressed with an original motif instead, and the owner was told.

## Confirmed — owner-supplied critique 6, 2026-11-02

Make the eyes about 10–15% larger, mostly vertically, in a rounder almond with less slant and soft upper lids, with no creases, keeping the glow and spacing. Clear the belly diamonds and leave the orange-to-yellow colouring. The owner then supplied three stock images of multi-tongued cartoon flames as a belly reference.

**Not followed:** a multi-tongued belly flame, for the reason in critique 5. The stock images are watermarked or licensable, and aren't stored or reproduced here. The belly stays unmarked, pending the owner's choice of an original alternative. Proposed use for that flame style: the transformed form's fire and impact effects.

## Implemented — fourteenth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Ember crest:** a flat, solid deep-red rounded ember with a spark either side and no glow, about 50% bigger than the previous round.
- **Belly:** three soft golden embers rising up the front, largest low, each smaller and drifting off the centre line, in the same shape as the crest. No outline or glow.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Confirmed — owner revision 7, 2026-11-02

The owner replaced the long forehead mark with a **small ember crest**: a compact emblem that keeps the forehead smooth. For the belly, a pasted critique asked for a soft golden patch running down the front and widening towards the lower torso, with a soft transition, no hard border, no extra geometry and no glow. It also suggested a flame-inspired outline.

## Confirmed — owner-supplied critique 4, 2026-11-02

Move the emblem lower and slightly smaller, between the upper eyes. Tone the lids down so they read as natural lids, not eyeliner: thinner, less arched, no decorative brow. Target look: cute, confident and cheeky. Make the belly an intentional flame motif, broader low down, narrowing to a point, soft-edged, with a subtle inner highlight, not a gradient.

## Confirmed — owner-supplied critique 5, 2026-11-02

Make the emblem bigger and clearer. Remove the wrinkle-like creases at the outer upper eye corners, which read as crow's feet and bring back the uncanny look. The belly read as a teardrop, and the critique asked for a three-point flame.

**Not followed:** the three-point belly flame. A multi-tongued flame belly is the franchise reference's most recognisable marking, and AGENTS.md requires original IP. The underlying complaint (a static droplet) was addressed with an original motif instead, and the owner was told.

## Implemented — thirteenth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Ember crest:** a small, flat, solid deep-red rounded ember with a spark either side and no glow, sitting low on the forehead between the upper eyes.
- **Belly:** a single soft golden flame, broad at the lower belly and narrowing to a point, with a subtle lighter centre and no outline or glow. It is one smooth shape in gold, where the franchise reference has several pale flame tongues.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Confirmed — owner revision 7, 2026-11-02

The owner replaced the long forehead mark with a **small ember crest**: a compact emblem that keeps the forehead smooth. For the belly, a pasted critique asked for a soft golden patch running down the front and widening towards the lower torso, with a soft transition, no hard border, no extra geometry and no glow. It also suggested a flame-inspired outline.

## Confirmed — owner-supplied critique 4, 2026-11-02

Move the emblem lower and slightly smaller, between the upper eyes. Tone the lids down so they read as natural lids, not eyeliner: thinner, less arched, no decorative brow. Target look: cute, confident and cheeky. Make the belly an intentional flame motif, broader low down, narrowing to a point, soft-edged, with a subtle inner highlight, not a gradient.

## Implemented — twelfth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Ember crest:** a small, flat, solid deep-red rounded ember with a spark either side and no glow.
- **Belly:** a soft golden patch, narrow at the chest and widening towards the base, with a gently wavering edge and no border, geometry or glow. The suggested flame outline was deliberately not used, because the franchise reference has a pale flame-tongue belly; a side-by-side check is still needed.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Confirmed — owner revision 7, 2026-11-02

The owner replaced the long forehead mark with a **small ember crest**: a compact emblem that keeps the forehead smooth. For the belly, a pasted critique asked for a soft golden patch running down the front and widening towards the lower torso, with a soft transition, no hard border, no extra geometry and no glow. It also suggested a flame-inspired outline.

## Implemented — eleventh concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Forehead flame:** a flat, symmetrical curved diamond in deep red with no glow, its long fine point running down between the eyes and stopping above the mouth. It stays one colour, with no white, yellow or lightning shape, to remain distinct from the franchise reference; a side-by-side check is still needed.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Confirmed — owner revision 6, 2026-11-02

The owner finds the concept "pretty nice". Keep the sharp spines and the stripes running from them to the front. Remove the extra marking running from the back of the head towards the eyes, above the first spine, and the red marking on top. Replace the bulb on the back of the head with a smooth finish and a sharp spine. Make the forehead mark a more symmetrical curved diamond flame that runs further down.

## Implemented — tenth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** about 12% narrower low down, with a slight forward lean, no arms or feet, a small tail and four sharp blade spines down the back. The top spine finishes the smooth back of the head; this reads the owner's bulb note as both a smooth head and a spine.
- **Head:** a broad slug face with no snout, brow ridge or cheek shelves, and a small fold between the eyes.
- **Forehead flame:** one flat deep-red curving lick with no glow, tapering to a fine line between the eyes. A gold core was tried and removed because it looked like a third eye. It is kept narrow and red to stay distinct from the bright lightning crown on the franchise reference; a side-by-side check is still needed.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Confirmed — third owner-supplied critique, 2026-11-02

Remove the cheek projection, keeping flat red marks. Narrow the lower body by about 10–15%, with a slight forward lean, keeping the spikes and stripes. Shorten the smile by about 15% and open it by about 25–35%, with no lips. Add a flat flame marking on the forehead, tapering to a fine line and stopping before the mouth. Make the eyes about 10% taller with a softer outer corner: the eyes make him cute, the rest makes him powerful.

## Implemented — ninth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** a thick neck and chest with no arms or feet, pooling onto the floor, with a small tail and three blade ridges down the spine.
- **Head:** a broad slug face with no snout or brow ridge. Subtle cheeks, fuller on the high side, with a small fold between the eyes and room in the mid-face.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Confirmed — second owner-supplied critique, 2026-11-02

Target expression: cheeky, confident, slightly mischievous, a little dangerous, but still appealing, sitting between **cute mascot and little menace**. The previous version leaned too far to menace. Asks: lower, less narrow, less slanted eyes; subtler cheeks; a longer smile; more space between the features.

## Implemented — eighth concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** a thick neck and chest with no arms or feet, pooling onto the floor, with a small tail and three blade ridges down the spine.
- **Head:** a broad slug face with no snout or brow ridge. Cheeks are pushed up by the smile, fuller on the high side, with a small fold between the eyes.
- **Ear-antennae:** a crossover between fox ears and antennae, pointing up and slicked back, resembling the ear shape without reading as ears.
- **Colour:** orange, red and yellow, in a different pattern from the reference. No black.
- **Head:** must look like a predator from the front.

## Confirmed — owner revision 2, 2026-11-02

The owner rejected the second concept as looking like an angry bird, with a beak and a strong brow. **"Predator" mainly means the eyes**, not the head shape. Snake eyes are out, because they make it look like a dragon. The ear-antennae were "almost perfect", but should be slightly shorter, droop more and be flexible, not stiff. The owner isn't sure what the eyes should look like, so options were offered.

## Confirmed — owner revision 3, 2026-11-02

The owner chose the **Burning** eyes, a bit bigger. He should look like a **predator among slugs**, not scary or a predator in general. The mouth moves down and becomes a friendly cartoon smile, because this slug should be expressive.

## Confirmed — owner revision 4, 2026-11-02

The owner said the concept is heading the right way, but the mouth still looked creepy and the eyes too small. Eyes should be bigger and a little rounder. The mouth should be a cocky, arrogant, cartoony cheese smile with teeth, not realistic teeth.

## Confirmed — owner revision 5, 2026-11-02

The previous grin was too cocky, and the owner doesn't want tooth lines. He should look a little happy alongside the cockiness. The owner supplied a reference image of a generic cartoon smile to model the mouth on: one solid white shape with a grey band under the top lip, thick dark outline, a flared high corner with a small cross flick. The image is third-party study material and isn't stored here. The lack of eyelids made the eyes uncanny and scary.

## Confirmed — owner-supplied critique, 2026-11-02

The owner pasted an outside critique: the features are good but don't read as one expressive creature face, which is why it feels uncanny. Keep the eye interior, palette and antenna shape. Asks: a mouth that reads as a crease in the face with less lip; heavier upper lids, a slight lower lid and some structure above the eyes; a more angular eye outline; more facial planes around the cheeks, eyes and smile; and one clear expression. The critique also says to keep the teeth. The owner's earlier notes still apply, so the teeth stay solid with no lines and the eye structure is a soft fold, not a strong brow.

## Implemented — seventh concept, awaiting owner review

[Concept page source](evidence/inferno/inferno.html), with [turntable frames](evidence/inferno/frames/) rendered by [`render_concept.py`](../../../tools/slugs/render_concept.py). These are original signed-distance shapes written for this page, with no imported mesh, texture or image. Renders were inspected from the front, three-quarter, side and back and in face close-up. No Blender, Roblox or gameplay work has been done.

**Base form**
- **Body:** a thick neck and chest with no arms or feet, pooling onto the floor, with a small tail and three blade ridges down the spine.
- **Head:** a broad, soft slug face with no snout or brow.
- **Ear-antennae:** broad at the root, then drooping out and back. They bend and bob along their length in Live 3D, with softly glowing yellow tips. The flexibility is a concept animation and hasn't been rigged.
- **Colour:** orange `#E7731C`, deep red `#AD3722` stripes running from the spines around the flanks, and a soft yellow `#F7B844` underside. Outlines are dark maroon.
- **Eyes:** the same burning glow with no pupil, about 10% wider and, at the owner's request, about 12% taller, with a slight lift at the outer corners, fine rays in the glow and two highlights. The viewer's left eye has a slightly heavier lid. No creases.
- **Face depth:** the forward masses around the mouth and forehead were removed. Only very soft sockets and a mild form shadow remain.
- **Mouth:** a compact, lopsided smile set deeper into the face. The solid teeth fall into shadow at the corners, with a soft shadow beneath and no lips.
- **Detail:** darker stripe edges, gold spine tips, a red tail tip, a deeper rim at the base and small flecks across the back of the head and shoulders, plus three faint red marks on each cheek and seven freckles across the nose area, at the owner's request.

**Rights check (Unresolved):** the silhouette is its own, with no arms or feet, a slim leaning body, spines and different ear-antennae. But an orange body, glowing antenna tips and a head emblem share a layout with the franchise reference, even though each one differs. The belly no longer uses a flame. A proper side-by-side and the name and IP check are needed before any publication.

## Confirmed — transformed form direction, 2026-11-02

The owner rejected the bullet form because it looks like a missile. It should be a cool transformation that mixes a slug with a dragon, keeping the character's DNA.

**Revision, 2026-11-02:** keep the base form's wide grin, make the eyes larger, and give him real wings, not spikes or small arms.

**Revision 2, 2026-11-02:** shorten the tail by a noticeable amount, put the wings down at his sides, and replace the trailing fire with a small animated fire on the tail tip: noticeable and medium-sized, in the style of the flame images the owner supplied. Those are stock images, so the flame was drawn fresh and not traced.

**Revision 3, 2026-11-02:** spread the wings out instead of tucking them in, make them bigger, and join them along a longer stretch of the body, not at one point. Make the flame less cartoon-like next to the body and point it backwards in line with the tail. Shorten the transformed body.

**Revision 4, 2026-11-02:** remove the yellow triangle above the mouth, move the emblem down so it shows from the front, and blend the fire into the tail so it looks part of it.

**Revision 5, 2026-11-02:** the smile's high corner touched the eye, so it was lowered with a shorter hook.

## Confirmed — final transformed design, 2026-11-02

The owner: "okay its perfect, make this the finalised design". Both forms are now final as concepts. Next: Blender, Roblox Studio, then shooting.

## Implemented — final slug-dragon concept

A bigger form with a compact curving body, an arched neck, a short soft snout, a short tail and four spines. Big solid leathery wings spread out and slightly up from a long join along the body, with a strong front arm, ribs and a scalloped back edge, running from deep red to orange with a thin gold edge. It carries Inferno's own ear-antennae, base-size burning eyes, the base form's grin, ember crest, freckles and stripes. The ember crest sits on the front of the forehead. The last part of the tail heats up and glows, running with no outline into a medium-sized 3D flame that streams straight back, shading from yellow through orange to red, with calm one-second looping motion. The franchise form's flame limbs, burning wings and horned crown are deliberately not used.

**Rights check (Unresolved):** an orange winged creature with a yellow underside and a flame on its tail tip also resembles a very well-known character from another franchise, so the check before publication should cover that as well as the slug reference.

## Implemented — Blender and Studio display, 2026-11-02

**Confirmed, owner:** open Studio with large models of Floppy and Inferno, to judge their faces. Inferno must blink, go between an angry and a smiling mouth, and be far more active and cocky than Floppy, including a backflip, with smooth transitions. Remove the black lines from both faces, improve Floppy's blink, and give Inferno an underside like Floppy's.

- **Build:** [`build_inferno.py`](../../../tools/slugs/build_inferno.py) ports the approved concept to `assets/source/slugs/models/inferno/inferno-{base,dragon}.blend` and ignored `build/slugs/inferno`. Bodies are 12,000 and 16,000 triangles, doubled by the ink shell, with 1024 maps. Rendered from front, three-quarter, side, back and under.
- **Face:** each eye sits in a recess. Blinks use a separate plain lid mesh hidden inside the head when open, which swings over the eye, so no second lid outline can show. There is no ink shell on the face, and eye and smile lines are deep red.
- **Underside:** painted folds with matching shallow geometry, on the base form.
- **Motion:** [`InfernoMotion`](../../../experiments/creatures/inferno/client/InfernoMotion.client.luau) springs every channel toward a target pose. Base: bouncing, leaning in, head wag, spin, leap and backflip, always looking at the player. Dragon: wing beats, banking, swoop, barrel roll and tail whip, with a particle tail fire. Both blink and move between grin and angry.
- **Display:** `inferno.private.project.json` builds `build/SlugshotInfernoDisplay.rbxlx`. Assets are private and listed Approved; ids stay in ignored `private-assets/inferno`.
- **Verified in Studio:** one local client loaded all three models with no errors from these scripts. Captures show the grin, angry mouth, half and full blink, the backflip and the dragon's banking. Frames do not prove smoothness: **Unresolved:** owner verdict on motion and faces; the dragon's face is less close to the concept than the base; gameplay, canister fit and shooting are not started.

**Revision, 2026-11-02 (owner verdict pending):** the owner wants no blinking on Inferno (their earlier dictated note was misread as asking for it), corners of the mouth angled down and fiercer eyes when angry, outlines that hold through flips, better ground contact, and more transitional flips. He no longer blinks: the lid mesh is now a slanted fierce lid that slides out of the head only when angry. The hull is gone from Inferno's model; the display outlines both slugs with a `Highlight`, which is limited in how many can draw at once, so the game needs a plan for it. His foot curves under, and the base can no longer sink through the floor. Flips and spins wind up, overshoot and settle, with the body arching behind the turn. In this entry above, the blink and lid descriptions are superseded by this note.

**Revision, 2026-11-02 (owner verdict pending):** the owner still saw a blink, which was the lid hiding and returning with each mood, and found the bent smile's corners unclean. Lids now stay on the eyes in both forms and anger furrows them down and inward. The angry mouth is a separate patch with clenched teeth, whose whole shape curves down, textured with the skin it covers, fading in over the grin. Floppy was confirmed "perfect". This supersedes the mouth and hidden-lid notes above.

**Teeth revision, 2026-11-02 (owner verdict pending):** blocky teeth were rejected. From the owner's reference, the angry mouth keeps its downturned shape but is one solid white shape with a grey band under the top lip and one wavy line, with no individual teeth.

**Mouth patch revision, 2026-11-02 (owner verdict pending):** the skin-textured patch showed as a box during the change, and angry should last about a second longer. The grin and gritted mouth are now two patches holding only mouth pixels over clean body skin, which no longer has the grin hollow. Angry now holds for about 2.6–3.2 s.

**Face rebuild, 2026-11-02 (owner verdict pending):** the owner found the lids looked glued on and cut through the face, the grin had no bottom edge, and the mouth change cut rather than transitioned. Overlays were dropped. As on Floppy, each eye is now its own mesh behind the skin and the upper lid is the skin stretching over it. The mouth is one mesh on 20 lip bones that morphs from grin to gritted, with ink all the way round. This supersedes every earlier lid and mouth note.

## Considering — not approved

**Shot numbers.** These are first proposals for the shared `Combat.Slugs` table on `main`, for owner playtest. Nothing has been changed there.

| | Floppy (current) | Inferno (proposal) |
| --- | --- | --- |
| Speed by level (studs/s) | 95 / 105 / 115 | 300 / 420 / 500 |
| Exact aim from | third kick | second kick |
| Damage (of 100 HP) | 7 | 25, so four hits |
| Gravity / drag | 70 / 0.35 | 20 / 0 |
| Hit radius (studs) | 0.3 | 0.3 |

At 500 studs/s, a 100-stud shot takes about 0.2 s, against about 1 s for Floppy. The exact-aim kick is currently hard-coded to the third in the client, so it would need a per-slug setting.

**Readable transform.** At this speed the flight is only a few frames, so the proposal is a muzzle burst for the transform, a corkscrew streak in flight and a brief big-form moment on impact.

**Ability, following the rule.** The shot sets things alight, and the result depends on what it hits:
- **Player:** burns them over a few seconds.
- **Ground:** leaves a short-lived burning patch that blocks a path.
- **Water:** makes a steam cloud that blocks sight.

The Kindle mark-and-ignite idea in the report is dropped from the recommendation, because its result doesn't depend on the surroundings.

## Size and finishing notes (2026-11-02)

**Confirmed (owner):** the base form matches Floppy's game size; "probably just size the inferno slug up to match floppy".

**Implemented/verified (offline export sizes and Studio Play captures; owner approval pending):**
- **Size:** `GAME_SCALE` went from 0.34 to 0.4218. The base form is now 0.69 wide and 1.057 tall, the same as Floppy. The transformed form scales with it, to 1.87 x 1.55 x 0.84 studs.
- **Transformed eyes:** moved lower, nearer the mouth (centre height 1.37 to 1.32).
- **Transformed mouth:** the grey band under the top lip is about half as thick (it now starts at 0.86 of the mouth height, was 0.73). The base form keeps its band.
- **Transformed underside:** folds across the pale belly, painted and in the surface, matching the base form's sole. The base form's sole was already done.
- **Tail fire:** part of the body mesh, using the approved concept's flame formula at length 1.9 (concept 1.5), starting 0.45 up the tail. Colour licks up the tail and runs yellow, orange, red; fire is matte (roughness 0.85). Seven bones move it: a chain of three carries a wave down it and four swell its sides so the lobes roll round it. No separate texture, so no white box on load. The outline now runs round the flame too, as one silhouette with the tail. Around it (owner: "a simple nice" fire effect "to make it pop"): a soft orange-red glow behind it, one continuous flame-shaped layer pair running back past the point, flickering in width and off until its image has loaded so it never flashes white. The owner rejected separate licks and embers as "individual fireballs". Behind the shoulders the transformed form is shorter (owner: "shorten the tail a bit. As well as the body", then "the tails tooo long still"): the body to 80% of its length and the tail to 50%. The glow is placed from the moved bones every frame, so it tracks the tail. Owner corrected its size: back to the earlier length, but taller.

## Unresolved

The small step in the antenna tips seen from the side; the shot numbers and ability; shooting in Roblox; the Highlight outline's draw limit in a crowded scene; and a side-by-side and name/IP check before any publication. "Inferno" sounds like the franchise's Infurnus.


**Confirmed/implemented, 2026-11-03 ? world scale and exhibition:** owner set the outside-gun visual size to approximately two studs for all species; shared combat and grove scales now use that value. Loaded scale stays independent. Exhibition residents spring through compression/hold/flight/landing, remain on supported ground in their habitat and briefly react to nearby players through existing facial controls. [Runtime record and limits](../../art/lobby-hub.md#springing-exhibition-residents--2026-11-03).

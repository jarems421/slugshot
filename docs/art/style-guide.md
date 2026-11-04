# Slugshot visual style guide

The general rules for how Slugshot should look and feel: worlds, props, creatures, weapons and their motion. Exact colour values, map layouts and dimensions are deliberately left out. They will change, and they belong to individual asset or level notes. This guide is the philosophy those choices are checked against.

Source: the owner's pasted art-direction chat and follow-up, 2026-10-31. The owner agreed with the proposed direction ("Yes, I agree with you") and added the calm-plus-vibrant colour requirement in their own words. **Status: Confirmed direction.** Specific treatments remain to be chosen in the [style test](lobby-roadmap.md#phase-1-style-test-vignette).

## The one-line identity

**Living Comic-Book Fantasy:** a colourful underground fantasy world illustrated with bold, dark ink, where the creatures, weapons and environment all clearly belong together.

The two references, and what each contributes:

| Reference | What we take | What we do not take |
| --- | --- | --- |
| **Borderlands**: comic-book ink finish | Dark ink outlines, stylised hand-painted textures, exaggerated shapes, colourful lighting. It is graphic inkwork over real 3D depth, not flat two-tone shading. | Its desert/industrial palette, grime level, characters, logos or any specific design. |
| **Slugterra**: atmosphere and colour | Glowing caverns, crystals, bioluminescence, mysterious underground spaces, adventurous fantasy. Its colour balance mixes calming tones with vibrant ones. | Its specific creatures, locations, props, names or logos. Everything we build is an original design that captures the category, not a copy. |

The goal is not "Borderlands inside a Roblox cave". Slugshot should be recognisable as its own look.

The owner dictates, and "Badlands"/"Badland" in their speech means **Borderlands** (the comic-ink look), not the game *Badland*.

## Core mood

Underground · mysterious · adventurous · magical · stylised · clean · lively · readable.

**Cartoonish, but not cheap-looking.** Shapes are exaggerated and simple, while materials and lighting have depth and richness.

## 1. Ink outlines

The outlines are the signature. They unify everything and make sure nothing goes unnoticed, even where colours are soft.

- **Outline weight follows importance.** Thick outlines go on creatures, weapons and important props (portals, interactables). Thinner dark edges go on architecture and set dressing. The background and distant rock get the lightest treatment.
- **Dark charcoal, not pure black, by default.** Pure black can feel aggressive. Test both and keep black only where it looks better.
- **Outline the silhouette and the key interior forms.** Borderlands-style inking includes interior lines (creases, panel seams, rock fractures), not just the outer edge.
- **Roblox constraint:** no single effect outlines the whole world the way a custom shader would. Expect a combination of methods (see [technical approach](#7-roblox-technical-approach)).

### Treatment rule: "Slugshot mix" (Confirmed, 2026-10-31)

Ink treatment is chosen **per material**, not per scene. The owner said Inked Cavern looks "beautiful" and is the main treatment, but dark natural forms look better with Comic Cavern:

| Material | Treatment |
| --- | --- |
| Glowing, clear and organic things (crystals, fungi, portal energy, moss) | **Inked Cavern**: Comic Cavern's thick near-black ink, clean surfaces with few interior lines, deep shadows with a crisp comic edge, full glow |
| **Characters (slugs, players): always** | **Inked Cavern** |
| Dark rock, stone, cave floor | **Comic Cavern**: heavy near-black ink, more interior crease lines |
| Small metal details (bands, bolts, trim) | Thick outline but **Living Comic's light interior lines**, so heavy ink doesn't swallow small detail (owner: Comic Cavern "engulfs" the portal's grey bands and orange bolts) |

The [asset library](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr) implements this as its default "Slugshot mix" mode. Enchanted was rejected; Comic Cavern, Inked Cavern and Living Comic remain available for comparison. For Roblox, this maps to per-asset hull widths, painted interior-line density and shadow treatment, to be proven in Studio.

## 2. Colour philosophy: calm base, vibrant accents

The owner's formula: **calm base tones + selective vibrant accents + bold dark outlining.**

- **Slugterra-type vibrant, not neon.** Colours should feel clean, controlled, soft, glowy and alive. Avoid neon green, random saturation and visually loud scenes.
- **Calm colours dominate.** Most of any scene is grounded, restful base colour: cave stone, muted cool greys, earthy desaturated tones and deep shadow colour.
- **Secondary colours add richness.** Mossy, dusty and earthy hues give variety without competing for attention.
- **Vibrant colour is reserved for what matters.** Crystals, portals, signs, special plants, slug habitats, blaster displays and interactables. Because the rest is calm, these feel special and pop.
- **Rough proportion guide:** about 70% base, 20% secondary, 10% hero accent. This is a balance check, not a formula to measure.
- **Dark stone is what makes the glow work.** Do not brighten the base to make a scene "more colourful".

Exact palettes are not fixed here. They will be set and revised in asset and level notes.

### Readability check (ask of every scene)

1. What is the neutral base?
2. What is the accent?
3. What needs attention?
4. What should stay calm?

If too many things are bright, the scene stops feeling magical and starts feeling messy. This is the biggest risk with this direction.

## 3. Shapes and forms

- **Rounded and exaggerated, not realistic or noisy.** Rocks are chunky, soft-edged masses with clear big shapes, not photo-scanned detail.
- **Strong silhouettes.** Every asset should read from its outline alone, which the ink lines then reinforce.
- **Chunky, hand-built feel** for anything made by people: thick bevels, oversized bolts and fittings, slightly irregular construction.
- **Consistency with existing assets.** The world must sit naturally beside Floppy (soft, slumped, glossy, drowsy) and the blaster (compact, angular, burnt orange/graphite/steel). The environment's shape language bridges soft organic and chunky industrial.

## 4. Lighting

- **Rich, colourful shadows.** Shadows lean blue and violet rather than going grey or black.
- **Glow as light source.** Crystals, plants and fungi glow and light their surroundings, giving bioluminescent pockets.
- **Warm pockets mark inhabited areas.** Amber and orange light spills from outposts, lamps and workshops.
- **Bloom used selectively.** It should look magical without washing out the scene. (Floppy's lab already showed heavy bloom flattening the look.)
- **Lighting gives each area an identity.** Neighbouring areas can differ in temperature and mood without clashing. See the zone moods in the [lobby roadmap](lobby-roadmap.md#zone-identities).

### Lighting rules learned in Roblox (Confirmed by owner feedback, 2026-11-01)

- **Ambient stays dark and near neutral.** Tinting the ambient to brighten walls turned the stone blue ("don't just make the rocks blue"). Light surfaces with placed lights instead.
- **Overall brightness never depends on shadows.** Studio switches graphics quality automatically and drops light shadows at lower levels, so shadow-casting fill lights made walls flip between dark and bright. Wall and fill lights cast no shadows.
- **Few, merged local lights.** Roblox renders a limited number of lights near the camera. Glows within about 4 studs share one light.
- **Zone moods shift colour only.** Exposure, fog density, haze, contrast and brightness stay the same everywhere, so walking between zones never re-lights the cavern.
- **Glow takes the surface's own colour.** Roblox emission is colour map x mask x strength, so a dark surface cannot glow brightly. Give glowing parts a luminous colour (Floppy's bulbs), and cap glow below white so colours survive.
- **Ink shells are near-black Neon** (`14, 14, 18`): lamps never grey them and they never bloom.

## 5. Materials and texture

- **Stylised, hand-painted look with depth.** Painted colour variation, painted highlights and ink detail on top of real lighting and normal detail.
- **Not flat toon shading.** The comic look comes from inking and painting, while lighting stays nuanced.
- **Grime is limited.** Surfaces can show wear and age, but this is a clean fantasy world, not a gritty one.
- **Glossy where it is alive.** Slugs and wet organic surfaces are glossy (per Floppy). Stone is matte, metal has chunky readable highlights.

## 6. Life and motion

The world should feel alive. There should be **just enough activity that a space doesn't feel static**, never so much that it is busy.

- **Creatures:** slugs such as Floppy resting, idling and wandering around spaces.
- **Particles:** glowing motes, spores or fireflies drifting through the air.
- **Effects are one shape (owner, confirmed 2026-11-03).** Fire, explosions and similar effects must read as one designed form, never as a bunch of individual fireballs or puffs assembled into an effect. Owner: "It needs to be one explosion, not multiple different fireballs forming the explosion." Use a drawn flipbook or a mesh with bold ink-style colour bands. Particles remain fine for small ambient motes.
- **Fire that rides on a creature is geometry (owner, confirmed 2026-11-03).** A flat picture reads as "slapped on" and looks 2D at range. Give it real thickness, grow it out from under the part it belongs to, and animate it with a ripple.
- **Plants:** subtle sway in vines, moss, fungi caps and glowing flora.
- **Light:** gentle, slow pulsing of crystals and glows, never flicker or strobe.
- **Sound:** environmental audio (drips, hums, distant water, creature sounds) supports the life pass.

Motion principles, carried over from what the owner has accepted on Floppy and the blaster ([owner design language](../slugs/owner-design-language.md)):

- **Calm and slow by default.** Ambient motion is gentle drift and breathing, not bounce. "Too bouncy and squishy" was rejected on Floppy; the owner wants soft-looking, not jiggly.
- **Readable, never disruptive.** Flourishes are short, readable from the third-person camera and never block input.
- **Consistent.** Motion should not depend on timing quirks or frame rate.
- **Original choreography.** Slugterra-esque energy is fine, but do not copy any show's specific animation.

## 7. Roblox technical approach

Roblox lacks the general-purpose screen-space shaders of Unreal or Unity. The look has to be built from what Roblox offers, and each method's cost and limits must be checked before it is adopted.

| Goal | Candidate methods (to test) | Known limits |
| --- | --- | --- |
| Silhouette outlines on meshes | **Inverted-hull shells** authored in Blender: a slightly inflated copy with flipped normals and a dark, flat material, exported with the mesh. | Roughly doubles the outlined mesh's triangles. Thickness is fixed in world space, so it thins at distance. Needs smoothed outline normals to avoid gaps at hard edges. |
| Interior ink lines | **Painted into textures**: ink lines baked or hand-painted into the colour map from curvature, seams and creases. | Resolution-bound. Lines can blur up close if texel density is low. |
| Highlighting gameplay objects | **`Highlight`** on creatures, interactables and portals (for example on approach). | Silhouette only. Roblox limits how many highlights render at once, so use it sparingly. |
| Glow | Neon/emissive surfaces, `PointLight`/`SurfaceLight`, glowing textures, bloom. | Light count and shadow cost on low-end devices. |
| Grade and mood | `Lighting` (Future technology), `Atmosphere`, `ColorCorrectionEffect`/grading, `BloomEffect`, optional depth of field. | Lower graphics levels drop or reduce effects. The look must survive without them. |
| Painted materials | `SurfaceAppearance` (colour, normal, roughness, metalness maps) on Blender-authored meshes. | Texture memory and the upload/moderation pipeline. |

Rules:

- **Check low graphics settings before adopting anything expensive.** The style must still read at low quality and on mobile.
- **Verify every claim in Studio.** Record which methods worked, their cost and screenshots. Offline Blender renders are not evidence of the Roblox look.
- **Prefer methods baked into assets** (hulls, painted lines) over runtime effects that vary by device.

### Characters and props in the look (Confirmed, 2026-11-01)

- **Floppy (final design):** an inked skinned shell that bends with him, sage sores matching the upper lids with a light glow, and luminous yellow-green antenna bulbs plus a soft head light, so slugs stand out in dark caverns.
- **Blaster (final):** curved bladed-ridge pincer tips (top down, bottom up, no corner), 15% shorter for hip carry, ink shells on every part, colours unchanged.
- **Sick reads lighter, dirty reads darker.** Dark brown blotches look like grime; sickness reads as sallow pallor, a faint bruised rim and a lit centre.

## 8. Asset quality bar ("not AI slop")

Everything in a finished scene is deliberately designed and authored, mainly in Blender, so the world reads as one hand-made place.

- **Authored, not generated.** AI mesh/scene generators, random free models and default Roblox parts are acceptable only as disposable blockout placeholders, never in finished art.
- **One shape language, one material language, one ink treatment** across every asset.
- **Concept before production.** Following the Floppy lesson, agree a concept or blockout of each distinctive asset with the owner before detailed Blender work.
- **Intentional detail.** Detail goes where the eye should go. Avoid uniform noise and greebling everywhere.
- **Original designs.** Slugterra-style categories (giant glowing cave fungi, crystals, slug habitats, hideouts carved into rock) are welcome. Each asset gets its own silhouette and records how it differs from franchise designs. See [lobby assets](lobby-assets.md).

## Open questions

- **Unresolved:** outline colour (charcoal vs black) and weights, decided by the style test.
- **Superseded by the Slugshot mix rule above.** Earlier treatment history, 2026-10-31: the owner rejected B Enchanted outright and asked for a midpoint between A Comic Cavern and C Living Comic, closer to Comic Cavern but not as heavy. This became **Inked Cavern** (about two-thirds of the way from C toward A: bolder, darker ink than C, lighter than A's heavy black), the current lead in the [asset library](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr). **Unresolved:** final confirmation, then Studio proof.
- **Unresolved:** whether creatures use the same hull outlines as props or a stronger Highlight-based treatment.
- **Unresolved:** the actual palette (owner said colours may change).

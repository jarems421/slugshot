# First slug: Flopper-inspired creature

## Confirmed — owner brief, 2026-10-31

Create a distinct original Slugshot creature inspired by Flopper. A soft, squishy and somewhat goofy personality; pale cream/light yellow-green body, olive facial accents, large expressive eyes, a broad head, narrower flexible middle, flared lower body and small flexible appendages. Squash/stretch and expressive motion are central. This species does not transform. This is the first creature design; the reference is not a mandate to import or reproduce someone else's model.

The owner supplied two screenshots as visual study material: `Screenshot 2026-10-31 005433.png` and `Screenshot 2026-10-31 005444.png`. They show a pale upright creature with green eye regions, a green belly, small arms and two long flexible projections. Those screenshots are third-party visual references, not textures, model geometry or assets supplied with reuse rights; they remain outside this public repository.

## Reference research and rights

The community-maintained [SlugTerra Wiki Flopper entry](https://slugterra.fandom.com/wiki/Flopper) calls Flopper a common, powerless, unknown-element species and describes stretching, slippery contact and smoke-related uses. Species number 000 is wiki classification; the owner supplied the names Noodle, Dizzy and Old Timer and the stated debut. These are observations of the franchise reference, not confirmed Slugshot canon. A search-indexed copy of the page was inspected on 2026-10-31; direct access was blocked by the site's robots policy. Franchise characters and names belong to their rights holders.

Reference facts supplied by the owner: Floppers do not develop a transformed form, tend to be sleepy/stretchy/clumsy, and can flatten on impact. The wiki describes stretching, slippery contact, a smoke trail, and a highly situational blaster backfire trick. The owner wants a creature with more potential for clever use in Slugshot. These examples are research and proposals, not implemented game rules.

The owner suggested an animated Sketchfab model as the main 3D study reference. [This Slugterra collection](https://sketchfab.com/DanSword/collections/slugterra-4da93539bd6d42a0b50e0942048a9a8f) lists an animated “Slug Flopper”, but the collection page returned HTTP 403 in this environment. Its actual animation, author and license could not be verified. No Sketchfab model was downloaded, executed, copied or imported. The supplied screenshots provide the directly inspected form references; do not claim an animation study occurred.

## Considering — Slugshot gameplay ideas, not implemented

A weak slippery patch, small smoke puff, a carefully placed tripwire or a squash/splat at impact could reward inventive use. The owner described these as ideas; exact effects, balance, damage and legality in a future game remain open. The franchise-specific “Stab Fire” example is a reference note, not an approved Slugshot mechanic. No projectile, collision, combat or abilities are implemented by this design task.

## Implemented/verified

**Original draft, awaiting owner review:** a pale, wide-headed body with a pinched middle, flared base, small side fins, two short curved asymmetric feelers, soft green facial patches, layered eyes, cheeks and a curved smile. A curved green belly marking is an original surface mesh fitted to the body. The working identifier `flopper-inspired` is not an approved final species name.

- Editable [Blender source](../../../assets/source/slugs/models/flopper-inspired/protoform.blend), reproducible [authoring script](../../../tools/slugs/create_flopper_inspired.py), [species configuration](../../../assets/source/slugs/species/flopper-inspired.json) and [10-bone rig definition](../../../assets/source/slugs/rigs/flopper-inspired-v1.json). Created as original procedural geometry by Codex for the owner's 2026-10-31 request; no imported mesh, texture or animation. The reference screenshots and the Blender source are kept separate.
- The authored rig has body, head, jaw, tail, independently weighted eyes and left/right feelers. It provides Idle (2 s), Blink, Hop, Launch and Impact (1 s each) actions. The asymmetrical blink and nonuniform squash use bone-scale animation in Blender; Roblox support is not established.
- Generated outputs: `build/slugs/flopper-inspired/exports/protoform/model.fbx` and five individual animation FBXs; `build/slugs/flopper-inspired/previews/index.html` contains front/side/three-quarter stills, a 360° turntable, and each motion sequence at its authored duration. [Review portrait](evidence/flopper-inspired-portrait.png), [front](evidence/flopper-inspired-front.png) and [side](evidence/flopper-inspired-side.png). These images show the actual generated 3D model, not a 2D concept.
- **Verified offline:** Blender 4.5.14 LTS headless generation, authored source validation, export/reimport of the model and five clips, dimensions/bone hierarchy/normalized weights, nonzero motion, idle loop seam, preview generation, 22 configuration tests, strict Luau and isolated builds. The mesh has 23,132 triangles across 21 mesh objects and 10 bones; each mesh is within the configured per-mesh budget. Exact source/FBX hashes, export settings and clip measurements are preserved in [export evidence](evidence/flopper-inspired-export.json). Source and outputs are separate; output binaries are ignored and reproducible.
- Run `python tools/verify_slugs.py --blender` with `BLENDER` set to the existing executable to rebuild and validate both species. To rebuild just this design from the saved source, run `python tools/slugs/cli.py all --species flopper-inspired`; render portraits with `blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/render_flopper_portrait.py`. The authoring script deliberately overwrites the editable `.blend` if run again; preserve manual edits first.

## Unresolved

Owner review of silhouette, palette, expression and how closely the design should evoke the supplied images; actual Roblox import, skinning, bone-scale channels and playback; gameplay role and final name. Studio MCP returned no connected instances during this work. The 21 separate mesh objects and total triangle count also need device/performance review and potential consolidation before use at scale. No upload or publication is authorized by the reference brief.

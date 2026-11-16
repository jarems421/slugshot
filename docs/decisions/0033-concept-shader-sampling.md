# ADR 0033: Build slug models by sampling the approved concept shader

**Status: Implemented, 2026-11-14, for Aquabeek; offline checks pass; Studio unverified.**

**Context:** new slugs are designed as live 3D concept pages (a GLSL distance field and colour function) and then rebuilt in Blender "from the same maths". Floppy, Inferno and Rammstone did that by porting each shader to NumPy by hand. Aquabeek's shader is about 1,900 lines with many options; a hand port is slow and drifts from what the owner approved, and drift is what the owner notices.

**Decision:** [`tools/slugs/sample_concept.py`](../../tools/slugs/sample_concept.py) runs a concept page's own fragment shader (its `main` removed) in headless Chrome on SwiftShader with a caller-supplied `vec4 probe(vec3 p)`, on a regular grid or a list of points, and returns four bytes per sample (`pack24` for distances). A slug's build script uses it for:
- the distance field on a grid, meshed with the existing surface nets, then each vertex snapped onto the surface (three axes at 24-bit precision; 8 bits left rings in the shading);
- vertex colour, glow and part membership (for skin weights) on the source model;
- the game texture: each texel's position on the reduced mesh is baked, snapped onto the surface and coloured by the shader, so fine detail (lashes, irises, scales) is as sharp as the texture allows rather than blurred through vertex colours.

Animation inside the shader is switched off by a page define (Aquabeek: `MOTION 0.0`) so the sample is the rest pose. Nothing leaves the machine.

**Consequences:** a concept change reaches the model by re-running the build, not by editing a port. The page's shader becomes a build input, so tooling defines must not change how the page looks (defaults keep the page identical). SwiftShader is used deliberately: Windows GPU drivers have miscompiled parts of these shaders (see the lesson index). Surface nets produce inconsistent winding, so normals are recalculated. Older slugs keep their NumPy ports.

**Evidence:** [Aquabeek's record](../slugs/catalog/aquabeek.md#implemented---in-the-game-place-not-yet-seen-in-studio-2026-11-14). Boon Doc's source models (2026-11-14) use it too, with no page define: the time uniform left at 0 is his rest pose. [Boon Doc's record](../slugs/catalog/boon-doc.md).

# Curled cave fern

**Confirmed, 2026-11-01:** owner requested curled cave ferns at the volcano's foot and a separate reusable 3D asset. This is an original Slugshot cavern plant with six curled fronds, paired leaves, muted blue-green paint, fine mint veins and dark ink edges.

**Implemented:** [individual preview](https://slugshot-volcano-concept.jarems421.chatgpt.site/?asset=fern), [downloadable GLB](https://slugshot-volcano-concept.jarems421.chatgpt.site/curled-cave-fern.glb), editable [authored generator](../../assets/source/environment/curled-cave-fern/fern-asset.js) and [reuse notes](../../assets/source/environment/curled-cave-fern/README.txt). The website also offers source and reuse-note downloads. The same `SlugshotFern.create(THREE, {seed:19})` definition is used for the isolated preview and six rotated/scaled volcano placements. Generated local export: ignored `build/lobby/curled-cave-fern/curled-cave-fern.glb`.

**Implemented/verified offline:** GLB v2 header, lengths, finite positions/normals, valid indices and accessor ranges pass structural checks. Four meshes, 7,008 triangles including ink, 246,988 bytes, dimensions approximately 7.62 x 10.71 x 7.84 studs (X/Y/Z). Origin is at the root; small roots extend slightly below zero. The GLB has portable vertex colours and ink hull geometry, with no external textures. Its PBR lighting differs from the website shader. Foliage leaves are intentionally open and double-sided.

**Implemented/verified in browser:** isolated live view and 36 rendered angles inspected; forced-no-WebGL preview, controls, 390 px layout, and all three download routes pass. [Preview evidence](evidence/volcano/curled-cave-fern.png).

**Unresolved:** owner art verdict, Blender handoff, Roblox import/appearance, final placement scale, LOD and measured device cost. The source is a reusable concept, not evidence of a final Studio asset.

**Implemented backup, 2026-11-02:** the complete [local viewer snapshot](environment-preview/README.md) includes the standalone fern GLB, shared generator and rendered fallback.

Slugshot Curled Cave Fern - authored reusable concept asset

The fern GLB and fern-asset.js generator use the same seed-19 geometry as the volcano dressing.
Root origin: ground level. Dimensions: approximately 7.6 x 10.7 x 7.8 studs (X, Y, Z).
GLB: 4 meshes, 7008 triangles including dark ink shells. Portable vertex-colour paint, no external textures.
Source: load Three.js and fern-asset.js, then call SlugshotFern.create(THREE, {seed:19}). The returned THREE.Group can be positioned, rotated and scaled. Materials may be supplied through options.materials.leaf/stem/ink.
The GLB uses portable PBR vertex colours, so lighting differs from the website shader. This is a reusable concept asset; Roblox import, final scale and performance still need engine validation.
Three.js is required to run the generator and is covered by THREE-LICENSE.txt in the preview source.

# Lobby hub in Roblox

The final hub designs built for the game, on top of the approved block-out, whose simple colliders still carry the player. Everything here is look-only. Status: **Implemented, in owner review, 2026-11-01.** Not published. Runtime performance on a real phone is **Unresolved**.

## How it's built

- **Place:** `python tools/lobby/build_hub.py` writes `build/SlugshotLobbyHub.rbxlx` from `lobby-hub.private.project.json`. `--check` adds a short camera check.
- **Models:** `python tools/lobby/hub_mesh.py all <key>` samples each piece from the asset library's own shader, builds a budgeted game mesh in Blender (`blender_hub_piece.py`), and paints every texel from the shader. `python tools/lobby/hub_mesh.py list` shows budgets.
- **Uploads:** `python tools/lobby/upload_hub_assets.py`, private, into ignored `private-assets/lobby`.
- **Ground shape:** `python tools/lobby/hub_mesh.py shape` measures the rock outline, pit edge, lip and fall positions from the art into `experiments/lobby/scale/shared/rim_shape.json`. Re-run it after changing those shapes.
- **Place scripts:** `experiments/lobby/hub`. `HubArt.server` places the art and effects and hides the block-out it replaces. `HubMotion.client` runs all motion and the Detail button.

## Decisions from owner review (Confirmed, 2026-11-01)

- Bridges rest still. Standing on one dips it under your weight with no wobble; only moving on it makes it sway and the boards rock. This replaces the earlier "slight sway at all times".
- Crack mushrooms are really tiny, about 1 to 2 studs, with caps under a stud across. The concept's `tiny = 2` setting holds this.
- The Sky Well's eye and perimeter must look clearly separate from the cavern ceiling: a crown of pale carved stone with runes and a glowing ring, then a dark moat that nothing crosses, then the natural cave ceiling with spires, multicoloured crystals and veins. Moss and hanging vines spread across the whole cave and a little over the crown and the rocks round the eye, with only the moat left bare. `tools/lobby/ceiling_sites.py` generates it at fixed coordinates.
- Every crack is a real V-shaped hole through the top, sharp at both ends: a touch of lit stone at the lip, black walls and glowing azure welling up from the bottom, with mini copies of the standard cyan crystal cluster rooted into the crack walls, alternating cyan and azure, all glowing with a twinkle. `rock_sites.py` only uses a site whose cluster clears the opposite wall and its neighbours. Six spaced cracks at fixed coordinates, with no clumps. No puffs of mist. The dark paint is game-only (`GAME_PAINT` in `hub_mesh.py`), so the library's cracks still glow teal.
- Each fall starts from a round stone basin in one shallow hole in the cliff, full to the brim. Water spills over its whole front edge, covers the stone and falls as one curtain, built from strips that stay flat to the basin rather than turning to the camera. No side streams. The rock columns in its path are left out. Fall angles are fixed constants (`fallAngle` in the shader and `falls` in `hub_mesh.py`). The land reaches out to meet each bridge. Rim bushes have their own detail.
- Waterfalls must read as flowing liquid in the whirlpool's colours, with a visible connection where they land. They are now scrolling sheets with ripples and foam, not a mesh.
- The gun-side symbol is the game's blaster in its own colours, with sharp edges: orange prongs, cyan canister, dark body with the white swirl. The entrance symbol is a jagged stone arch with stalactites, a path and light inside.
- Falls only come from their mouths and melt into the juice at its surface. Lanterns are solid and only move with the bridge. The ground matches the rock and rim you can see. No floating rocks in a bridge's path.
- A Detail button in the place switches between High and Low. A game can't change Roblox's own graphics level.

## Roblox versions differ from the concept on purpose

| Concept | Game |
| --- | --- |
| Volumetric storm | Stacked discs of the concept's cloud field, turning at slightly different rates. Lightning brightens the discs themselves. No camera-facing sprite may cross a disc: it gets cut in a straight line, which read as a box |
| Volumetric light | Soft camera-facing Beams |
| Folded juice surface | A smooth funnel that rotates, with folds in its colour and normal maps |
| Falls | Scrolling Beams with wavering edges, ripples and foam at the foot |
| Light rising from cracks | Emission and bloom only, with the painted halo |

## Costs

Latest, after the ceiling: busiest view about 234k triangles, 131 draw calls and 107 MB of textures on an RTX 3070; about 330k across all pieces before automatic LOD. Still no phone evidence.

Measured in Studio on an RTX 3070, before the last two rounds: about 145k to 195k triangles and 80 to 125 draw calls in most views, with the Low setting taking off about 10%. All pieces together are about 270k before Roblox's automatic LOD. Those numbers aren't phone evidence. The last two rounds weren't measured, because Play didn't start from the automated check.

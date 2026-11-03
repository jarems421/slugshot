# Lobby checkpoint, 2026-11-03

Where the lobby stands after the four main areas, written so a new chat can pick up from here. The detail for each piece is in [lobby hub](lobby-hub.md); the problems and fixes behind it are in [lessons](lessons.md).

## Status

**Confirmed by the owner, 2026-11-03:** "Looking perfect." The mountain and slug exhibition area is marked complete. The next piece is the shop, in a new chat.

| Area | State | What's in it |
| --- | --- | --- |
| Centre | Built | Spawn rock, four rope bridges and runestone gateways, the Maelstrom whirlpool |
| Above | Built | Ceiling, Sky Well, storm and rubble tornado |
| Portal side | Built | Three portals, Titan's Arch, the volcano, cracked lava floor |
| Slug side | **Complete** | Slug Grove: mountain, stream, pond, mushrooms, plants, crystals, Floppies |
| Gun side | **Next** | Still the block-out's shop box |
| Far side | Open | The spiral route and cave entrance were removed; what replaces them is undecided |

"The four main areas" is the agent's grouping of the owner's "four main assets", from the table's first four rows.

## Playing it

`SlugshotLobbyHub` runs in first person with the game's settings, saved between sessions, and no guns or combat HUD (`LobbyFirstPerson.client.luau`). V toggles the camera and M opens settings. The temporary range, `python tools/build_combat_range.py`, has the latest movement, slugs, blaster and shooting.

## Decisions to keep

- **Slugs:** 1.3 studs outside the gun, with the in-gun size and 0.3 hit radius unchanged. The grove has 15 slugs, 10 Floppies and 5 Infernos (owner, 2026-11-03), one in four glancing at a nearby player.
- **Mountain:** one form of flat faces and hard ridges, from the owner's six reference pictures. Peaks are never tips added to a body. 165 studs tall and about 370 across, under the ceiling at 225.
- **Look:** thin black lines on ridges and valleys, cut-out shading, small broken facets. No rows or rings of lines, which read as a contour map.
- **Solid art:** you touch hidden collision chunks, not the drawn mountain, so it runs smoothly and its valleys stay open.
- **Stream:** thick and stuck to the rock, flowing over it with none poking through, out of a shallow rough cave. Not like the Maelstrom's free-falling sheets.
- **Whirlpool basins:** no splash rings on their pools. The foam at the foot of each fall stays.
- **Volcano and gate:** 85% height. The walls between the lava streams rise above the lava, slightly pointed.
- **Mushrooms:** the approved giant mushroom v2 at every size, in teal, green, purple and azure, at 30% glow, because more washes out the colour.
- **Plants:** the five approved designs: grass, broad plant, lanterns, moonbells, star lily.

## How to rebuild

Everything runs from the repository root. Python needs the venv with moderngl, numpy, scipy and scikit-image, and private assets stay in ignored `private-assets`.

| Task | Command |
| --- | --- |
| Build the place | `python tools/lobby/build_hub.py` writes `build/SlugshotLobbyHub.rbxlx` |
| Build with checks | Add `--check`. The run logs `HUBCHECK` lines and captures views |
| Rebuild a hub piece | `python tools/lobby/hub_mesh.py all <key>` |
| Rebuild a library asset | `sdf_mesh.py <key>`, then `blender_lobby_asset.py -- <key> [budget]`, then `paint_texels.py <key>` |
| Upload privately | `upload_hub_assets.py <keys>` and `upload_lobby_assets.py <keys>` |
| Move plants, trees, crystals, slugs or the stream | `python tools/lobby/grove_sites.py`, then build the place. No mesh rebuild unless the page's generated block changes |
| Phone estimate | `python tools/lobby/mobile_check.py` |

**Build order on the mountain:** `hub-grove-mountain` first, because `grove_sites.py` places things on its exported mesh and traces the stream down it. Then the pieces carrying sites: `hub-grove-solid`, `-falls`, `-rocks`, `-dress`. The same goes for `hub-grove-ground`, which plants stand on.

## Traps

- Renders and Studio checks max the owner's only GPU. Warn first and use `--gentle`.
- Long batches carry on after a failure. Read the log for tracebacks before trusting a result: one 13-minute batch left an old mountain and no plants.
- Heavy shader branches can make the driver paint the wrong material. Keep them behind markers, as `@mountain-paint` does.
- The `hub_run.ps1` log reader also sees other open Studio windows, so a warning may belong to another place.
- A cancelled tool call may still have started its process. Check before saying a render stopped.
- Never send global keystrokes to Studio.

## Open

- **Phone cost:** about 1.3M triangles and 270 MB of textures with the grove in view on desktop, against starting budgets of 200k and 100 MB. The estimate hasn't been re-run since before the grove. Lighter Floppies, fewer plants and baking small props together are the likely savings. This has to happen before the real phone and iPad tests.
- **Not tried by hand:** running and climbing the mountain, the pond's splashes at real speed, the slugs' hopping and glancing. Collision stands up to 13 studs above the rock at one tested point.
- **Inferno:** 5 grove slugs are Inferno, built 2026-11-03 on `lobby/grove-inferno`. Awaiting the owner's look in Studio.
- **Far side:** undecided. The bounty board is still block-out, and other biomes aren't designed.
- **Log noise:** `Failed to upload TexturePack` recurs with several Studio windows open, and isn't traced.

## Next: the shop

The owner called it the "shop bar" on 2026-11-03. The plan on record is a walk-in shop on the gun side at -90 degrees, radius 190, about 50 by 40 studs and 18 tall ([layout](../../experiments/lobby/scale/shared/layout.json)), with a [slug workshop](lobby-assets.md) beside it that must not look like a real blacksmith's forge. A browser concept already exists from another chat: [The Burrow Exchange](general-shop.md), a pod-grown shop over a mist chasm, on its second study. Read it first. **Unresolved:** whether "bar" means a shop counter or something new, and whether that concept is still the direction, so ask first. Get reference pictures before the first build, and show visibly different options if a shape misses.

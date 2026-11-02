# PvP UI

The match HUD, inventory, settings and keybinds. **Confirmed by the owner, 2026-11-02:** the design below, reached over several rounds of play; individual values remain open to tuning. Code: `experiments/combat/client` and `experiments/movement/client/Keybinds.luau`. Art: `tools/ui/build_goo_art.py` writes `assets/source/ui/goo`; `tools/ui/upload_goo_art.py` uploads privately and writes the IDs to ignored `private-assets/ui/GooArt.luau`, which every private project mapping the combat client must also map.

## What the owner chose

- **Look:** "Steady Ink": Oswald titles over Nunito text, ink outlines, no tilted or floating comic elements. The match HUD uses the neutral **Moonlight** accent, chosen because it sits beside any slug. The settings menu has a colour per tab (crystal teal, goo lime, amethyst) on deep indigo. Above all it must feel like Slugterra, with original art only.
- **Slug bar:** bottom centre, raised 36 px, **five** slots (`Combat.SlotCount`), 13 slugs in total (`Combat.SlugTotal`).
- **Health bar:** top left under Roblox's buttons, as dripping goo with a number beside it. The number can be Always, On change or Off. Hover cannot be used for it: the cursor is locked in first person and shift lock.
- **Settings:** a small cog beside Roblox's buttons, with no coloured outline on hover. Tabs: Controls, Gameplay, Crosshair.
- **Inventory:** E. A small panel expands up out of the slug bar, which is the loadout. Choosing which slug sits in which slot comes with the second slug.
- **Sprint:** Toggle by default, with Always on and Hold; double-tapping any direction also sprints.

## How the goo stays smooth

Roblox snaps UI to whole pixels, so slow `Position` and `Size` changes step visibly (the owner: "0.5 frames a second"). `ImageRectOffset` is not snapped, so `Goo` resamples textures instead:

- **Surfaces** are thin columns reading a wavy texture at any fraction of a pixel, moved by a small ripple simulation so a hit travels along the liquid. No rotation and no `CanvasGroup`: an ink 9-slice over the liquid rounds its corners.
- **Drips** play a rendered flipbook in which a drop swells, necks, pinches off and falls, then the rest recoils. A drip rides the edge above it and is one shape with the goo. With no goo above it, it pulls back up and fades.
- **Numbers shared** between `build_goo_art.py` and `Goo.luau` are marked SHARED.
- **Cost:** slider liquid and header goo only run while visible. Column widths trade detail for cost.

`GooBar` builds the health bar and, without drips or the red lost-health flash, the settings sliders, whose end never passes the knob.

## Controls

`Keybinds` holds every action, with a main and second binding, for the session. **Roblox exposes Left, Right, Middle and the wheel, but no usable side mouse buttons** (no forward code, `MouseBackButton` deprecated, staff call MB4/MB5 low priority). Players map side buttons to keys in the mouse's own software, and F13 to F15 are labelled Side 1 to 3; the owner has not confirmed F13/F14 on their mouse. Recheck the API before keybind work. Settings do not yet save between sessions.

## ADS charge kicks

Every kick used to scale to zero while aiming, leaving a slow zoom that the owner felt as "a bow and arrow charge". Each step now uses only motion that cannot move the aim: a view roll about the crosshair, an eye shove along its line, the gun jumping back along its barrel, and the sight frame punching and flashing, with its line thickening per step. The view tighten clicks in steps. Values are `adsStep*` in the Studio tuning panel (P). **Unresolved:** the owner's feel verdict; charge sounds, which do not exist yet.

## Checking it

`python tools/build_pvp_ui_check.py`, then `tools/studio/pvp_ui_check.ps1 -OutDir <dir>`, opens its own Studio window, presses Play, sends a real E, captures the health bar through three hits, the inventory and all tabs, then closes that window. It takes under a minute and needs no Studio MCP. It captures stills only and does not drive the mouse, so hover, dragging and feel remain the owner's judgement.

## Taste rules from the owner's feedback

No halftone dot backgrounds ("never do that"). No thin glowing lines passed off as cracks. Hover grows by a few pixels with its shadow and never covers a neighbour. No whole-row highlights. Slot and menu slugs perform (wiggle, hop, smile) and never spin. See [lessons](art/lessons.md) and [owner design language](slugs/owner-design-language.md).

## Loadout controls and inspect (2026-11-02)

**Confirmed/implemented:** 1-5 and the wheel select carried slugs; V toggles first person, R inspects. All are rebindable in the existing settings. The selected slot drives firing and the bar, with independent cooldowns. See [implementation, native checks and remaining limits](loadout-controls.md). This supersedes earlier notes reserving wheel input for zoom or deferring slot selection.

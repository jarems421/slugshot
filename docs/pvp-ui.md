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

`Keybinds` holds every action, with a main and second binding, with saved preferences restored asynchronously. **Roblox exposes Left, Right, Middle and the wheel, but no usable side mouse buttons** (no forward code, `MouseBackButton` deprecated, staff call MB4/MB5 low priority). Players map side buttons to keys in the mouse's own software, and F13 to F15 are labelled Side 1 to 3; the owner has not confirmed F13/F14 on their mouse. Recheck the API before keybind work. Settings persistence is implemented; the real cloud-backed rejoin remains unverified. See below.

## ADS charge kicks

Every kick used to scale to zero while aiming, leaving a slow zoom that the owner felt as "a bow and arrow charge". Each step now uses only motion that cannot move the aim: a view roll about the crosshair, an eye shove along its line, the gun jumping back along its barrel, and the sight frame punching and flashing, with its line thickening per step. The view tighten clicks in steps. Values are `adsStep*` in the Studio tuning panel (P). **Unresolved:** the owner's feel verdict; charge sounds, which do not exist yet.

## Checking it

`python tools/build_pvp_ui_check.py`, then `tools/studio/pvp_ui_check.ps1 -OutDir <dir>`, opens its own Studio window, presses Play, sends a real E, captures the health bar through three hits, the inventory and all tabs, then closes that window. It takes under a minute and needs no Studio MCP. It captures stills only and does not drive the mouse, so hover, dragging and feel remain the owner's judgement.

## Taste rules from the owner's feedback

No halftone dot backgrounds ("never do that"). No thin glowing lines passed off as cracks. Hover grows by a few pixels with its shadow and never covers a neighbour. No whole-row highlights. Slot and menu slugs perform (wiggle, hop, smile) and never spin. See [lessons](art/lessons.md) and [owner design language](slugs/owner-design-language.md).

## Loadout controls and inspect (2026-11-02)

**Confirmed/implemented:** 1-5 and the wheel select carried slugs; V toggles first person, R inspects. All are rebindable in the existing settings. The selected slot drives firing and the bar, with independent cooldowns. See [implementation, native checks and remaining limits](loadout-controls.md). This supersedes earlier notes reserving wheel input for zoom or deferring slot selection.
## Saved settings (2026-11-02)

**Confirmed:** the owner requested saving every setting, safe handling of missing/old/invalid data, and actual Roblox test records. `docs/MVP-UI.md` was not present; this is the existing UI specification.

**Implemented:** all twelve preferences (field of view, look/aim sensitivity, recoil, holster, health number, sprint mode/double tap, crosshair style/custom colour/size, flip camera), plus both keybind slots for every action, now use server-owned versioned DataStore saves. Cleared slots and Reset to defaults persist. Defaults repair missing or invalid fields; unversioned saves migrate; future versions are preserved without writes. Failed loads never replace saved preferences with defaults. Saves retry and flush on leave/shutdown; session leases prevent stale overwrites. Menu status shows whether settings are saved or unavailable. [Architecture](decisions/0021-player-settings-persistence.md).

**Implemented/verified offline:** `python tools/verify_combat.py` includes foundation and movement checks; formatting, lint, strict types and both combat place builds passed.

**Implemented/verified in Roblox Studio:** `python tools/build_settings_check.py`, then `powershell -NoProfile -File tools/studio/settings_check.ps1 -OutDir build/settings-evidence`. Dedicated test place only: real client/server load, early edits retained, custom colour and flip camera restored, bindings/clears/reset, save status and production PlayerRemoving flush/release. Real schema/store code passes JSON-backed simulated session reopen, all twelve values and both slots, defaults, legacy/corrupt data, duplicate inputs, future-version preservation, injected storage failures/retry, expired leases and stale-session rejection. Tests use injected storage, not Roblox cloud data. [Recorded evidence](evidence/2026-11-02-settings-persistence.json).

**Unresolved:** real cloud-backed rejoin; Studio MCP returned no sessions, and the owner allowed skipping this check for now. No publishing or Studio API/security changes. To finish acceptance in an existing authorized published test experience: change every preference, set a custom colour, change main/second bindings and clear one slot, wait for ?Settings saved?, leave/rejoin and verify UI plus actual controls/camera/crosshair. Repeat after Reset to defaults. In Studio, an authorized published test place with API access uses the separate Studio store; unpublished local files cannot demonstrate cloud saving.


## Settings repair and persistence limits - 2026-11-03

**Implemented/verified:** close X and double-tap checkmark are built with `utf8.char`, fixing corrupted UTF-8 text. Unpublished Studio previews show an honest session-only storage message, preserving early edits through retry/recovery. Settings lease acquisition handles conflicting UpdateAsync retries and checks actual token ownership. Native account isolation, failed-load recovery, all menu values/bindings and leave flush pass using injected storage. [Evidence](evidence/2026-11-03-settings-and-final-review.json).

**Unresolved:** actual cloud-backed leave/rejoin. A minimal private test place is prepared, but publishing a test experience and enabling Studio API access need owner permission. Local preview status does not mean preferences are saved across sessions.


**Implemented/verified, 2026-11-03 - real persistence:** owner-approved private settings-only experience passed actual cloud save, normal leave/release and fresh Play rejoin for all twelve preferences and both binding slots. Cold-start requires now wait for replicated children. [Evidence and scope](evidence/2026-11-03-settings-cloud.json). This supersedes the unresolved cloud test above; local unpublished previews remain explicitly session-only.

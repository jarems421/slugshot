# Inspect pose revision — 2026-11-02

**Confirmed:** owner rejected the first inspect as “horrible”: the gun was positioned incorrectly in both hands/views. First requested a readable side inspection based on pistol games, then clarified that the barrel should point upward in line with the raised arm, with the whole arm/gun angled diagonally back toward the holder. Floppy should hop, look at the holder, turn and wiggle before a smooth lower. This clarification governs the revision.

## Implemented

- A 5.8-second sequence: eased raise (0–0.85), hop/anticipation (0.82–1.65), look/smile, turn (2.65–3.3), wiggle (3.3–4.25), settle (4.15–4.75), lower (4.85–5.65). Joins ease to rest. Firing, aiming, switching and menus retain their existing interruptions.
- The barrel points up and slightly toward the camera. The first-person arm is solved through the actual grip joint, and that same rendered arm drives the gun. Removed the separate final gun placement that could separate it from the hand. Added a small inspect-only grip inset so the pistol is seated inside the block hand.
- The palm pivot and Tool.Grip remain fixed. Wrist rotation takes place at that pivot. The third-person shoulder remains attached to the torso; its raised diagonal pose accounts for the single rigid R6 arm.
- The raised barrel already stands Floppy nearly upright. His whole loaded model hops and turns through its existing cosmetic welds; face/head motion stays with the current bone drivers. A coherent basis derived from the actual eye/head facing avoids reversing the visible side. No mesh, weights, materials, Blender source or uploaded asset was changed.
- Loaded attachment rest frames are cached and restored after inspect/holster so a moved pose cannot become the next equip's baseline.

## Review method and failed attempts

The rejected baseline was preserved at commit `078c191` and in `build/inspect-v2/checkpoint`; its contact sheet is `build/inspect-v2/rejected-sheet.png`. Early revision sheets exposed an arm entering from above, an R6 pose lifted over the head, and Floppy hidden behind the gun's panels. These were rejected internally, not treated as successful because assertions passed. The owner's later upward-barrel clarification resolved the pose direction and gives Floppy a clearer standing silhouette.

Reference inspection was read-only: [USP-S side-inspect screenshot in an EsportFire recap](https://esportfire.com/article/market-recap-csgo-01082022) and [Riot's weapon-animation design discussion](https://playvalorant.com/en-us/news/dev/the-craft-and-fantasy-of-valorant-weapon-skins/). No game asset or animation was downloaded for reuse. The linked YouTube showcase could not be opened; it was not claimed as watched. The final orientation follows the owner's explicit upward pose rather than copying the reference screenshot.

`python tools/build_loadout_check.py --inspect-review` maps a disposable frozen-beat reviewer. It samples eleven times in each view and waits for a screenshot acknowledgement, preventing log polling from capturing a later pose. It checks the unchanged grip/palm pivot, first-person barrel/arm alignment (dot product >0.97 during the held pose), and actual head travel relative to the handle. This replaces the earlier weak test that only checked a non-identity bone value.

Screenshots/contact sheets and sanitized results are linked from [the revision evidence](../evidence/2026-11-02-inspect-revision.json). Normal projects do not map either review fixture. The ordinary loadout check still exercises actual server requests, wheel/keys, cooldowns, interruptions, rebinds, respawn and holster cleanup.

**Unresolved:** owner art/feel approval, multiplayer observer/latency coverage, and non-desktop devices. These checks do not establish that the owner likes the pose or the animation timing.

**Implemented/verified:** final frozen-beat review passes all 22 captures, fixed palm/Tool.Grip and held-pose barrel/arm alignment assertions. Actual head movement relative to the handle is about 0.244 studs. The ordinary native loadout test passes, including holstered attachment restoration; combat/foundation/movement and creature offline checks pass. The contact sheet was visually reviewed; its one difference warning crosses the first/third-person camera cut and is not an animation continuity claim. Final captures: `build/inspect-v3/delivery`, contact sheet: `build/inspect-v3/contact-sheet.png`, functional check: `build/inspect-v3/regression`. The existing art baseline is preserved.

## Final lean and spin follow-up (2026-11-02)

**Confirmed:** owner requested only a slightly stronger left lean and a slow spin while raising, then corrected the lowering request to include a spin on the down-flick too. Floppy's reaction stays as agreed.

**Implemented:** held barrel lean is about 9 degrees farther left. A forward 360-degree twirl spans the 0.85-second raise; the reverse 360-degree twirl spans the 0.8-second lower. Both ease into the seated held/rest poses. The flourish uses the accepted draw/holster trigger-guard pivot, with clearance from the forearm and a small first-person carry lift. It is applied after pose interpolation, using an unwrapped angle so quaternion interpolation cannot erase or reverse half the turn. The arm target removes only the flourish; the visible gun retains it, allowing the arm to carry the raise while the gun spins. Tool.Grip/C1 remains unchanged. The temporary toss offsets clear back to zero before the reaction and after lowering.

Verification and captures: [lean/spin evidence](../evidence/2026-11-02-inspect-spins.json), `build/inspect-v4`. Thirty frozen poses cover both transition spins and both views; the native loadout regression and combat/foundation/movement checks remain the technical gates. **Unresolved:** owner verdict on the final timing/feel; multi-client and device coverage.

**Visual refinement:** the transition twirl rolls about the barrel through the trigger-guard pivot, keeping the muzzle clear of the forearm. The earlier end-over-end trial swept the muzzle through the arm and was rejected before delivery.

**Implemented/verified:** 30 final frozen poses pass in Studio, including full-turn/end-state assertions and alignment through the unchanged reaction. The contact sheet was reviewed (`build/inspect-v4/contact-sheet.png`); spin and camera-cut differences are intentional. Native loadout regression passes; combat/foundation/movement checks pass, with final visual-axis/clearance refinement additionally checked by native review, formatting and lint. Final captures are under `build/inspect-v4/twirl`. Owner timing/feel approval remains open.

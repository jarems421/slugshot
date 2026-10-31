# Slug shooting (experiment)

Started 2026-10-31 on `experiment/rocklock-unified`. Code: `experiments/combat` (shared settings and flight model, server authority, client input/visuals/HUD, and the temporary range). Checks: `python tools/verify_combat.py`; runtime self-test lines (`[CombatSelfTest]`) appear in the Studio log when the range runs.

## Confirmed (owner, 2026-10-31)

- Every slug shares one shot: tap fires at a decent speed; holding charges for more speed, an earlier transformation and less drop. Standard slugs always transform (later slugs); no failed transforms for now. Floppy is the weakest slug and never transforms.
- Floppy: 5 damage against 100 base HP, a comedic splat, no knockback. It flies slowly, droops and does not travel far.
- Ammo: a cooldown from the moment of firing is the only reload rule (proposed 1.5 s). After impact the slug recovers and hops back quickly; if the cooldown ends first it puffs away and counts as back. Frictionless, fast-paced and easy to track.
- The current map is a placeholder, not a source of truth. The target range is explicitly temporary.

## Implemented

- Shared closed-form flight (gravity plus linear drag) so client and server compute identical arcs. The shooter sees the shot instantly; the server re-checks it (blaster equipped, cooldown with 0.15 s tolerance, muzzle within 6 studs of the torso, request rate), flies it, decides hits, applies damage and broadcasts shot/impact to all clients. Ammo is built as slots with one slot (Floppy).
- Client: hold LMB/R2 to charge (meter under the crosshair), aim through the cursor (the crosshair when shift-locked), the gun arm points along the aim while charging and briefly after firing, the canister empties until the slug is ready, a cooldown slot HUD, damage numbers with shot distance and a hit marker.
- Temporary range (`combat-range.private.project.json`, built by `tools/build_combat_range.py` to `build/SlugshotTempRange.rbxlx`): distance lines every 10 studs, six dummies from 10 to 80 studs, a strafing dummy and a raised one. Each shows HP, the last hit (damage and distance), session damage, hits, DPS and the player's live distance. The unified Rocklock place also includes shooting.

## Proposed (tuning, owner playtest)

Floppy launch 55 (tap) to 100 (full) studs/s, gravity 70, drag 1.2, hit radius 0.3, 2 tumbles/s, 0.55-stud flight size; full charge 0.8 s; splat 0.25 s; hop-back 0.5 s in 1–3 hops. All in `experiments/combat/shared/init.luau`.

## Unresolved

Feel and readability in play; shot behaviour under real network latency (the server starts the flight on receipt, without rewinding); multi-player hits; transformations, other slugs, slot switching, death/round rules, sounds and final effects art.

## First person and settings (2026-10-31)

**Confirmed (owner):** Rivals-style first person reached by scrolling in, not a setting; visible hands and gun that look clean and active; the player must feel their legs moving, not a floating camera (and not through added screen shake). A Settings panel holds the FOV and the hip/vanish holster choice (the K key is gone).

**Research basis:** weapon sway is the main signal of a physical body behind the view (look-driven lag that settles on springs); bob must be tied to movement state with separate sprint values; weapon size is usually kept independent of the camera FOV; floating cameras come from synthetic motion that is not tied to a body, while "true first person"/full body awareness attaches the view to an animated body (camera on the head, dampened) and shows the lower body. Sources: mocaponline.com first-person animation guide, Roblox DevForum viewmodel threads, Game Developer on Apex Legends first-person animation, gamedev.net/Unreal forum true-first-person threads, GiantBomb "Full Body Awareness".

**Implemented/verified offline:** `experiments/movement/client/FirstPerson.luau` snaps between third person (7-18 studs) and first person (0.5) on the scroll wheel. In first person the movement camera drops the shoulder offset and synthetic bounce and follows the animated head's motion relative to the body (after a slow baseline; `Config.Camera.FirstPerson`), the legs stay visible, and the real gun and hip copy are hidden. `experiments/combat/client/Viewmodel.luau` draws both arms and a copy of the gun, scaled with the FOV setting to keep its on-screen size: look sway on springs, lag behind the camera's body-driven motion (so footfalls and landings reach the hands in step with the legs), strafe lean, jump lift/landing dip, lowered sprint carry, charge wind-up, recoil, a flip draw, and shots leave its muzzle. `Settings.client.luau`: Settings button or M; FOV 60-110 (sprint/slide kicks stay relative); holster On hip / Disappears; session-only.

**Unresolved:** owner feel check; footstep sounds synced to the feet (a known contributor to grounded movement, not built yet); settings persistence; gamepad/touch first-person entry.

### Actions in first person (2026-10-31)

**Confirmed (owner):** the pistol is one-handed (the two-handed hold read as inconsistent); flips, wall runs and slides did not feel like them in first person, and the legs crossed the face during flips.

**Research basis:** Mirror's Edge spins the camera with the character through its roll (reviewers call it disorienting but it sells the move; visible limbs convey momentum); Titanfall 2 tilts the view on wall runs, which its designers said "immediately made it feel much better" (recreations use about 7.5 degrees, eased); slides drop the camera and kick the FOV. Sources: Game Developer (Titanfall controls interview), Engadget/Joystiq and wurb.com on Mirror's Edge, a UCSD course recreation of Titanfall constants.

**Implemented/verified offline:** one-handed viewmodel. In first person the flip turns the view exactly as the body's flip turns the head (relative to its rest on foot), wall runs roll the view 10 degrees away from the wall, slides lean back 3 and roll 4 degrees, all eased (`Config.Camera.FirstPerson`, applied after the camera scripts). The gun tucks in through flips, cants on wall runs and slides. Legs hide during flips, wall runs, wall hops, mantles and vaults and stay visible on foot and in slides. **Unresolved:** owner feel check (flip comfort, roll direction and size).

### Action view fix, running arms and gun-side wall runs (2026-10-31)

**Confirmed (owner):** a first-person flip spun the screen many times and landed looking at the ground; slides forced the view to the sky; arms (left and gun) should move as in the run animation and stay visible through flips with the legs; with the wall on the gun side, what does the gun hand do?

**Cause and fix (implemented/verified offline):** Roblox's camera scripts read the camera's orientation back each frame, so the flip turn and slide lean added after them compounded. The addition is now removed first thing every frame (`SlugshotActionViewUndo`, RenderPriority.First) and re-applied after the camera scripts. The viewmodel now has a left arm driven by the real left arm's rotation relative to the torso (x1.3, swung from just below the view so each forward swing brings the hand into the bottom of the screen), and the gun takes 30% of the real gun arm's swing about a shoulder off view. Legs stay visible through flips and wall runs and fade only near the eye. With the blaster out and the wall on the gun (right) side, the gun hand holds the gun forward instead of reaching for the wall and the left arm swings out for balance (Presentation, third and first person). **Unresolved:** owner feel check.

## Open issues and next steps (handoff, 2026-10-31)

Owner verdict after the last build: sliding is fine and wall running is almost perfect. Two problems remain, not yet fixed:

1. **First-person flips feel choppy.** The view still jolts during a flip; the crosshair flies around, aiming is hard and the experience is unpleasant. The view currently follows the animated head's full rotation (`flipWeight`, `viewTurn` in `experiments/movement/client/init.client.luau`). Likely directions: follow only part of the flip rotation (e.g. a pitch dip and recover), smooth the head rotation (it carries clip keyframe jitter and neck motion), and keep the crosshair/aim stable through the flip.
2. **First-person arms look elongated at every FOV.** The owner wants them to look exactly like the third-person R6 arms. The viewmodel arms are 0.45 x 2.3 (gun arm) and 0.42 x 1.9 (left arm) blocks close to the camera (`experiments/combat/client/Viewmodel.luau`); use true R6 proportions (a 1 x 2 x 1 block, scaled as one) and check the perspective at 60-110 FOV.

Everything else in this file is implemented and verified offline only; feel is the owner's playtest. Test place: `python tools/build_combat_range.py` builds `build/SlugshotTempRange.rbxlx` (temporary range); `python tools/verify_combat.py` runs all offline checks.

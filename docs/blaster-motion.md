# Blaster draw and holster — 2026-10-31

**Confirmed:** owner requested brief, expressive gun-only draw/holster gestures inspired by Slugterra: wrist twists/twirls, no airborne throws or body spins, convenient during play and fitted to the Roblox hand. Reload, firing and slug performance are outside this pass.

**Implemented:** original 0.42-second draw (outward wrist roll, controlled reverse flourish, small settle) and 0.34-second holster (reverse wrist turn and arm tuck; disappears by 0.27 seconds). Six rotation channels use bounded cubic interpolation. No root/camera movement, input lock, gameplay delay or uploaded animation IDs. Motion is driven by elapsed time rather than frame count.

The real gun stays on the native RightGrip joint while drawing. Rotation is about the grip, preserving palm contact; shoulder motion is an additive layer over the existing carry/locomotion pose. The local holster clone retains meshes, skinned bones and PBR materials, follows the hand, and removes executable scripts, joints and lights. It is cosmetic, anchored and non-colliding. Rapid re-equip cancels the prior visual; character death/removal restores owned pose layers and destroys the clone. Every client observes equipped tools for peer presentation; multiplayer timing remains unverified.

The standalone Floppy lab and Rocklock use identical `BlasterAnimator`/`BlasterMotion` modules. The existing Rocklock full-spin draw is suppressed only for tools marked with the new driver attribute; G hold-style selection remains. Foundation, terrain, movement physics and private clip data are unchanged. R6 and Motor6D-based R15 joint names are supported; constraint-only shoulder rigs skip the shoulder layer and need separate validation.

## Research and provenance

- [Official Slugterra/WildBrain Slug Fu trailer](https://www.youtube.com/watch?v=nK5LElj5EqQ) and [official Shout! Kids trailer](https://www.youtube.com/watch?v=SQJkbnRXgQY) were located as style references. Download attempts returned unavailable; specific shots or timings were **not observed or copied**. The poses/timings above are original interpretations of the owner's brief, not a reconstruction of show choreography. No downloaded reference or third-party motion is committed.
- [Roblox Tool API](https://create.roblox.com/docs/reference/engine/classes/Tool) informed native Handle/Grip and equip lifecycle integration. No custom replacement character controller is installed.

## Evidence and limits

**Implemented/verified offline:** foundation/creature checks, strict Luau/format/lint and movement checks pass. Rocklock public/private builds and v2 verification pass. `tools/r6pose/preview_blaster.py` reads the actual shipped numeric Luau keys, renders a block-R6/gun-bounds contact sheet, and checks 1,001 samples per gesture. Numerical palm-position error is below 1e-12 studs; endpoint sampling at 30/60/144 steps per second reaches the intended terminal pose/visibility. These are a Python numerical approximation, not execution of the Luau sampler or actual rendered-frame-rate tests. The reviewed bounds show a compact flourish near the right arm; boxes do not establish final mesh/body clearance or art approval.

Ignored evidence: `build/blaster-motion/{r6-contact-sheet.png,numerical-report.json}`, `build/blaster-motion-slug-checks.log`; Rocklock logs are in that worktree's `build/blaster-motion-*-checks.log`. New private test build: `build/SlugshotFloppyTest-GunDrawHolster.rbxlx`.

**Unresolved:** actual Studio visual quality, R15/constraint rig behavior, rapid-switch/death cleanup, peer presentation, movement overlap and final owner art approval. Test Play → hotbar 1 to draw → 1 to holster; repeat quickly, while running/jumping, and after reset. In Rocklock, compare G carry styles. Confirm palm contact, no duplicate gun or stuck pose, material retention and no new Output errors. Existing gun lighting/art gates remain separate.

**Confirmed Studio launch limit:** the new process reported that the maximum allowed Studio windows were already open. Only that failed-launch dialog was dismissed; all eight earlier Studio sessions were preserved. The new place was built but could not be opened in another window; no runtime pass is claimed.

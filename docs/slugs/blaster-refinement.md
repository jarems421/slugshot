# Angular blaster and steady-visibility pass (2026-10-31)

## Confirmed brief and feedback

The owner asked for a less toy-like gun, a little more shortening of the grip and barrel, a white glowing spiral/dial behind the canister, and investigation of the recurring interior/pedestal lighting dropouts. Slug animation changes are deferred.

The owner approved the first compact burnt-orange/graphite render. The first sharp-tip variant flared upward and was explicitly rejected: points must slope **down**, preserve the central firing gap and keep the present barrel reach. The owner further requested an angular rather than smooth appearance. The final construction cuts planar downward bevels into the two muzzle prongs; it does not bend the prongs. Rejected renders and the approved rounded finish remain in ignored build checkpoints.

## Implemented

- Existing orange identity retained with a burnt-orange housing, graphite body/grip, restrained steel accents and white emitting spiral vanes over a recessed dark dial. Native Roblox materials distinguish metal, grip and luminous inserts. Blender materials are a controlled preview, not proof of identical Roblox lighting.
- Grip vertical profile is 0.70 of the original (previous revision 0.82); the existing 0.88 overall gun multiplier stays. The forward barrel section is shortened by 10%, roughly 0.1 stud overall, before the small muzzle bevels. The chamber/slug fit is recomputed from the new mesh bounds.
- Both muzzle tips have solid, planar downward bevels. Cut-perimeter vertices are welded and triangle-filled so the caps remain solid. Broad panels use weighted normals and sharp chamfers; the canister/dial retain their functional curves. Nine sample firing-channel paths are clear after the bevels. This is a visual channel check, not a firing mechanic.
- Added a low, albedo-modulated emissive floor to the existing explicit Floppy PBR templates (0.08 pedestal, 0.16 loaded), preserving colour rather than applying a white Highlight. It provides constant material visibility independently of local-light selection. [Roblox emissive material model](https://create.roblox.com/docs/art/modeling/surface-appearance).
- Replaced the gun's 0.75/3-stud lights with one dim neutral 8-stud PointLight; pedestal fill is shadowless with 12-stud range and lower intensity. Cosmetic gun parts do not cast self-shadows. Test-place ambient fill is modestly raised and bloom reduced (0.24 intensity, fixed 16 size, 1.25 threshold). No pulse, timer or animated light property was introduced. These changes target the reported dropouts; actual sustained rendering stability needs the owner's test.
- The matching Rocklock private mesh mapping and native fallback styling/grip were updated. Map geometry, movement and slug animation code were not changed.

## Evidence and limits

- `tools/slugs/refit_floppy_blaster.py` reproduces the mesh/finish from the existing private input. Original private input, prior uploaded models and rejected variants are retained. Final upload/mappings and the additional emissive mask ID stay private. No experience publication or security settings were changed.
- Side and three-quarter Blender views were rendered and inspected under fixed lights; the gun images/source stay in ignored build storage with the private input. Final geometry report: [channel and mesh counts](catalog/evidence/floppy/blaster-refinement/geometry-check.json).
- Generic asset QA was run: [raw report](catalog/evidence/floppy/blaster-refinement/mesh-audit.json). It reports no degeneracy, winding, scale or detached-part errors, but conservatively flags close/coplanar housing/bevel pairs. The raw report is **not a clean production QA pass**. A separate exact positive-area check on the pre-bevel sharp variant found zero actual coplanar-area overlaps for BodyGrey and one small Orange overlap (~0.000023 source units squared at the rear hardware), rather than all detector sample-pair counts being visible faults. Hard-normal seam duplicates, mechanical inset contacts and a grip-centred origin below floor zero are intentional. Rear contact/overlap cleanup remains a production gate, rather than silently deleting approved housing details during this art pass.
- `python tools/verify_slugs.py --blender` passed foundation/creature tests, formatting, lint, strict types and builds; the current Floppy rig/export baseline remains valid. Rocklock v2 `--skip-movement` verifier passed after the targeted native fallback update. No multiplayer, rendered frame-rate or new animation claim is made.
- The new Studio process initially stopped at its **Low System Resources** prompt with eight other Studio sessions open (16 GB host memory). That is confirmed resource pressure, not proof of the lighting cause. Existing unsaved sessions were preserved. The prompt subsequently cleared and `SlugshotFloppyTest-AngularBlaster.rbxlx` opened.

## Owner test

Use the new AngularBlaster window; Play, then hotbar 1. Check both downward tips, open firing channel, finish and grip, white coil and pedestal/loaded colours. Watch while stationary and moving for at least 30 seconds for lighting contraction/dropout. Material visibility is now independent of the local lights, but engine/GPU resource pressure and the final subjective look are not verified by offline builds. Slug animation is the next separately requested pass.

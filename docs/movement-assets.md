# Movement asset provenance

Acquired 2026-10-28. Restricted sources and all converted data/previews live under ignored `private-assets/`, outside every tracked Rojo mapping. No reusable third-party animation IDs or source pose data are committed.

| Resource | Official download | Bytes / SHA-256 | Audit |
| --- | --- | --- | --- |
| Cinderlore R15 Movement & Dash Sampler 1.0.1 | [Product](https://cinderlore.com/products/r15-movement-dash-sampler), direct `/downloads/F3` | 115392; `e4002d30fe1762d83622a26fb038624dcfc8ebc5e51f5accc4e9842b068630f3` | 6 clips, 145 keyframes; zero LuaSourceContainers; all six played and captured on R15 |
| Cinderlore R15 Combat Starter Motions | [Product](https://cinderlore.com/products/r15-combat-starter-motions), direct `/downloads/F1` | 172155; `1824d3d6126c5f444c0b4f01f2e7a079864e8b4fd03a5ab8619f32586e0c8209` | 7 clips, 218 keyframes; zero LuaSourceContainers; GuardReaction played and captured |
| Original procedural movement study (v1) | Commit `e2b5688`, `experiments/movement/client/Presentation.luau` | Original source, no imported clip/ID | Runtime-verified on the generated R15 rig; preserved as the v1 comparison build |
| Original keyframed clips (v2) | `experiments/movement/shared/OriginalClips.luau` | Original source, no imported clip/ID | Public; contact sheets and live captures inspected; see [results](movement-verification.md) |
| Place1 movement system, `ParkourTraversalController` | [Repository](https://github.com/alexkkork/place1-movement-system) at `87da75e2f2528291ebf65c4cbc52d1ce83c2f527` | Source reviewed; MIT, Copyright (c) 2026 alexkkork | Ledge/wall detection adapted into `experiments/movement/client/Traversal.luau` with the full MIT notice in the file header (ships in every build). No package, asset or script installed or executed |
| Original mantle and wall-hop clips (v3) | `experiments/movement/shared/OriginalClips.luau` (`MantleLow`, `MantleHigh`, `WallHop`) | Original source | Public; path-placed held frames inspected; see [results](movement-verification.md#v3-traversal-2026-10-29) |
| Blender 4.5.14 LTS (portable) | [Official release](https://download.blender.org/release/Blender4.5/), `blender-4.5.14-windows-x64.zip` | SHA-256 `b9533d2397ac1984db4466fb23a7a4649391cca93f6e84209f9bcc60d071c8b9` (verified against the published checksum) | GPL tool, unpacked in ignored `.tools/`; no installer, elevation or addons; runs only the reviewed retargeter |

The [Cinderlore licence](https://cinderlore.com/license), version 1.0 effective 2026-09-06, permits Roblox commercial use, editing and private project collaboration. It prohibits redistributing original/modified animation files in public templates/repositories and offering IDs as a reusable library. Changing file format does not remove those restrictions. A copy of the exact licence is retained privately. No signup/payment was required.

Offline inspection used the existing Rojo binary to convert RBXM to private XML without executing anything. Live Studio's LoadLocalAsset call lacked the required capability; no permission/security setting was changed to work around it. Instead, only reviewed Keyframe/Pose data was reconstructed for a temporary native Animator preview. No bundled script was executed. Preview rigs, temporary registered clip IDs and private data were not included in the built sandbox or retained in the edit place.

## Mixamo clips (owner download)

Mixamo requires the owner's own Adobe sign-in. Reposted copies of Adobe's Mixamo FAQ ([community](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400), [itch.io quote](https://itch.io/post/7747839)) describe royalty-free use in games, but no redistribution of raw character or animation files. Adobe's own FAQ page returned HTTP 403 to this review, so check its current wording when signing in. Treat downloads, conversions and generated data like the Cinderlore packs: private only.

**Status (2026-10-29):** the owner downloaded 49 clips into `private-assets/mixamo/`, keeping Mixamo's own file names. All 49 were mapped in v4. After the owner's playtest, v4.1 maps 48 runtime clips and no longer uses Neck Stretching, Strafing, Jump, Rifle Jump, Left Strafe Jump or Run Strafing Jump. `tools/mixamo_manifest.json` holds file names, trims and style options only, no animation data ([results](movement-verification.md#v41-owner-feedback-pass-2026-10-29)). Manifest flags added in v4.1: `mirrored` (flip in place), `amplitude` (hip/shoulder swing scale) and `elbows` (bend scale).

1. **Download settings:** FBX Binary, With Skin (the T-pose bind pose is required), 30 fps, no keyframe reduction. In Place is optional: the converter removes travel from loops. Save into `private-assets/mixamo/` with any file name, then add a manifest entry: runtime name (`Name.2` for a variant), file, and flags such as `loop`, `air`, `rootMotion`, `traversal`, `vault`, `trim`, `mirror` or `alignEnd`.
2. **Still wanted.** A missing slot keeps the original clip, or skips the feature:

   | Slot | Search Mixamo for | Why |
   | --- | --- | --- |
   | `RollBack`, `RollLeft` (right is mirrored) | back roll, side roll | back and side rolls are still original clips |
   | `RunBack` | running backward | straight back-pedal; currently blended from the two back diagonals |
   | `MantleLow` | climbing / step up (low) | a quick step-up onto waist height; still the original clip |
   | Running / sprint | fast run, sprint (long stride) | the owner dislikes the current run; a longer-striding clip would replace the restyled one |
   | `Jump` | jump (standing, in place) | the standing jump is derived from Running Jump; none of the downloads is a standing takeoff |
   | Wall-run loop | wall run (loop) | the wall-run pose is procedural; a looping clip could replace it |
   | Rifle locomotion | rifle idle / run / walk / strafe | only if the owner wants the gun-ready look while aiming (needs a grip decision first) |
   | Extra variants | second idle | the owner prefers fewer, consistent clips over many variants |
3. Run `python tools/build_movement_playtest.py --retarget`. The reviewed `tools/mixamo_to_r15.py` runs in portable Blender and writes `private-assets/generated/MovementClips.luau`, which is used by `build/SlugshotMovementLabPrivate.rbxlx` only.
4. Live (non-Studio) use would need the chosen animations published under the owner's account, plus a private ID mapping. This has not been done; ask first.

## Later owner-controlled use

Follow [the publisher's import guide](https://cinderlore.com/help/importing-r15-animations):

1. Insert the private RBXM into an isolated Studio place and open EditableClips. Keep it out of public Rojo mappings.
2. Load the chosen KeyframeSequence in a compatible editor on the actual R15 proportions; review pose, timing, root movement and blend transitions.
3. If you decide to use it, publish the edited animation under the account/group that owns the eventual experience. No animation/experience has been published by this task.
4. Keep resulting IDs in private project storage/configuration. Integrate an explicit private mapping only after choosing a clip; the public sandbox deliberately needs none.

Do not commit private download/converted/preview files, screenshots of these private trials, temporary IDs or an assembled place containing these clips. Public verification records contain only names, hashes and playback results.

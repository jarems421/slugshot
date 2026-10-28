# Movement asset provenance

Acquired 2026-10-28. Restricted sources and all converted data/previews live under ignored `private-assets/`, outside every tracked Rojo mapping. No reusable third-party animation IDs or source pose data are committed.

| Resource | Official download | Bytes / SHA-256 | Audit |
| --- | --- | --- | --- |
| Cinderlore R15 Movement & Dash Sampler 1.0.1 | [Product](https://cinderlore.com/products/r15-movement-dash-sampler), direct `/downloads/F3` | 115392; `e4002d30fe1762d83622a26fb038624dcfc8ebc5e51f5accc4e9842b068630f3` | 6 clips, 145 keyframes; zero LuaSourceContainers; all six played and captured on R15 |
| Cinderlore R15 Combat Starter Motions | [Product](https://cinderlore.com/products/r15-combat-starter-motions), direct `/downloads/F1` | 172155; `1824d3d6126c5f444c0b4f01f2e7a079864e8b4fd03a5ab8619f32586e0c8209` | 7 clips, 218 keyframes; zero LuaSourceContainers; GuardReaction played and captured |
| Original procedural movement study | `experiments/movement/client/Presentation.luau` | Original source, no imported clip/ID | Runtime-verified on the generated R15 rig; captured run poses inspected |

The [Cinderlore licence](https://cinderlore.com/license), version 1.0 effective 2026-09-06, permits Roblox commercial use, editing and private project collaboration. It prohibits redistributing original/modified animation files in public templates/repositories and offering IDs as a reusable library. Changing file format does not remove those restrictions. A copy of the exact licence is retained privately. No signup/payment was required.

Offline inspection used the existing Rojo binary to convert RBXM to private XML without executing anything. Live Studio's LoadLocalAsset call lacked the required capability; no permission/security setting was changed to work around it. Instead, only reviewed Keyframe/Pose data was reconstructed for a temporary native Animator preview. No bundled script was executed. Preview rigs, temporary registered clip IDs and private data were not included in the built sandbox or retained in the edit place.

## Later owner-controlled use

Follow [the publisher's import guide](https://cinderlore.com/help/importing-r15-animations):

1. Insert the private RBXM into an isolated Studio place and open EditableClips. Keep it out of public Rojo mappings.
2. Load the chosen KeyframeSequence in a compatible editor on the actual R15 proportions; review pose, timing, root movement and blend transitions.
3. If you decide to use it, publish the edited animation under the account/group that owns the eventual experience. No animation/experience has been published by this task.
4. Keep resulting IDs in private project storage/configuration. Integrate an explicit private mapping only after choosing a clip; the public sandbox deliberately needs none.

Do not commit private download/converted/preview files, screenshots of these private trials, temporary IDs or an assembled place containing these clips. Public verification records contain only names, hashes and playback results.

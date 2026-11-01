# Creating another species configuration

**Implemented:** JSON is the authoring source; generated strict Luau is the runtime projection. Read the [complete placeholder example](../../assets/source/slugs/species/placeholder.json). Do not edit `Definitions.luau` manually. Names use lowercase identifiers; the file stem and `id` must agree.

## Technical variants

1. Copy `placeholder.json` to `<test-id>.json`, change `id`, retain `placeholder: true`, and record original authorship/provenance. This creates a test configuration, not an approved character design.
2. Set protoform `size` to `[width, length, height]`, `headScale` and `eyeSpacing`. All sizes must be positive. Change `palette` and choose `solid` or `bands`; `organic-spots` identifies an authored mesh with its own vertex colours. The placeholder test bands are material-face assignments; production texture/pattern baking remains a separate art task.
3. Add/remove/replace features using named sockets. Use one `eye` on `face_center` for a one-eyed test. Horns, fins, antennae and ears can be positioned independently with `offset` and `scale`; no fixed feature count is imposed.
4. Keep the base rig ID for compatible variants. For a different topology, create a new rig JSON with ordered bones and named sockets and use authored sources. Do not change another species' source path. Shared rigs and clip conventions are intentional dependencies; other species' editable models are prohibited dependencies.
5. Configure `forms.transformed` with its own rig/model/actions. Alternatively set `transformation.enabled` to false and omit that form entirely. The disabled path never swaps rigs, even on impact.
6. Set transformation duration, rotation speed (turns per second), transition/reveal fractions, effect color and symbolic effect reference. Fractions specify visual staging, not damage timing.
7. Validate, compile, generate, export and review:

```powershell
python tools/slugs/cli.py validate-config --species test-id
python tools/slugs/cli.py compile
python tools/slugs/cli.py all --species test-id
python tools/verify_slugs.py
```

The default lab selects `placeholder`; use `Visual.new("test-id", options)` in an isolated test to select another compiled definition. The CLI's `compile` validates all registered species and deterministically regenerates the shared module. Missing config fields, sockets, palettes, rigs, required actions, transformed forms, unsafe source paths and out-of-range values fail early.

## Authored models and custom rigs

Future art uses `placeholder: false`, a real provenance statement, `generator: "authored"`, and a source such as `assets/source/slugs/models/test-id/protoform.blend`. The path must exist inside that species' source folder. A real rig's required bones, rest axes/positions and sockets live in its rig JSON. Validate a minimal source/FBX/Studio roundtrip before scaling up production.

The authored source must contain only the form's armature and skinned meshes. Apply object location, rotation and scale. Use the declared normalized rest skeleton at the specified body dimensions and export-ready weights. Name modular meshes after their feature IDs. Bake constraints into deform-bone keys and unsupported modifiers into an export copy. Actions use 24 FPS; action duration may vary. Looped action endpoint matrices must match to tolerance; every exported action must contain measurable motion. Static facial states should become pose data in a future explicit pose contract rather than empty animation clips.

The generator loads that file, validates it, and writes a separate editable build copy. It does not overwrite the authored original. This path validates/exports existing custom armatures; automatic retargeting from arbitrary rigs is not implemented. A new silhouette can use entirely different meshes while retaining compatible bones, or declare a new rig and override its animations.

## Slot conventions

| Form | Slots |
| --- | --- |
| Small | `idle`, `blink`, `breathing`, `happy`, `angry`, `surprised`, `hop`, `launch`, `spin`, `prepare`, `impact` |
| Transformed | `reveal`, `movement`, `attackStartup`, `attack`, `impact`, `recovery` |

`idle` is required for protoforms; enabled transformations require `reveal` and `attack` on the transformed form. Other slots are optional conventions. An omitted optional slot is not a missing required reference. Declared slots must point to existing source actions and match the form's rig ID. The initial generator authors only Idle/Launch/Spin/Prepare and Reveal/Attack as technical motion tests. Do not treat those motions as style decisions.

In source configuration an animation is `{ "rig": "protoform-v1", "action": "Idle", "loop": true }`. Species overrides change `action` and supply that action in the authored `.blend`. Roblox asset bindings are injected privately via `Visual.Options.animationIds[form][slot]` after authorized upload and permission review. They never belong in public JSON or the shared generated module.

## Materials and future effects

Palettes map material names to linear 0–1 RGB triples. Feature references must exist. Blender's placeholder materials use base color and roughness; sophisticated shaders and procedural textures do not automatically transfer to Roblox. The first sick/dizzy draft stores its green markings as vertex colours, verified through an offline Blender FBX reimport; actual Roblox import and appearance still need verification. Authored texture rights, UVs, PBR maps, color space and target appearance require independent import review. The effect string is resolved by the caller's `onEffect` callback; no asset is fetched by name. Future collection/inventory code can refer to the stable species ID without depending on renderer internals.

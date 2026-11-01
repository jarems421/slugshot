# ProtoformBase technical rig contract v1

**Confirmed:** this is an export/animation compatibility specification, not approval of a body shape, final model, face or animation style. `ProtoformBase` is provisional. The visible fixture is labeled `PLACEHOLDER`.

## Rest skeleton

The authoritative [protoform-v1 JSON](../../assets/source/slugs/rigs/protoform-v1.json) contains normalized bone-head positions and parent names. Positions multiply by form `[width, length, height]`. Root origin is at the floor under the body; local +Y faces forward, +Z is up in Blender. Every deform bone has zero roll and points +Z in rest; tails are 15% of body height with a 0.1-unit minimum. Object transforms are applied. Do not rename, insert between or rotate core bones in compatible variants.

| Bone | Parent | Purpose |
| --- | --- | --- |
| `root` | none | Common pose, launch, spin and whole-body deformation |
| `body_lower` | root | Lower-body bend and breathing |
| `body_upper` | body_lower | Upper-body bend and expressive motion |
| `head` | body_upper | Head motion independent of body |
| `jaw` | head | Basic mouth expression/pose slot |
| `tail` | body_lower | Flexible lower/rear extremity |

The placeholder body uses explicit normalized two-bone weights, blending tail/lower/upper by body length. Head and jaw meshes are rigidly weighted to their corresponding deform bones. Modules weight to the socket's parent bone. Validation rejects unweighted vertices, non-normalized weights, excessive influences, undeclared bones, wrong hierarchy/rest placement, unbaked transforms, unsupported modifier stacks and mismatched feature bounds.

Future expressive mouths can use jaw animation, replacement mouth modules or a separately verified facial rig. Blink, gaze, mouth poses and final deformation quality are not authored by this setup. Extending the skeleton requires a new rig ID and its own animation compatibility evidence; do not label an exceptional face or body `protoform-v1` to bypass checks.

## Sockets and anatomy

Sockets are named rest positions bound to a deform bone, independent of the number of visible features. `face_left`, `face_right`, `face_center` and `crown` follow the head; `back_left`, `back_right` and `energy` follow the upper body. Their coordinates are in JSON and the export report. Empty anatomy is allowed: eyes and horns are not mandatory. A one-eye variant uses `face_center`; it need not carry two visible eyes.

Features have a unique ID, primitive test kind (`eye`, `horn`, `antenna`, `fin`, `ear`), socket, local source-space offset, absolute test dimensions and material name. Feature position equals normalized socket position times body size, plus offset. Eye spacing scales socket X for eye modules. Head size is independently parameterized; feature offsets remain explicit so they can be fitted to unusual heads. An authored species can replace these simple modules with its own reviewed meshes.

The test mesh generators demonstrate the attachment contract; they do not constitute a final asset library. The runtime native fixture approximates all non-eye features with blocks. Blender uses cones for the horn/fin/ear/antenna test kinds. This difference is disclosed; inspect imported art separately.

## Animation compatibility

Shared clips require the same rig ID, hierarchy, names, rest axes and compatible channel semantics. The initial reusable actions are rotation/scale based with no locomotion translation. Parameter changes retain that rest-axis contract; extreme proportions still need deformation review. Translation-heavy future clips need normalization/retargeting evidence or species-specific overrides. Rig IDs are checked before Roblox animation binding; asset existence, permissions and actual clip content require Studio verification.

Each species maps semantic slots to action names and rig IDs. It may replace an action while retaining the same slot. A `.blend` may contain the reusable library actions plus overrides; each configured action is exported on its own. Compatible species can bind the same privately reviewed Roblox clip. No conversion through R6 or R15 is involved.

The transformed placeholder uses [expanded-test-v1](../../assets/source/slugs/rigs/expanded-test-v1.json): `root → core → crest`, and two `wing_*` bones under `core`. It intentionally has a different hierarchy and five bones instead of six. Transformation replaces the model and player. Real transformed forms can declare independent rig specifications and authored meshes/actions.

## Scale and animation limits

Blender bone local Y points along the authored bone, so its local channels differ from object/world axes. FBX exporter bone-axis correction is preserved; automatic bone reorientation is off for offline reimport. Rig and model rest coordinates, timing, looping endpoints and nonzero motion are measured after reimport.

Blender can animate bone scale; Roblox `Bone.Transform` is a CFrame, so imported nonuniform scale channels must be checked in Studio. Native fixtures demonstrate volume-preserving squash by resizing Parts and joint offsets. Imported skinned models use the renderer's `onDeform(model, amount)` hook for a tested species-specific deformation or an approved mesh/model swap. We do not claim arbitrary Blender squash channels survive Roblox import. See [runtime gates](studio-import.md).

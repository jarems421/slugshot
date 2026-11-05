# Slug skill routing

Decide what kind of work this is, then read only that row. Add a second skill only for a real cross-domain dependency. The [skill audit](skill-audit.md) has all 58 installed skills, their compatibility and when to avoid them; open it for an override or when a tool misbehaves.

| The task | Start with | Read | Prove it with |
| --- | --- | --- | --- |
| New slug concept | `slugshot-creature-production` | [Style guide](../art/style-guide.md), [catalogue template](catalog/template.md); a live 3D concept first | Owner's verdict on a rotatable concept |
| Slug modelling or sculpting | `el4cteo-blender-sculpting` (`slugshot-creature-production` for the procedure) | Slug's record | Front, side, back, three-quarter renders; `el4cteo-blender-asset-qa` |
| Local eye, mouth or antenna geometry | `roble3-blender-modeling` | Slug's record | Views at pose extremes |
| Face and expressions | `el4cteo-blender-facial-shapekeys` | Slug's record | Expression sheet; both mid-transition directions |
| Materials and textures | `el4cteo-blender-pbr-materials`, `el4cteo-blender-texturing` for marks | Slug's record | Fixed-light views; Studio check, since shading differs |
| Rig, weights, collapsing bends | `el4cteo-blender-character-rigging` | [Rig contract](rig-specification.md) | Weight report; stress poses |
| **New motion concept** | `slugshot-animation-director` | [Motion library](motion-library.md), slug's record | Three-way preview; owner picks one |
| **Blender keyframes or clips** | `el4cteo-blender-animation` | Rig contract, [lesson index](../lessons-index.md) | Loop and clip checks, FBX, Studio playback |
| **Procedural Luau motion** | `slugshot-procedural-animation` | The slug's motion script, [motion library](motion-library.md) | Verification scripts; [motion review](motion-review.md) in Studio |
| **Motion looks wrong** | [Motion review](motion-review.md); `roble3-animation-quality-gate` for Blender renders | Lesson index, by symptom | Name the failed dimension; watch it at 1× |
| Transformation | Director if new; `slugshot-procedural-animation` otherwise | [Transformation](transformation-system.md) | Shooter's view at real range, at 1× |
| Export or Roblox playback problem | `el4cteo-blender-export-pipelines` | [Studio import](studio-import.md) | Reproduce, reimport, actual Studio playback |
| Mesh too heavy | `el4cteo-blender-game-optimization` | Slug's record | Per-mesh budget; silhouette before and after |
| Environment | Lobby tools; `el4cteo-blender-environment-kits` only for terrain and kits | [Style guide](../art/style-guide.md), [lobby checkpoint](../art/lobby-checkpoint.md) | Library page first; Studio tour |
| Quality stays poor despite valid files | `roble3-quality-refinement-autoloop`, diagnosis only | Lesson index | Name the failure; try a different method on a variant |
| Blender error or corrupt geometry | `el4cteo-blender-core` | [Install audit](install-audit.md) | Reproduce, then a targeted check |

## Blender backends

Pick one and stay on it. Confirm the open `.blend` is the right one, and save a copy or checkpoint first. Never run two live backends or two agents on one scene.

| Backend | For |
| --- | --- |
| Blender 4.5.14 headless with `tools/slugs` scripts | Reproducible slug builds and export |
| Blender 5.2.3 headless | EL4CTEO recipes |
| BlendRelay (`mcp__blendrelay__*`) | A selected local edit in a live scene, with checkpoints |
| MCP for Blender (`mcp__blender__*`) | Live inspection and reviewed Python |

RobLe3's legacy tool names and OpenCV scripts do not work here; substitute only after a disposable test. Never run a scene reset on an existing scene. Optional external AI and asset services stay off.

Run `python tools/slugs/check_skill_routing.py` after changing skills or this page.

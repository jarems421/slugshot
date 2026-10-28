---
name: roblox-asset-pipeline
description: Review authorized Blender-to-Roblox assets, rigs, animation, VFX or environment workflows and their provenance.
---

# Asset and animation review

Read `docs/assets.md` and the relevant approved task. This skill supports future authorized asset work; it does not authorize building creatures, animations or environments during the foundation milestone.

Before touching assets, record ownership/license evidence and preserve editable source. Check current Roblox import constraints and the installed Blender version instead of copying generic engine limits. Do not copy franchise characters or assume a code repository license covers its example art.

For a rig or animation export, record unit scale, axes, root/bone mapping, rest pose, action names, timing and exporter settings beside the source. Bake constraints when required by the selected export format. Validate a minimal roundtrip in an isolated Studio place before generating a whole asset set. Inspect deformation, orientation, playback timing, loop seams and texture mapping in the target engine.

For VFX or cinematic trials, test on the target quality/device settings, check cleanup and review timing without coupling presentation to unapproved gameplay rules. Environment imports also need collision and resource-budget checks when real requirements exist.

Prefer Blender's local CLI or native Studio tooling when sufficient. A community Blender MCP can execute Python and import remote assets; review pinned source, dependencies, network exposure and optional service terms before proposing installation. Never run a remote installer or connect accounts as part of asset inspection.

Record only actual source/export paths and verified Roblox IDs in the asset register; keep proposed designs in the creature template or open questions.

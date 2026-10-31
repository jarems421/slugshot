---
name: slugshot-blender-orchestrator
description: Route Slugshot creature modelling, rigging, animation, rendering and export tasks to the smallest suitable Blender skill set and backend; record visual feedback and technical evidence.
---

# Slugshot Blender orchestration

Use for creature asset work in the isolated slug worktree. Read [routing and the full skill inventory](../../../docs/slugs/skill-routing.md), [current lessons](../../../docs/slugs/blender-lessons.md), and the relevant [species record](../../../docs/slugs/catalog/index.md). Read the selected third-party `SKILL.md` only when needed.

Identify the owner's requested change or the observed failure first. Preserve the current `.blend` and render evidence. Choose the minimum relevant skills, a backend that is compatible with the selected Blender version, and a disposable test when validating new tooling. Work on a checkpoint or separate variant for a risky edit. Prefer local geometry edits when a local feature is wrong; evaluate silhouette, anatomy and expression from front, side, back and three-quarter views before claiming improvement.

For reproducible creature builds and export, use the existing headless scripts and Blender 4.5.14 selection. For EL4CTEO 5.2 workflows, select the separately installed Blender 5.2.3; its upstream test suite passed, but check a selected recipe on a disposable source before applying it to a creature. For selected mesh edits, use BlendRelay after a verified connection. For live Python or RobLe3 recipes, use MCP for Blender (`blender`). Run only one live editing backend on a scene at a time. Optional external asset and AI model services remain off.

Run the relevant Blender/source/export checks and the isolated Studio checklist when target-engine behavior matters. A passing script, render or FBX reimport is not owner art approval or Roblox playback. Preserve accepted iterations, update `docs/slugs/blender-lessons.md` after meaningful fixes or repeated failures, and present the result for owner review. Do not rebuild the pipeline, overwrite the first creature, upload assets or publish without an applicable request.

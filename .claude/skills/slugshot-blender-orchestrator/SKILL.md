---
name: slugshot-blender-orchestrator
description: Picks the Blender backend and domain skill. Use for a task already known to be inside Blender, such as a selected mesh edit, a live scene inspection or a Blender error. For a whole slug task use slugshot-creature-production instead.
---

# Slugshot Blender helper

Use the backend table and the task row in [skill routing](../../../docs/slugs/skill-routing.md). Confirm the live Blender and its MCP tools first, and that the open `.blend` is the intended one. Run one live backend on a scene at a time, and checkpoint before editing. Prefer a local edit for a local fault. Read the [skill audit](../../../docs/slugs/skill-audit.md) row for the chosen skill if you have not used it, and test a new recipe on a disposable scene. A passing script, render or FBX reimport is not owner approval or Roblox playback. Whole-slug procedure, recording and approval belong to `slugshot-creature-production`.

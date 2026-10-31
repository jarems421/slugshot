---
name: slugshot-creature-production
description: Step-by-step workflow for Slugshot creature (slug) production in Blender - modelling, sculpting, face/eyes, antennae, materials, rigging, skin weights, squash-and-stretch animation, rendering, FBX export and Roblox import. Use for any task that creates, edits, fixes, rigs, animates, renders or exports a Slugshot creature, or reports a creature looks wrong. Selects one or two Blender skills from docs/slugs/skill-routing.md instead of loading all 58.
---

# Slugshot creature production

The reference manual is [skill routing](../../../docs/slugs/skill-routing.md). Also read [modelling lessons](../../../docs/slugs/blender-lessons.md), the species record in [the catalogue](../../../docs/slugs/catalog/index.md) and, for Roblox, the [Studio import checklist](../../../docs/slugs/studio-import.md). `slugshot-blender-orchestrator` holds the same routing rules in short form; this skill is the full procedure.

1. **Name the problem.** Write one sentence: the creature, the failing view or behaviour, and whether it is technical (errors, geometry, weights, export) or artistic (owner feedback on form, face, colour). Quote owner feedback exactly. If the cause is unknown, inspect before editing.
2. **Select skills.** Find the matching row in the routing table. Use its primary skill; add a supporting skill only for a real cross-domain dependency. Do not choose a skill by its name alone; read its row in the audited inventory, then read only that installed `SKILL.md` (`~/.agents/skills/` or `~/.claude/skills/`). State the selection and why.
3. **Check compatibility.** Confirm the skill's Blender version, MCP tools and Python dependencies against the routing guide's compatibility section and [install audit](../../../docs/slugs/install-audit.md). RobLe3 legacy MCP tool names and OpenCV scripts are unavailable; substitute only after a disposable test.
4. **Choose one backend.** Reproducible creature builds and export: existing `tools/slugs` scripts on Blender 4.5.14 headless. EL4CTEO recipes: Blender 5.2.3 headless. Selected local mesh edit on a live scene: BlendRelay. Live Python inspection or RobLe3 recipes: MCP for Blender (`blender`). Confirm the open `.blend` is the intended one; never run two live editing backends on one scene.
5. **Checkpoint.** Save a copy, variant or BlendRelay checkpoint before geometry, rig or material edits. Never overwrite an accepted iteration or its renders, and never run a scene-reset step on an existing scene.
6. **Edit narrowly.** Fix a local problem locally. If the same visual failure has recurred (check the lessons), treat it as a modelling-method problem and test an alternative technique on a variant instead of another cosmetic pass.
7. **Render** front, side, back and three-quarter views with fixed camera and light, plus pose extremes for rig or animation work.
8. **Check technically** with the validation in the routing row and the project checks (`python tools/verify_slugs.py --blender` where relevant). For export: limit to creature objects, reimport and assert clip names. Blender reimport does not prove Roblox playback.
9. **Judge visually** against the brief and the last accepted iteration. Successful code is not successful design; say what still looks wrong.
10. **Record** verified fixes, failed approaches and repeated problems in `docs/slugs/blender-lessons.md` (what went wrong, cause, attempts, fix, prevention, verified or not), and update `docs/status.md` and `docs/memory.md` after meaningful work.
11. **Ask for owner approval** of artistic changes with the renders. Do not upload, publish, or start batch generation of other creatures until the first creature is approved.

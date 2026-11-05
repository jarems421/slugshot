---
name: slugshot-creature-production
description: Procedure for making or changing a Slugshot slug's model, face, antennae, materials, rig or weights in Blender, or for starting a new slug. Use when the slug's geometry or look has to change. For an export or import fault use el4cteo-blender-export-pipelines, for Blender keyframes el4cteo-blender-animation, for designing motion slugshot-animation-director, and for Luau motion slugshot-procedural-animation.
---

# Slugshot creature production

Find the task in [skill routing](../../../docs/slugs/skill-routing.md) and read only what its row names, plus the slug's record in [the catalogue](../../../docs/slugs/catalog/index.md). Search the [lesson index](../../../docs/lessons-index.md) by symptom before trying a fix. For a new slug, also read the "How the owner works" section of the [design language](../../../docs/slugs/owner-design-language.md).

1. **Name the problem.** One sentence: the slug, the failing view or behaviour, and whether it is technical or artistic. Quote owner feedback exactly. If the cause is unknown, inspect before editing.
2. **Select skills.** Use the routing row. Read only that installed `SKILL.md` (`~/.claude/skills/` or `~/.agents/skills/`). State your choice and why. Check the row in the [skill audit](../../../docs/slugs/skill-audit.md) if the skill is unfamiliar.
3. **Choose one backend** from the routing page, and confirm the open `.blend` is the right one.
4. **Checkpoint.** Save a copy, variant or BlendRelay checkpoint before editing. Never overwrite an accepted iteration or its renders. Floppy and Inferno are approved: change only what was asked.
5. **Edit narrowly.** Fix a local problem locally. If the same visual failure has recurred, it is a method problem: try another technique on a variant. A new slug starts as a live 3D concept agreed with the owner, then is rebuilt in Blender from the same maths.
6. **Render** front, side, back and three-quarter with fixed camera and light, plus pose extremes for rig work.
7. **Check technically** using the routing row and `python tools/verify_slugs.py --blender` where relevant. For export, limit it to creature objects, reimport and assert clip names. Blender reimport does not prove Roblox playback.
8. **Judge visually** against the brief and the last accepted version, and say what still looks wrong. Successful code is not successful design.
9. **Record** the owner's wording in the [design language](../../../docs/slugs/owner-design-language.md), the fix in the [creature lessons](../../../docs/slugs/blender-lessons.md) with a row in the lesson index, and any change of current truth in [status](../../../docs/status.md).
10. **Ask for owner approval** of artistic changes with the renders. Upload or publish only on request.

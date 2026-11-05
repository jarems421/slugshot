# ADR 0031: Motion production system and knowledge layers

Date: 2026-11-04
Status: Accepted
Approval evidence: owner asked for two pasted reviews to be implemented, omitting what the implementer disagreed with and reporting it.

## Context

Fourteen slugs each need acting, and nearly all approved slug motion is procedural Luau. The creature procedure covered production but not choosing a motion. Separately, instructions pointed at large documents: `status.md` was 175 KB and read at the start of tasks, and stale first-creature and isolated-worktree wording remained in active instructions.

## Options

Rebuild the docs, or keep everything and layer it. Extend the approved inspect preview in place, or add a sibling. Refactor approved motion onto a shared kit, or use the kit for new motion only.

## Decision

**Motion:** separate design (director skill, three concepts, owner pick) from implementation (procedural skill or Blender). Add `MotionKit` for new motion and leave approved scripts unchanged, because refactoring risks approved feel for no visible gain. Add a sibling `tools/slugs/motion-preview`, reusing the same Three.js r159 and offline builder approach, so the approved Playful Flame comparison stays as a record. The motion review has separate technical and visual gates and sits in the project, because the third-party gate is pinned and checked.

**Knowledge:** three levels. Current (`status.md`, `AGENTS.md`), task (router in `docs/index.md`, routing page, lesson index, feature notes), history (`status-history.md`, `memory.md`, full lessons, audit). Nothing is deleted. Precedence is in `AGENTS.md`.

**Left out:**

- Blender pose asset file: no accepted Blender poses exist to extract. The library holds Luau recipes until authored clips are accepted.
- Anything World and Tripo: new accounts, possibly paid credits, and sending original models to a service; both would need an owner decision. Their rigs are unlikely to fit custom contracts.
- Official Blender MCP pilot: a third backend that runs generated Python, for no motion-quality gain. Reconsider if the current two fail.
- Cascadeur and DeepMotion: humanoid and quadruped focus, poor fit for limbless slugs.
- Roblox Animation Graph Editor: composes clips; slug motion writes `Bone.Transform` directly.
- Moving text between sections of the design language and lessons: an index gives the retrieval benefit without risking loss or breaking links.
- Uninstalling or hiding third-party skills: wait for `/skill-doctor` evidence.

## Consequences and validation

Status must be edited in place rather than added to. Offline checks, routing benchmark results and limits are in [status history](../status-history.md). The director and procedural skills are unproven on a real slug task; the first real motion should test them, and owner art approval is unaffected by any of this.

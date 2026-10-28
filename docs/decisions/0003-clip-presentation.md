# ADR 0003: Clip-driven movement presentation with original clips

Date: 2026-10-28
Status: Accepted for the experiment only; reconsider after owner playtest
Supersedes: the procedural presentation part of [ADR 0002](0002-movement-experiment.md)

## Context

Owner feedback on v1: the evade looked like a dash, the flourish like a procedural spin, and running/jumping lacked expression. The owner asked for genuine directional rolls, athletic running, animated jumps and proper flips, with a single context-sensitive acrobatic control to explore. No verified free roll/flip clips were available publicly: the Cinderlore packs contain dashes/vault/wall jump and forbid public redistribution. Mixamo was chosen first, then deferred by the owner in favour of original clips, keeping Mixamo as a later upgrade.

## Decision

- Keep ADR 0002's native Humanoid controller, profiles, server validation and attribute replication.
- Replace procedural poses with a clip player (`shared/Clips.luau`) that samples R15 joint clips, blends directional locomotion, drives air poses from physics, crossfades states and corrects ground contact using forward kinematics on the real rig.
- Ship original keyframed clips (`shared/OriginalClips.luau`), public and editable.
- Private clips (Mixamo via `tools/mixamo_to_r15.py` + portable Blender) replace originals by name through an ignored `MovementPrivateClips` module and `movement.private.project.json`; public builds never contain them.
- Q/B becomes one context-sensitive control: roll on the ground, flip in the air, buffered landing roll.
- v1 stays playable via `tools/build_movement_playtest.py` (rebuilt from `e2b5688`).

## Alternatives

Native Animator with published animation IDs would need owner-published assets (outward action) and would not run for restricted clips in this public repo. Procedural rotation was rejected by the owner. A third-party controller remains unnecessary.

## Consequences

Clips can be swapped individually without code changes. Visual quality is bounded by hand-keyed clips and the blocky rig. Each client evaluates every character (cheap at sandbox scale; not profiled at large player counts). Evidence: [results](../movement-verification.md#v2-refinement-2026-10-28).

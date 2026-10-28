# ADR 0002: Isolated movement study on native Humanoid

Date: 2026-10-28
Status: Accepted for experiment only; reconsider after human playtesting
Update: procedural presentation superseded by [ADR 0003](0003-clip-presentation.md); controller decision unchanged
Approval: owner's movement-research/prototype request; later request explicitly authorizes pushing the work.

## Context and alternatives

Compare lightweight athletic movement without importing a whole first-person controller or choosing the final move set. Reviewed CCL, Place1, Precision, Movement Base and additional controller/tool leads; see [research](../research/movement.md).

## Experimental decision

Use native Humanoid physics/input/camera with small original input/tuning, evade, procedural presentation and request-validation layers. A dedicated branch and Rojo project keep the foundation build intact. Native CCL is a future comparison, not rejected permanently; its complete opt-in integration was not established on this installation. No copied controller code, external runtime framework or restricted clip IDs are required.

## Evidence and consequences

Local builds/lint/types/math checks and real single/two-client Studio checks support the prototype. A peer rendered motion/flourish; an impaired network trial completed with settings restored. This does not establish subjective quality, device coverage, full FPS independence or competitive security. Procedural poses need polish and private clip selection needs further fit/blend review.

Controls, third-person reference camera, speed values, evasion and flourish remain experimental. No combat, creature, matchmaking or permanent game-design decision is made. See [playtest plan](../movement.md) and [results](../movement-verification.md).

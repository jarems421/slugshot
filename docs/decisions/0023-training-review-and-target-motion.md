# ADR 0023: Isolated training review and adjustable target motion

Date: 2026-11-02. Status: Implemented for the authorized training review; final visual and gameplay approval unresolved.

## Context

The owner first requested a complete training-arena asset before gameplay work, then liked that draft and asked for plain rock, action runes, rim-visible rubble, moving/stationary dummy controls and a Studio enclosure view. The active lobby, creature and combat work must remain separate.

## Decision

Keep authored geometry/layout and render/export tools on `feature/training-arena`. The normal and check review places use their own generated Rojo projects and a generated copy of the existing movement server with only spawn/fall thresholds adapted. Foundation and movement source are unchanged. Existing private island/wall assets are reused; only the reviewed authored draft model and stone paint are imported privately for Studio. Restricted IDs stay ignored and server-side.

Target motion is an anchored model moving along a fixed sinusoidal path. Server owns speed and phase; zero holds position, resume preserves phase. A training-only remote accepts finite speeds in [0,20], rate-limits per player, and replicates the selected setting. Native clients display that shared configuration; the browser offers an independent visual preview of the same rule. Ordinary range/combat/inventory projects do not map these scripts or the remote.

## Evidence and consequences

New geometry QA/export roundtrip and browser control checks pass. Native server tests verify 30/120 Hz equivalence, pause/resume and invalid speeds. A real client verifies replicated 0/4/16 settings, movement/stopping and forged speed rejection; six camera views cover room/ceiling/rim/runes. Full movement/foundation offline verification passes. See [current training review](../art/training-arena.md) and [evidence](../evidence/2026-11-02-training-asset.json).

This is one-client local-server evidence, not multiplayer latency, collision-route quality, mobile performance or owner art acceptance. Shooting damage and training-only access to every implemented species remain subsequent integration work; the review does not change owned inventory or grant persistent slugs.

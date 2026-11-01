# ADR 0011: Isolated custom-rig creature pipeline

Date: 2026-10-30
Status: Accepted technical scope by the owner's attached universal slug pipeline request. Artistic/gameplay decisions remain unresolved.

## Context

The owner requested reusable creature infrastructure while Claude changes Rocklock. The existing main checkout has uncommitted map work. Player animation uses a separate R6/movement pipeline with private animation provenance. Creatures need original custom rigs, anatomical variation and independent transformed skeletons. Fast projectile flight may be shorter than normal animation durations.

## Decision

Create `feature/slug-asset-pipeline` in a separate worktree based on `913f9e6`. Keep creature runtime in `experiments/creatures` with dedicated public/test Rojo projects on 34875. Keep foundation, map/destruction and movement source unchanged. Do not merge or publish.

Version JSON skeleton/socket contracts and species configurations under `assets/source/slugs`. Compile a deterministic strict Luau projection; verify parity. Use the existing Blender 4.5.14 LTS native Python API, text-first placeholder generators, authored `.blend` inputs and separate ignored build/source/export/preview outputs. Record provenance, hashes, scale/axes, actions, settings, budgets and offline FBX roundtrip evidence. No addons, package installs or asset IDs are required.

Small and transformed forms declare their own rigs and animation slots. Renderer handles own cloned models, players and cleanup. A pure presentation timeline consumes externally owned pose, elapsed time, predicted total flight time and impact. It compresses to available flight time, prevents reversal after a swap and finishes on explicit impact. Attack visuals require an explicit event. No gameplay waits for animation frames.

## Consequences and limits

The pipeline can demonstrate reproducible geometry, anatomical changes, weighting, animation and export without designing a finished species. Native Parts/Motor6D proxies permit upload-free timing checks; they are not evidence of imported Bone skin deformation. FBX and nonuniform bone-scale behavior, material fidelity, asset ownership and runtime playback remain Studio gates. Real art uses reviewed source files and a separate binary-storage decision. New rig topologies need new compatibility IDs and clips; arbitrary cross-rig retargeting and literal mesh morphing are not implied.

Evidence and reproduction commands are in [the pipeline guide](../slugs/pipeline.md) and [verification record](../slugs/verification.md).

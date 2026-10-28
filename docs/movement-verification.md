# Movement prototype verification

Date: 2026-10-28. Studio 0.745.0.7451137, Rojo 7.7.1. Experimental branch only; no Roblox experience or animation published. This records technical progress, not a claim that movement feels excellent.

## Passed

| Check | Observed result |
| --- | --- |
| Foundation pipeline | Existing formatting/lint/types, normal/test builds, source fidelity and package boundaries pass; default project still has only three probes |
| Movement pipeline | `python tools/verify_movement.py`: formatting/lint, engine-neutral math analysis, both movement builds and private-asset/test isolation pass |
| Numerical timestep checks | Actual Studio assertions passed at 30/60/144 Hz integration steps: speed convergence, no overshoot, braking and exponential turn blending; NaN/infinity checks |
| Profile comparison | Live steady speeds: Baseline 16, Athletic 24, Precise 21 studs/s; approximate distances over a 0.9 s sample: 14.0, 19.1, 17.5 studs |
| Start/stop/reversal | Athletic cruise about 24; stopped speed below 0.001. A reversal sampled after 80 ms was about -13.1 studs/s; subjective responsiveness still needs review |
| Evasion and wall | Open-ground displacement about 6.9 studs; wall-adjacent evade stayed behind the wall, moving about 1.8 studs in the tested approach |
| Jump/flourish/aim | Actual Freefall state, visible-joint rotation measured; physical root up = 1, camera roll = 0, aim-direction dot approximately 1; harmless marker placed |
| Respawn | Controller reattached to replacement R15 rig with 15 animation joints |
| Native keyboard bindings | Studio's real input tool exercised W/Shift, Q, Space and F in the final public sandbox; moved about 19.2 studs and triggered the flourish with root up = 1 |
| Two-client movement | Both clients reached about 24 studs/s. Observer rendered the other player's run with weight 1 and hip pitch magnitude up to 0.67 radians |
| Peer flourish | Observer measured visual rotation up to 6.20 radians while the physical root remained upright |
| Real network emulation | One client: 60 ms minimum delay in each direction, 10 ms jitter. Evade moved about 6.8 studs with no rejection or motion correction in the tested run; all modified settings restored to zero |
| Invalid requests | Server rejected 32 malformed/unknown/rate-limited requests; character health stayed 100 |
| Multiplayer respawn | Reattached, one HUD, mouse lock cleared; peer saw replacement rig; both players remained present |
| Teardown | Multiplayer test ended; no emulation setting left modified |
| Asset acquisition/playback | Two official free Cinderlore downloads retained privately; no scripts in either pack. All six movement clips and GuardReaction played on an actual R15 preview rig |

The two-client output had no project-script errors. The existing platform/avatar asset-type warning for `203785492` appeared again and is recorded separately. It is not a restricted Cinderlore ID and is not referenced by prototype source.

## Visual review and issues caught

Captured running poses and the seven selected private preview clips were actually inspected. This was sample-frame inspection plus confirmed Animator playback, not a full animator-quality review of all timings, loop seams or avatar proportions. Evasion/flourish still need human visual/feel feedback.

Live tests exposed the installed rig's AnimationConstraint joints, a blend-state reset against Animator evaluation, a jump-input probe timing issue, delayed position versus velocity in airborne validation, and mouse-lock cleanup across respawn. The implementation was corrected and the relevant checks rerun. Generated rig coloration was made readable for testing; it is not a creature/art-style decision.

## Limits and manual feedback

- Actual rendered 30/60/144 FPS sessions were not forced. Numerical timestep invariants do not establish full engine/physics FPS independence.
- Only a small local two-client and one network-condition sample was tested. No packet-loss, WAN, stress, mobile/gamepad-device or competitive exploit certification is claimed.
- The aim marker demonstrates camera-space input independence, not finished weapon grip/muzzle alignment or hit validation.
- Motor6D support exists in the presentation code but the actual tested rig used 15 AnimationConstraints. R6 is not targeted.
- CCL's complete opt-in setup was not validated; classes existed but the alias probe did not complete and AuthorityMode was unavailable in the checked scene. No beta/security setting was changed.
- Built-in MCP could not call LoadLocalAsset with its available capability. Only the separately inspected animation data was reconstructed for private previews; no capability/security restriction was changed.
- Restricted clips/IDs are not integrated into the public build. Further fit/blend work and any owner-controlled publishing remain manual choices.
- Slopes/step foot contact, camera comfort, stride quality and action usefulness require the playtest in [movement.md](movement.md). Do not call these polished or final.

[Sanitized evidence](evidence/2026-10-28-movement.json) contains measured results and source hashes. Raw logs, private captures and temporary IDs remain ignored. CI validates public source/builds only; Studio evidence is local and separate.

[Public-safe sandbox capture](evidence/movement-lab.jpg) shows only the original procedural study on a native Roblox rig, not downloaded animation playback.

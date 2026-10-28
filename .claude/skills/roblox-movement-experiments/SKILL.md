---
name: roblox-movement-experiments
description: Research and iterate on an authorized Slugshot movement sandbox while preserving the foundation and private animation provenance.
---

# Movement experiment procedure

Read the latest user task, `docs/status.md`, `docs/movement.md` and the movement research/provenance notes. Prototype mechanics and numbers are hypotheses, not permanent design requirements.

Keep work in the dedicated experiment project/branch. Do not connect a movement Rojo project to the foundation place, install competing character controllers, publish an experience or push restricted source/IDs. Respect the task's actual installation/push permissions rather than requesting approval already granted.

Before adopting a component, inspect implementation, pinned revision, licence, dependencies and bundled scripts. A README/store label is insufficient. Keep restricted downloads, conversions, temporary registered IDs and private preview captures under ignored private storage. Test asset data on the actual rig before claiming playback or visual assessment.

Inspect joint classes in the installed Studio. R15 may use AnimationConstraint rather than Motor6D. Avoid fighting the default Animate script; disable it only in the experimental avatar when using the original presentation layer. Maintain independent blend state rather than repeatedly blending from Animator-overwritten joint values.

State the test hypothesis and compare a small number of profiles. Separate locomotion, visual rotations, camera and aim. Check actual root/camera orientation while an action plays; a marker demo does not prove weapon alignment. Prefer a coherent small move set to adding every proposed mechanic.

Run `python tools/verify_movement.py`, then use the actual Studio client/server contexts to check movement, wall blocking, action rejection, peer presentation and respawn cleanup. Confirm HUD/input bindings are not duplicated. Distinguish numerical timestep tests from tests at actual rendered frame rates. Snapshot and restore every temporary network-emulation setting, including on failure; stop test sessions afterward.

Record observed results, warnings, subjective gaps and rejected candidates in movement notes/evidence. Do not describe request validation or one latency trial as competitive anti-cheat or network correctness. Leave final movement/camera choices for explicit review.

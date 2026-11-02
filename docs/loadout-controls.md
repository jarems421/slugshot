# Loadout controls and slug inspect

**Confirmed, owner, 2026-11-02:** use the existing five-slot HUD and settings. Keep 1–5 for slug selection; add the wheel. V toggles first person instead of wheel zoom. Inspect raises the blaster with one hand and gives each slug its own response. Saving/loading is the next task, not part of this pass.

**Implemented:** `feature/loadout-controls`, isolated in `C:/Users/runni/slugshot-loadout-controls`, based on main `344fcf4`. No SFX, lobby or concurrent creature source is changed.

- Wheel down selects next, wheel up previous; wrap around and skip empty slots. Number keys select populated slots directly. Selecting the current slot keeps the gun equipped. The old standalone key-1 holster listener yields to the combat HUD.
- All controls, including V and R (inspect), appear in the existing rebind settings. Wheel camera zoom stays disabled even when its bindings are cleared or rebound. Character setup reapplies the pinned third-person distance on respawn.
- The selected slot drives shot species, prediction and HUD highlighting. Cooldowns remain separate for every slot, including slots not selected. Switching cancels a held charge without firing it. The server validates the selected slot against the existing carried loadout; selection does not grant creatures.
- Inspect uses server-authored character timestamps, sampled cosmetically by each client. The gun/arm driver, first-person copy and existing Floppy bone/face drivers compose the animation. Firing, aiming, switching, menus, traversal, holstering and death interrupt it. Movement and weapon use are not locked for the gesture.
- Floppy looks back, smiles lazily, turns forward and wiggles his rear before the gun lowers. This is a runtime animation candidate; the accepted Blender mesh, weights and source animation are preserved. First-person framing articulates the cosmetic wrist while keeping the palm at the grip and upper arm below the view.

## Verification

Run `python tools/verify_combat.py` and `python tools/verify_slugs.py`. The full `--blender` creature suite also passed in this worktree; no authored Blender asset was edited.

`python tools/build_loadout_check.py` builds a disposable place with copies of Floppy in slots 1, 2 and 5. `powershell -NoProfile -File tools/studio/loadout_check.ps1 -OutDir build/loadout-evidence-delivery` opens only that test window, sends native keyboard/wheel messages, captures the animation and closes its own window. The normal range retains its single real Floppy; fixture copies are not additional species or owned inventory.

**Unresolved:** owner animation/feel approval; a real second species and its chamber model; multi-client and latency coverage; hardware wheel behaviour outside Studio. Inferno's requested turn-and-glare requires its runtime rig from the concurrent creature work. See [inspect briefs](slugs/catalog/inspect-profiles.md). Persistence, collection acquisition, rearranging slots and exploration are outside this pass.

## Review fixes

- First pass: using the real R6 wrist orientation to solve the first-person arm put the upper arm across the camera. Moving the entire gun farther away improved the overlap but weakened the close-up. The final cosmetic wrist solve keeps the gun closer and the arm below it, preserving palm position.
- A startup-only optional inspect lookup could miss `MovementSandbox`. Resolve the module after startup in the existing idle driver; standalone creature places still run without movement modules. The pose failure was ultimately reproduced as render ordering, described below.
- The movement character bootstrap restored the old zoom range after the camera module pinned it. It now calls the camera module's explicit third-person reset.

Decision: [ADR 0021](decisions/0021-loadout-controls-and-inspect.md).

**Runtime ordering fix:** native animation can reset bone transforms between simulation and rendering. Unordered RenderStepped callbacks also let the first-person copy read a reset pose. Idle now runs at Character +2, face at +3, and the viewmodel copies them at +10. The native fixture samples the source at +30 rather than during Heartbeat; simulation-time identity is not evidence of a frozen rendered bone.

**Implemented/verified, final native run:** all fixture assertions and shared flight regressions pass. See the [sanitized evidence report](evidence/2026-11-02-loadout-controls.json); screenshots remain under ignored `build/loadout-evidence-delivery`. The fixture asserts that the first-person copy receives non-identity root motion, not just that the source bone changes. Native key/wheel tests use OS window messages, not a physical mouse. Studio also emitted service HTTP errors; an earlier passing run logged an engine debug.profileEnd warning. The animation remains a candidate for owner review, especially expression readability inside the small chamber.

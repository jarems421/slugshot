# Loadout controls and slug inspect

## Current: first-person inspect view (2026-11-07)

**Confirmed, owner, 2026-11-07:** both inspections must work in the game, at the same size, and the slug must be bigger and noticeable. Of three options (camera moves in, first-person inspect, bigger canister) the owner chose first-person inspect.

**Implemented/verified in Studio (combat range, real key presses):** pressing R in third person switches to first person for the act and back after the catch; pressing V during the act keeps the player's choice (`CombatClient`). First person holds the gun 0.7 times as far away (`SlugInspect.ViewNear`), moved along the line through the canister so the slug keeps its place on screen and reads about 1.4 times bigger. Floppy and Inferno read the same size in the canister (same loaded fit). The game build was missing Inferno's inspect and teeth scripts; `build_game.py` now copies them. This tree's private Inferno asset file lacked the wing-fire keys, so every Inferno model failed to build and the HUD showed a ball; it was refreshed from `slugshot-slug-pipeline`. **Unresolved:** owner's verdict on the view swap and size; not yet tried in the game place's arena by hand; phone and controller.

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

## Inspect superseded after owner rejection

**Confirmed, 2026-11-02:** the owner rejected the original inspect pose and clarified an upward barrel aligned with the raised arm, diagonally toward the holder. The [revised inspect](slugs/inspect-revision.md) replaces independent gun placement and bone-only whole-body turning with a shared grip solve and cosmetic attachment motion. Earlier passing assertions did not establish visual approval.

## Current inspect correction (2026-11-02)

**Confirmed/implemented:** the owner clarified a toss, end-over-end flip, catch, then outward wrist reveal. Floppy stays in the chamber and springs into his turn; his bum shake articulates the hips and upper body without added jiggles. The gesture is now 6.8 seconds; controls and interruption rules stay as previously verified. Earlier barrel-twirl/visibility-offset candidates are superseded. [Revision and evidence](slugs/inspect-revision.md#toss-catch-and-contained-spring-turn-2026-11-02-current). Owner art/feel approval remains unresolved.

## Owner-selected resting pose and wider camera (2026-11-02)

**Confirmed:** owner selected Idle arms (first person): Gun tips down = -20 degrees, Arms up = -0.35 in the live P panel, and requested a noticeably wider base third-person view. **Implemented:** baked `idleGunDown = -20` and `idleLift = -0.35` into Tuning defaults; increased fixed third-person distance from 7 to 10 studs (about 43% farther). V still toggles first person; the wheel still selects slugs. The two numeric arm values are owner-selected; 10 studs is the implementation choice for the requested camera change, with owner feel verdict unresolved. Combat/foundation/movement formatting, lint, strict types and place builds pass. Fresh normal preview: `build/SlugshotInspectTuned.rbxlx`.

**Implemented/verified in Studio:** the fresh P panel shows -0.35 and -20.00 as unchanged defaults, and the base third-person view is visibly wider. Captures: `build/studio-cleanup/tuned-first-person-panel.png` and `tuned-third-person.png`. Checked both camera modes with the normal playable place; this is not a new multiplayer/device test.

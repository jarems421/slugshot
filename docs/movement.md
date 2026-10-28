# Movement lab

Experimental branch: `experiment/movement-sandbox`. The foundation project remains unchanged. This is a playable comparison, not an approved final movement set or camera design.

## Play

```powershell
python tools/verify_movement.py
```

Open `build/SlugshotMovementLab.rbxlx` in Studio and press Play. The generated R15 avatar, floor, ramp, steps, wall and landing platform are functional test fixtures. No public experience or animations were published.

For editing, serve `movement.project.json` and set the Rojo plugin port to **34873**. Serve only the intended project into the sandbox. `default.project.json` still uses port 34872 and contains only the original foundation probes. `movement.test.project.json` additionally runs the math assertions.

| Control | Experimental action |
| --- | --- |
| WASD / native movement controls | Move with input smoothing |
| Shift / gamepad L3 | Faster run |
| Space / native jump | Jump |
| Q / gamepad B | Directional grounded evade; current input direction, otherwise forward |
| F / gamepad Y | Visual aerial flourish, once per jump; no extra jump or physical rotation |
| RMB / gamepad L2 | Shoulder aim pose, stable camera, small FOV change |
| Click / gamepad R2 | Harmless local aim marker; no damage or projectile system |
| P | Cycle Baseline, Athletic, Precise |
| R | Respawn/reset |

Touch action buttons are present, but touch/gamepad use has not been device-tested. No stamina, invulnerability, wallrun, skiing, slide system, combat or creature systems were added.

## Compare and tune

All tuning is in `experiments/movement/shared/Config.luau`. Baseline uses 16 studs/s; Athletic uses 24/30 run/sprint; Precise uses 21/27. Baseline is a speed/control comparison profile, not an exact copy of untouched Roblox default locomotion. Acceleration, braking, turn smoothing, jump power, evade duration/speed/cooldown, animation amplitudes and camera parameters are configurable.

Athletic is the initial hypothesis: faster traversal with a compact roughly 7-stud evade. Precise is available when aiming/readability matters more than pace. FOV varies only 68-74; there is no shake, motion blur or camera roll. Default Roblox camera/occlusion and PlayerModule input are retained rather than replaced with a large controller framework.

The original procedural R15 layer supplies stride/arm movement, airborne pose, compact evade and flourish. It supports the installed AnimationConstraint rig and also has a Motor6D code path; the latter has not been separately runtime-tested. Private Cinderlore clips were downloaded and previewed, but remain optional candidates outside the public sandbox.

## Boundaries and known rough edges

Motion, visual joints, camera and aim markers are separate. The flourish rotates joints without rotating the physical root or camera; the marker is camera-directed throughout. This is not proof of future weapon/muzzle alignment during a full flip. The aim pose is a visual study, not a finished weapon system.

Requests have server type/finite-vector checks, cooldown/ground-state checks, profile validation and a rate limit. A broad motion envelope provides correction telemetry. Native client-owned character physics remains in use. This is not competitive security, rollback or comprehensive exploit prevention.

The run/evade/flourish animation is intentionally an original placeholder. Foot contact, landing weight, tuck silhouette, aiming blend and camera comfort need human feedback. Full rendered 30/60/144 FPS behavior was not forced; only numerical timestep invariants and the actual observed Studio sessions were checked. See [results](movement-verification.md).

## Playtest priorities

1. Compare profiles on the flat lane and around the steps: which starts/stops/turns feel predictable?
2. Try Q forward/back/sideways near the wall. Does the distance support evasion without dominating movement?
3. Jump, hold aim, use F and place a marker. Check readability, camera comfort and whether the flourish adds value.
4. Decide whether to keep, change or remove each action before expanding the move set. No prototype action is a permanent requirement.

[Research shortlist](research/movement.md) · [Private asset handling](movement-assets.md) · [Decision record](decisions/0002-movement-experiment.md)

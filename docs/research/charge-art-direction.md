# Combat charge art direction - 2026-11-01

**Checkpoint correction:** the current renderer has a compact radius-19 white ring with feathered edges, thin charcoal inner and outer rims, a short inward intake after the quick-tap threshold, fine ring-only full-charge vibration and a traveling light reflection. Overall ring scale remains one; the crosshair and camera do not shake. The broader 1.1-second breathing and four ready corners described in older trials below were rejected. Crosshair shape/color/size settings affect the aim mark alone. The owner liked the tighter vibrating base and subsequently requested the ink rims/reflection; the final appearance remains theirs to assess in Studio. [Runtime evidence](../evidence/2026-11-01-tight-ring-rims.json).

**Latest accepted base and refinement:** the owner likes the tighter translucent vibrating ring. Preserve its radius 19, thinner feathered white, fixed crosshair and fine ring-only energy, replacing the rejected broad breathing. Requested black highlights now define both rims. A subtle traveling reflection explores the requested spinning feel without rotating geometry; that refinement remains pending owner review. Full charge is drawn with continuous unclipped circles to avoid a moving split seam. [Evidence/limits](../evidence/2026-11-01-tight-ring-rims.json).

**Earlier simplification trial, superseded by the checkpoint above:** the owner removed four outer ready corners, simplified intake and blended the outer halo. The trial used a small 1.1-second full-ring breath; the owner later rejected that broad, blocky pulse in favor of fine ring-only vibration. Its evidence remains useful for quick-tap gating and cleanup, not as current motion guidance. [Trial evidence/limits](../evidence/2026-11-01-simple-charge.json).

## Authority and sources read

**Confirmed:** owner rejects the plain/blocky charge animation and asks combat UI to follow the lobby's established visual philosophy. The designed crosshair is liked; preserve its 1.15 third-/1.22 first-person sizes, with a stronger dark edge. The native pointer overlapping it is a separate reported bug.

Read-only reference worktree: `C:/Users/runni/slugshot-lobby`, branch `experiment/lobby`. Research began at `5a540fb`; latest check at `fed077915890f74f5f7ebdb0f73cb57d47a308e5` included rounds 7/8. Reviewed:

- `docs/art/style-guide.md`: confirmed **Living Comic-Book Fantasy**, bold charcoal silhouettes, calm bases, selective glow, clean interior detail and deliberate motion. Ambient life is restrained; rubbery bounce and noisy decoration are not the goal.
- `docs/art/look-pack.md`, `docs/art/lessons.md`: the Slugshot mix treats materials separately, keeps small details from being engulfed, and avoids washed-out glow. Latest wall study removes decorative squiggles/shells in favor of deliberate real cracks; do not interpret “plain” as a request for random surface noise.
- `docs/art/lobby-roadmap.md`, `docs/slugs/owner-design-language.md`, `docs/slugs/blaster-motion.md`: calm/hero hierarchy, purposeful effects, crisp readability and short original flourishes that never block input.
- `experiments/lobby/shared/LookPack.luau`: near-black `(14,14,18)` ink, controlled glow, crystal twinkles, mushroom spores, per-material treatment.
- `experiments/lobby/client/LookFx.client.luau`: measured portal breathing and drifting light-carrying spores; effects give life without shaking the viewpoint.
- Open `build/SlugshotLookTest.rbxlx` inspected visually, currently showing an inked rock module with glowing crystal/fungus dressing. Capture is local ignored `build/lobby-design-reference.png` in the combat worktree. No lobby source, camera, play state or scene was edited; only its existing window was brought forward for inspection.

No lobby models, private texture IDs, lighting scripts or global effects were imported into the target range. These sources establish the shared art direction, not approval of this new HUD.

## Translation to the charge effect

**Implemented; owner appearance/feel verdict pending:**

| Lobby principle | Combat presentation |
| --- | --- |
| Important forms get bold ink | Stronger charcoal reticle outlines; charcoal-backed white charge stroke. Preserve the small white aiming core. |
| Selective glow, not washed-out brightness | Low-opacity halo around the active white energy, no whole-screen bloom or lighting changes. |
| Life with purpose | Two short counter-flowing wisps and three inward motes only while loading. Flow slows as charge gathers. |
| Clear silhouettes | A tapered leading energy stroke, drawn shapes instead of tiny font symbols, smooth circular curves. |
| Readable activation | Gather -> loaded stroke -> short glint/rim closure -> stable ready seal. No repeated bounce, strobe or busy held animation. |
| Calm foundation | Accepted crosshair shape/size stays fixed; decoration stays outside the precise aiming area. |

White remains the base. Angular fill still reflects real combat charge. Scale settles monotonically at full charge instead of overshooting like a spring. Brief glints and an outlined rim supply the readiness accent; four small lock marks and the completed stroke remain while held. No aiming drag, fake charge delay, projectile, camera or movement change.

Initial native preview still read like a generic circle, and a tiny font glint looked boxy. Final pass strengthens the tapered leading stroke and the ink-backed inner flow; custom drawn/faded glints avoid font-dependent appearance. Pad arc clips so thicker ink/halos do not create square outer edges. Never add noise just to make a circle less plain.

## Cursor ownership and verification limits

**Reported:** native pointer has returned over the reticle. The initial current-build free-view audit did not reproduce the overlap (181 frames, no icon-enabled frames). The original offending writer/path is not confirmed.

**Implemented/verified:** apply the cursor policy after native UI/camera work at `RenderPriority.Last + 1000`, plus a property-change guard against gameplay re-enablement. Menus/text focus remain explicit exceptions. An injected late writer at `Last + 500` is overridden without exposing the icon at the final audit; native M/Esc transitions restore it correctly. See [runtime evidence](../evidence/2026-11-01-ink-charge.json).

Windows `CURSOR_SHOWING` can be set even for a transparent cursor image. Drawing the current native cursor returned blank images in both gameplay and menu observations, so this alone cannot distinguish Roblox's visible pointer state. Use actual in-game captures and the runtime mode/menu/icon policy together; do not call a Windows flag a cursor regression by itself.

Static native art previews temporarily feed fixed charge poses to the existing renderer and restore its setter afterward. They prove the native appearance only. Separate real charge/release/server probes verify behavior and aiming. Subjective gravitas, comfort and style acceptance remain the owner's playtest; no mobile/multiplayer/performance approval is inferred.

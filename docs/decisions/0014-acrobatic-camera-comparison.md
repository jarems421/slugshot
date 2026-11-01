# ADR 0014: reversible first-person camera comparison

Date: 2026-10-31. Status: **owner accepted Spot as current default; Anchor/Ride retained in Settings**.

## Context

The owner requested player-feedback research and three playable flip cameras for a fast PvP shooter. Existing physics, directional clips, timing, gun mechanics and third-person presentation are to remain the source system. [Research and source limits](../research/first-person-acrobatics.md) show conflicting preferences for stability, body awareness and dramatic camera motion.

## Experimental implementation

The initial range-only comparison started on Anchor without recommending a winner. **Subsequent owner decision:** Spot is the normal first-person default. `Config.Camera.FirstPerson.FlipCameraDefault = 2` selects Spot; `FlipCameraEnabled = true` enables it throughout the isolated movement experiment. Combat-enabled places expose all three choices in Settings (M). The temporary overlay and J/K shortcuts are removed. Selection is local/session-only, survives respawn and does not force a camera-mode switch. A fresh session starts on Spot; no account persistence was requested.

The existing post-camera view transform now includes the experiment, and its inverse plus any temporary FOV addition is removed at RenderPriority.First before input, movement and Roblox's camera read the prior frame. The native live look remains underneath presentation. A stored Camera reference avoids undoing an old effect onto a replacement camera. This does not change shooting rules: aim uses the visible camera ray and the actual rendered gun muzzle. Tilt/pitch can therefore move the target under the crosshair even when raw player look is preserved; this tradeoff is deliberate and must be judged in play.

Anchor uses a small drive/tuck/release displacement, with no flip rotation or FOV pulse. Spot uses an anticipatory counter-motion and bounded directional bank/pitch, levels by 68% of the actual flip; a small FOV pulse follows the bank. Ride samples Root/Waist/Neck rotations directly from the selected decoded clip using the existing action stamp/rate, with short entrance and final-neutral recovery. Its arms follow their source body pose instead of a lens-pinned tuck. All use the real animated legs and current arm geometry.

The owner rejected generic carry gestures, including a larger direction-blended key trajectory attempt. Anchor/Spot now use each live arm's torso-relative articulation plus 12%/28% of its actual camera-relative body direction. A forward reach projection retains the source shoulder choreography and mirrored asymmetry while keeping it readable around the stable eye. It does not introduce replacement flip poses or a shared oscillation. The forward projection compresses lateral spread; it is an intentional perspective adaptation. First-person flip arm follow is 72/s to preserve the source timing; the charging gun hand retains only 20% of the reframe and follows the established pointing pose. Ride and locomotion are unaffected by this follow-up. Rejected source snapshots are retained only under ignored build checkpoints.

Spot/Ride also add a short wall-release kick and traversal pull; existing wall-run and slide poses remain. Physics roots never inherit these rotations. Settings changes during a flip queue until it ends. The immediate cancellation API remains for probes, without a gameplay shortcut. Exit, death, character replacement and respawn clear transient state while retaining the session preference. Code stays in `experiments`; probes stay outside playable mappings. The owner accepts the result except the first-person running look.

## Reversal and review

Set `Config.Camera.FirstPerson.FlipCameraEnabled = false` to restore the prior camera/carry fallback; `FirstPersonFlipCameraEnabled` is an optional local probe override. Pre-comparison sources remain under ignored `build/checkpoints/pre-flip-camera-options`. The default and Settings choices are reversible. No merge, publish, uploaded animation or controller replacement is involved.

Check formatting/lint/types/builds with `python tools/verify_combat.py`. The development-only [Studio probe](../../tools/studio/flip-camera-comparison.luau) exercises actual directional flips, gun releases, orientation recovery and lifecycle cleanup. Owner look/feel approval and numerical evidence remain separate. Device input and multiplayer/latency coverage remain limited.

Additional probes cover [injected look and transitions](../../tools/studio/flip-camera-transitions.luau) and [wall runs/kicks approached by walking rather than teleporting](../../tools/studio/flip-camera-wall-live.luau). [Recorded evidence and fixture limits](../evidence/2026-10-31-flip-camera-comparison.json) distinguish local camera continuity from accepted server traversal.

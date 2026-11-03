# 0022 - Consistent firing samples and projectile collision

Date: 2026-11-02. Status: Confirmed repair scope; implemented experimental approach. Balance values remain subject to owner feel review.

## Context

The owner reported occasional distant misses during diagonal sprint/quick-scope starts and a sudden drop change when stepping backward. A native baseline measured a 29.19-degree launch change over half a stud. A later reproduction fired about 22 studs beyond a close surface because that surface lay behind the animated muzzle.

## Decision

Capture the firing ray, rendered muzzle and shoulder after the camera and viewmodel finish their frame. Input releases use that coherent completed sample; visual aiming still reads the current camera. This preserves immediate release and avoids pairing the temporarily undone movement camera with an old world-space muzzle. Respawn, camera and equipped-tool identity invalidate the sample.

Use one shared continuous ballistic policy for muzzle and shoulder fallback. Find the minimum required launch speed over flight time, then select the earliest feasible arrival (low arc). If a target is unreachable, bisect its reachable distance on the same line instead of switching to a 45-stud zero or choosing 10% distance steps. Lower powers retain their own speed and partial gravity correction; full power receives full correction.

Check shoulder-to-muzzle clearance. Close obstructions, including a camera hit behind the visible barrel, stop the shot on the shooter's side rather than spawning it beyond the surface. Existing server origin/selection/cooldown checks remain authoritative.

Both client and server use curved collision sweeps with segments no longer than 1/120 second. Server impact messages also stop a local flight that has not yet entered recovery. The existing local recovery sequence is preserved.

## Consequences and limits

Floppy speeds are 85/100/115 studs/s; gravity, drag, third-kick speed and damage remain unchanged. These numeric choices implement the owner's requested weaker first two levels; they are not final balance approval. Physical range remains finite. No movement-animation changes, new production remotes, persistence, new slug species or publication are introduced.

Evidence and reproduction: [shot consistency](../combat.md#shot-consistency-and-distinct-floppy-powers-2026-11-02-current). Desktop one-client Studio checks do not prove observer, latency or moving-target behavior.

Roblox's [render priorities](https://create.roblox.com/docs/reference/engine/enums/RenderPriority) and [camera ray API](https://create.roblox.com/docs/reference/engine/classes/Camera#ViewportPointToRay) were consulted. The frame-ownership choice is an implementation inference from this project's camera undo/apply passes, not an engine guarantee about arbitrary input callbacks.


## 2026-11-03 follow-up

**Implemented/verified:** cache surface hit/point with the completed firing frame and use a 60-stud zero when no surface is hit. The former 300-stud imaginary target saturated into a high lob. Native baseline/fixed evidence and limits are recorded in [combat notes](../combat.md#open-space-and-slide-rise-shooting-repair--2026-11-03).

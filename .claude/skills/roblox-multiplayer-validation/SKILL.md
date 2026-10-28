---
name: roblox-multiplayer-validation
description: Plan or run authorized Roblox multi-client, networking or physics experiments and record reproducible evidence.
---

# Multiplayer and physics validation

Read `docs/vision.md` to identify which behavior has actually been approved. The current foundation permits startup probes only. Do not implement a controller, remotes, combat or an authority framework merely to exercise this procedure.

For foundation validation, use `docs/testing.md` with one server and two clients. Inspect each Output separately and distinguish replicated shared code from server-only code. A server-side test requiring a module does not prove the client loaded it.

For later approved experiments, write the hypothesis and acceptance criteria before testing. Capture source revision, Studio version, client count, device, frame rate, network conditions and observations. Change one major variable at a time. Measure server/client agreement, correction frequency, latency and bandwidth where relevant rather than inferring correctness from visual smoothness.

Physics work must check elapsed-time handling, ownership, collisions and behavior at different frame rates against current official engine guidance. Do not assume rollback determinism or accept client results as authoritative without an approved design and validation.

Use Studio network simulation only if available in the installed version. Record inbound/outbound latency separately, plus jitter and packet loss. Test join/leave and cleanup when those behaviors exist. Keep experimental fixtures out of the normal Rojo project.

Separate measured results from a proposed design choice. Add evidence and limitations to project memory; user approval is required before turning an experiment into a gameplay requirement.

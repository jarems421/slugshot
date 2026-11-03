# ADR 0013: Bounded origin validation grace for moving shooters

Date: 2026-10-31
Status: Accepted for the isolated combat experiment
Approval evidence: Owner reported tap/held shots disappearing during flips and requested a fix.

## Context

Studio logs confirmed `origin` rejections. A scripted before-fix batch rejected five of eight directional mid-flip shots. Client muzzle distance was within about 4.4 studs, while server traces measured distances of about 7-10 studs. Server root and torso positions matched in these traces: firing messages were ahead of physics replication, rather than animated torso displacement being the sole cause.

## Decision

Validate against HumanoidRootPart with the existing six-stud radius. If the root has not caught up, wait on Heartbeat for at most 0.25 seconds, then recheck that same radius. Reserve cooldown before yielding to prevent extra pending shots; restore the previous reservation on rejection. Cancel if the character/state disappears. Equipment is checked on receipt, so holstering after release does not retroactively cancel the committed shot. NaN origins/directions are rejected.

Keep original world origin and receipt time. Sweep elapsed flight in segments no longer than 1/60 second, including the interval spent waiting, so early hits are not skipped. Ammo readiness uses the same original cooldown deadline. Client prediction remains immediate. No origin-range expansion, root-position claims or new shot payload fields are required.

The Studio-only CombatExperimentProbe routes through the same press/release functions as input and reports sent/accepted/rejected IDs. Test scripts and fixtures remain outside normal builds.

## Consequences and validation

Full verify_combat.py passes. One live client/server accepted all eight flip-direction shots, alternating taps/full charge at four release phases. Far origin, pending cooldown, NaN rejection and recovery checks passed. A controlled 0.1-second server-root catchup fixture registered a five-damage hit on the original flight's 0.05-second path, exercising catchup collision sweeps. [Evidence](../evidence/2026-10-31-mid-flip-shooting.json).

Server confirmation may wait up to 0.25 seconds; local predicted visuals are immediate. Longer or more irregular replication delays, physical input, peer presentation, firing through occluders and multiplayer load remain unverified. This is an experimental request/replication fix, not a competitive networking guarantee.


**Owner acceptance, 2026-10-31:** the owner accepts this chat's first-person result except running. This does not upgrade the bounded replication-grace checks into multiplayer/latency validation. Preserve the confirmed origin-ordering diagnosis, cooldown reservation/rollback and swept catchup; see the [regression guide](../combat.md#regressions-and-fixes-to-preserve).

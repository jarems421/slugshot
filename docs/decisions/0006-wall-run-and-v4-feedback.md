# ADR 0006: Wall run as an attach state, and the v4 feedback pass

Date: 2026-10-29
Status: Accepted for the experiment only; reconsider after the next owner playtest
Approval evidence: owner playtest feedback on the private v4 lab, 2026-10-29 (two messages: animation feedback, then wall run/wall jump/mantle feedback)
Builds on: [ADR 0004](0004-place1-traversal.md), [ADR 0005](0005-mixamo-variants-transitions.md)

## Context

The owner played v4 and found:
- wall run and wall jump not working;
- the v4 "wall run" behaving like a hop (it needed a second press at a narrow angle and then ran for about half a second before forcing a kick);
- a scrappy-looking wall jump and a slow mantle;
- too many jump variants;
- a crouch entry that dropped to all fours, and arms that cut between crouch idle and crouch walk;
- three visible cuts between stop, idle and fidget;
- short, fast-armed running strides;
- a falling pose while standing on a box edge.

The owner described a standard wall run: jump onto a wall while running and keep running along it, with a hand on the wall, then kick off when you choose. The v4 clip "Wall Run" is the kick-off at the end of that, not the run. Wall running up sloped walls was raised and then explicitly deferred.

## Options

- **Wall run as an extended hop (v4).** Simple, but it is not what the owner means by a wall run.
- **Wall run as a state, entered automatically on contact.** It needs per-frame wall following, end conditions and a new server action. This is the convention in action games, and what the owner described.
- **A Mixamo wall-run loop for the pose.** None of the owner's files is a loop along a wall. A procedural pose (sprint cycle, body roll, reaching arm) avoids waiting for a download.

## Decision

- **Jump input.** Space/ButtonA presses call the jump handler directly; `JumpRequest` remains for touch only. Real-key testing in Studio showed `JumpRequest` not firing for Space, so v4's wall hops never triggered.
- **Wall run is a `WallRun` action.** It attaches automatically while airborne at least 2 studs up, near a wall, when:
  - you're moving at least 12 studs/s along the wall;
  - your travel is at most about 53° into the wall and you're not moving away from it;
  - your movement input points along the wall;
  - it isn't the wall you just left.

  You keep 30% of the jump's rise (4 to 13 studs/s), then sink under 14 studs/s² while being pulled in to hug the wall. The run lasts up to 1.6 s. Space kicks off. Releasing input, steering away, the wall's end, or the ground drops you off. The server validates wall contact the way it validates wall hops, and rejects a grounded attach.
- **Wall jumps** (from a run or mid-air) play the kick-off part of the owner's Wall Run / Diagonal Wall Run clips. They're rotated to end facing the launch direction and mirrored for the other side. Up to 3 kicks per airtime.
- **Wall-run pose.** It's procedural and shown to every client: the forward run cycle, the body rolled 0.35 rad away from the wall, and the wall-side arm reaching to it. Observers keep it for 0.35 s before applying the end checks, because the action can arrive before the replicated body leaves the ground.
- **Parkour mantle.** Below 4.6 studs, the hand-plant part of Vault Over Box. Mantles may play up to 3.2x, with a 0.32 to 0.48 s target duration; the server rate limit follows that config.
- **Animation feedback:**
  - one running jump, plus a standing jump derived from it (mirrored, with a smaller swing)
  - no crouch-drop clip; crouch toggles crossfade, and the crouch idle borrows the crouch walk's arms
  - no fidget
  - transitions hand back to locomotion over their last 0.35 s, and the idle/moving mix eases over time
  - wider stride and arm swing, straighter elbows, and cadence capped at 1.3x, all via converter options
  - a sphere-based ground check in the presentation layer, so edges count as ground

## Consequences and validation

- Several of the owner's downloads are no longer used: Neck Stretching, Strafing, Jump, Rifle Jump, Left Strafe Jump and Run Strafing Jump. The trimmed Jumping clip remains as the hard landing.
- The wall-run pose has no hand IK.
- Running style is still unresolved: the owner wants it reworked next.

Evidence: [results](../movement-verification.md#v41-owner-feedback-pass-2026-10-29) and the [sanitized evidence](../evidence/2026-10-29-movement-v4.1.json).

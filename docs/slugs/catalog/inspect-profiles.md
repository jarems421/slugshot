# Slug inspect briefs

**Confirmed, owner, 2026-11-02:** inspect is a shared one-handed blaster raise/lower with a different creature response for every species. The same action must read in first and third person. R is the initial rebindable key chosen for implementation.

| Species | Owner's requested response | Implementation state |
| --- | --- | --- |
| Floppy | Look at the holder, lazy smile, turn around and wiggle his bum | Runtime candidate using the existing root/head and facial bones; owner art approval pending |
| Inferno (owner corrected “Burpy” to Inferno) | Turn to look at the holder, make a little angry face, then lower the gun | Confirmed animation brief; runtime model/facial rig belongs to concurrent creature work and is not present in this branch |

**Implemented:** reusable raise/lower sampling and a species turn profile in `SlugInspect`. Floppy's inspect composes with his current idle and facial driver; the accepted Blender art is preserved. **Unresolved:** Inferno's rig-specific glare and runtime integration; subjective timing, readability through the chamber, and observer playback.

See [implementation and verification](../../loadout-controls.md). This record does not approve new abilities, change either slug's design or rename Inferno.

**Confirmed correction, 2026-11-02:** the Floppy inspect is an upward barrel aligned with the arm, held diagonally toward the player; the first candidate was rejected for poor gun/hand placement. [Revision and review evidence](../inspect-revision.md) supersede its pose.

**Confirmed/implemented correction, 2026-11-02:** shared presentation now tosses the gun, catches it, then twists outward. Floppy stays inside the chamber, compresses and springs into his turn, then uses articulated hip/upper-body motion for the bum shake without added jiggles. Prior visibility escape/barrel twirl are superseded. [Current candidate/evidence](../inspect-revision.md#toss-catch-and-contained-spring-turn-2026-11-02-current); owner art approval remains unresolved. Inferno's separate runtime integration is still outside this branch.

**Confirmed/implemented correction, 2026-11-02:** shared gun motion is now a quick thrown backflip, arm-swing catch, outward tilt and plain lower with no flip. Slug acting is only retimed and awaits the next pass. [Current candidate/evidence](../inspect-revision.md#quick-backflip-arm-swing-catch-and-plain-drop-2026-11-02-current).

**Confirmed/implemented correction, 2026-11-02:** Floppy's response is now: look at the holder, three springy hops round, bum shake, slow return. Gun motion approved by the owner; Floppy's act awaits a verdict. [Current candidate/evidence](../inspect-revision.md#clear-canister-and-spring-driven-slug-act-2026-11-02-current).

**Confirmed/implemented correction, 2026-11-02:** Floppy's response is now only a look up with a little smile, then the HUD icon's wiggle; the hop and bum-shake act was rejected. Owner verdict pending. [Current candidate/evidence](../inspect-revision.md#smile-then-the-hud-wiggle-2026-11-02-current).

**Confirmed, owner, 2026-11-03:** Floppy's inspect approved: smile, soft wiggle with base stuck, small hop home, snug wiggle while lowering.

# Slug inspect briefs

**Confirmed, owner, 2026-11-02:** inspect is a shared one-handed blaster raise/lower with a different creature response for every species. The same action must read in first and third person. R is the initial rebindable key chosen for implementation.

| Species | Owner's requested response | Implementation state |
| --- | --- | --- |
| Floppy | Look at the holder, lazy smile, turn around and wiggle his bum | Runtime candidate using the existing root/head and facial bones; owner art approval pending |
| Inferno (owner corrected “Burpy” to Inferno) | Turn to look at the holder, make a little angry face, then lower the gun | Confirmed animation brief; runtime model/facial rig belongs to concurrent creature work and is not present in this branch |

**Implemented:** reusable raise/lower sampling and a species turn profile in `SlugInspect`. Floppy's inspect composes with his current idle and facial driver; the accepted Blender art is preserved. **Unresolved:** Inferno's rig-specific glare and runtime integration; subjective timing, readability through the chamber, and observer playback.

See [implementation and verification](../../loadout-controls.md). This record does not approve new abilities, change either slug's design or rename Inferno.

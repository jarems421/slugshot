# ADR 0027: Transforming slugs leave fast and slow down along their path

**Status:** Implemented, 2026-11-03, for owner playtest. Numbers are proposals.

**Context:** the owner wants the transformation and final form visible before a hit, while the whole thing stays quick. At Inferno's 500 studs/s, a 50-stud shot lasts 0.1 s. A first version flew slowly and then sped up; the owner rejected that: the slug must be fastest when fired and slow down after. Unlanded shots also flew for about 7 s, because the time limit counted time along the path.

**Decision:** `Combat.flightTime` maps real time to time along the unchanged closed-form path. A slug with a `Transformation` table starts at full speed and eases to `Cruise` (40%) with time constant `Slowdown` (0.04 s). Server and clients use the same function. Aim, drop and hit checks are untouched, and slugs without the table keep real time. A slug's `Expires` removes an unlanded shot that many real seconds after firing, on server and clients. Inferno uses `Combat.Cooldown`, so a shot ends as the next becomes ready.

**Consequences (calculated, full charge):** Inferno reaches 50 studs in about 0.19 s and 100 in about 0.44 s, against about 0.45 s and 0.95 s for Floppy. Range is about 310 studs. He holds 200 studs/s after the first moments, so long shots are slower than his launch number suggests. Close shots run the transformation faster so the swap still shows. Floppy still falls until it lands.

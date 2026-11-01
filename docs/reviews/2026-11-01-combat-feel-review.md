# Combat feel review (2026-11-01)

Status: **owner responded the same day.** Reviewed against what the owner asked for in the Codex combat chat.

| Item | Owner decision | State |
| --- | --- | --- |
| Sound | Later | Not started |
| Gun-tip shots, return cue, tuning panel | Yes | Implemented |
| Stronger front/back flip tilt, first-person landing | Yes | Implemented |
| Rounded underside, belly skid, steep rock and ledges | Yes; whole animation within 1.5 s | Implemented |
| Livelier wiggle and dig (owner's addition) | Yes | Implemented |
| Left-aim fix by turning the body | Yes | Implemented |
| Idle hands visible with arms still relaxed | Yes | Implemented, first pass |
| Distance limits for effects | Not needed: the owner expects at most 12 players per map | Dropped |
| Field-of-view framing | Owner checked it and it is good | Closed |

Implementation evidence: [review pass](../evidence/2026-11-01-review-pass.json). The findings below are the original review as written. Everything else remains Proposed.

How each finding was checked: **Measured** in a native Studio run ([numbers and limits](../evidence/2026-11-01-combat-review.json)), **Seen** in captures, or **Code** (read from source, not run). Feel can only be judged by playing. Running, recoil and flips were not re-measured here.

## Do first

| # | Proposal | Why | Check | Size |
| --- | --- | --- | --- | --- |
| 1 | Add sound: shot thunk scaled by charge, charge hum and ready tick, footsteps on the stride, flip whoosh, burrow scrape | There is no sound in the combat or movement clients. Many rounds of "I can't feel it" (recoil, legs, charge gravitas) were spent on visuals alone. Footsteps were already flagged as missing. Needs original or licensed audio. | Code | Medium |
| 2 | Spawn third-person shots at the real gun tip | The slug appears 1.1-1.4 studs from the tip, and up to 3.2 aiming left. First person already uses the real muzzle. The server's 6-stud limit allows it. | Measured | Small |
| 3 | Add a "slug is back" cue when the cooldown ends | Burrowing removed the visible return, and the canister refills silently. The owner described it "appearing back in your inventory". A small canister pop and slot pulse would mark it. | Code | Small |
| 4 | Scale effects down with distance and reuse parts | Up to about 340 debris parts per second at 16 shooters (10.7 shots/s × 32 parts), and about 32 skinned slugs recovering at once, with no distance limit. Phone play is a stated goal. This is arithmetic, not a load test. | Code | Medium |
| 5 | Build a live tuning panel for Studio | Grip took 2 rounds, recoil 4, the aiming arm 4 and first-person framing over 10, mostly "a bit more / too far". Sliders for shoulder width and depth, arm length, grip and kick would let the owner settle a value in one sitting. | Chat history | Medium |

## Gun mechanics

- **Recoil beyond the gun (Code):** the kick lives entirely in the gun. A small muzzle puff and a 1-2° field-of-view punch on full charge would add weight without moving aim.
- **Slug pops to full size at launch (Code):** it goes from canister size to 0.85 studs in one frame. A 0.1 s growth would read as launching out.
- **Charging shows nothing on the gun (Code):** the loaded slug could glow or wriggle in the canister while the ring fills. The ring stays the accurate readout.
- **Still untested:** whether the big kick reads while *running* in third person, which was the original complaint. Tap against full charge while moving has no evidence either.

## Flip mechanics

- **Front and back flips have a much weaker cue than side flips (Code):** Spot uses 8° of pitch against 19° of roll. The owner's complaint was that it felt like "a double jump". Trying about 12-14° pitch is cheap and stays reversible.
- **No first-person landing reaction (Code):** nothing reacts to touching down after a flip, because the old viewmodel's landing dip went with it. A small dip scaled by fall speed would finish the move, and would help "feel the legs" too.
- **Keep:** the steady aim and each flip's own arm choreography. The owner accepted these after many rounds.

## Slug burrowing

- **Flat underside (Seen):** rolled or diving, the flat base reads as a bright sawn-off disc with pale stripes. It is the most noticeable thing at gameplay distance. It needs a rounded, darker underside on the model, which changes an approved asset, so it needs the owner's go-ahead.
- **Slug stops dead on landing (Code):** a 100 studs/s shot goes straight to belly-down. A short belly skid in the travel direction suits the comedic brief.
- **Steep rock (Code):** while falling, surfaces steeper than about 56° are ignored, so the slug passes through them and may vanish silently. Real maps are rocky, so this will show up.
- **Ledges (Code):** the pile is placed on a flat plane, so near an edge it floats in the air.
- **Non-earth floors (Code):** digging into a wooden bridge looks wrong, and the lobby has rope bridges. Hard materials could use a different exit. The owner mentioned "depending on the terrain".
- **Overlap (Measured):** recovery lasts about 2.7-3.0 s against a 1.5 s cooldown, so the slug is back in the gun while the last one is still on the floor. The owner accepted this abstraction. Worth checking it still feels right when firing constantly.

## Gun placement in the hand

- **Aiming left leaves the gun far off target (Measured):** it points 33-47° away at left-side targets and within 5° elsewhere. Turning the body up to about 40° toward the target while charging, with the legs counter-rotated, would rarely reach the limit and reduce torso clipping. It changes the look the owner likes, so it needs a try-out.
- **Sector switch (Code):** moving from front to rear aim on the left swings the arm 100° through the torso over a few frames.
- **Housing near the trigger:** left as the owner asked. If the blaster mesh is touched again, slim that block then.

## First-person movement

- **Idle hands (Seen):** looking slightly above the horizon, neither hand nor gun was in view. The owner asked for them to be "a little bit visible" at rest. Later lean changes may have moved them, so this needs a look while playing.
- **Field of view (Code/docs):** arm framing was tuned at the default. Composition at 60 and 110 has never been checked, although the setting offers them.
- **Real frame rate:** much of the movement evidence ran near 15-17 FPS in background Studio. Smoothness has only really been judged by the owner.
- **Constants (Code):** framing values are spread through `Viewmodel.luau` with stacked multipliers such as `1.0738 * 1.12 * 0.9`. Consolidate them when the tuning panel is built.
- **Settings don't persist (docs):** crosshair and recoil choices reset each session. Fine for now; needed before players see it.

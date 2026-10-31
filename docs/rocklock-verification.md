# Rocklock validation

## Cavern art and stalactites — 2026-10-30

**Implemented/verified, limited:** Blender 4.5.14 generated the revised rock scene and crystal variants. Both FBX roundtrips preserved mesh count and dimensions. `python tools/verify_rocklock.py --output-suffix=-cavern4` passed foundation, movement, source-fidelity, collision flag, watertight triangle and budget checks, including that 12 stalactites are above y=45. The generated place has 6,458 parts, including 4,864 collidable rock wedges, under the 6,500 part budget. Blender renders include inspection-only fill lights and are not Roblox lighting evidence.

**Studio, one client:** in `-cavern3`, sampled raycasts hit three stalactites, an arch pillar, a haunch, a boundary skin and the west wall skin. The client walked the west approach and shelf, crossed the shelf and the underpass, and attached a west wall run at roughly 34 studs/s with no rejections in that successful sequence. An earlier attempt to reach the raised shelf directly from its side hit the shelf face; using the ramp succeeded. After lengthening the overhead formations for visibility, the final `-cavern4` was retested and the client again crossed the west shelf and underpass with no reported rejections. The final wall run was not repeated. The isolated tests were stopped afterward. **Unresolved:** in-game visual capture and owner judgment, the opposite route and wall, multiplayer, all collision seams and camera/limb clipping, and device performance. No performance benchmark was run.

## Rock-facet collision pass — 2026-10-30

**Implemented/verified, limited:** owner requested rock collision closely matching the visible rock silhouette, including recessed areas. In the separate `-accurate` place, all 4,800 rock wedges are collidable and queryable, with 0.035-stud authored thickness. Invisible rectangular proxies underneath stone skins are noncolliding/nonqueryable. Visible floor, tunnel and wall-run blocks still collide; crystals remain noncolliding. Automated foundation, movement and map checks passed, including the generated place's collision flags and geometry integrity.

**Studio observations:** downward collision rays hit both arch pillars, both haunches, keystone, one edge bridge rock, one rubble rock and one boundary skin. All 108 radial rays at y=5, 40 and 80 hit something, but interior rocks can intercept these rays, so this is not proof of complete boundary coverage. In a separate actual single-client play session, a character placed above the arch landed on its visible pillar facet at root y=35.03. After restarting, the character walked the west ramp and shelf, crossed that shelf, and walked through the underpass. A slide started toward the west run face and stopped at the wall; one `wallrun-state` rejection was reported afterward, cause unresolved. This test did not visually establish whether the animated legs penetrate the wall or whether the camera can see outside. A Studio screen capture was blank. The test place was stopped after inspection.

**Limits:** this is finite-thickness triangle-facet collision, not a zero-thickness mathematical surface; adjacent pieces overlap and seam behavior can vary. Surface shells are hollow inside, not volumetric solid rocks. Limb animation can extend beyond a character's physics collider and was not changed, especially because gun/animation work is concurrent. High-speed tunneling, all boundary corners, both wall directions, two-client behavior and the performance cost of 4,800 collidable rock wedges remain unverified. No device performance guarantee or exhaustive no-clipping claim is made.

Date: 2026-10-30. Studio 0.745.0.7451137, Windows desktop. Branch: `experiment/rocklock-greybox`, based on movement commit `913f9e6`. The source controller remains v7.37. This report separates the enlarged v3 from the earlier v1 and v2 geometry.

## Implemented/verified offline

**Implemented/verified v3:** the owner requested about 33% more space. The 160 ? 140 layout was scaled 1.33 in X and Z to **212.8 ? 186.2 studs**, with height and movement settings unchanged. The full `python tools/verify_rocklock.py --output-suffix=-v3` suite passed, including foundation/movement checks. Comparison of the authored layouts confirmed scaling for all 37 pieces and unchanged vertical dimensions; pitched tunnel-ramp sizes were excluded from that dimension comparison. The 83 Blender-generated rocks passed the offline FBX roundtrip. The map still contains 4,854 parts, including 35 solid collision pieces.

**Studio v3 checks:** the two spawns are 153.10 studs apart, with direct line of sight blocked by the north baffle. All 108 radial checks hit enclosing boundary collision at y=5, 40 and 80. Two isolated clients completed both flank routes, wall run/kick, the underpass, flips, slides and slide-jumps, observed their peer actions, and respawned at their assigned ends. Each had six accepted actions, zero rejections and zero corrections. [Sanitized evidence](evidence/2026-10-30-rocklock-v3.json).

**Unresolved correction:** one movement correction with `SuspectAirBoosts=1` was observed in the owner?s separate active v3 play session; 42 actions were accepted, none rejected, and the cause was not established. It did not recur in the two scripted routes, which do not cover all possible traversal. Do not infer that the correction is harmless or caused by the map.

**Test limits:** the first two-client attempt exceeded a seven-second spawn-route timeout in one background window, so the peer-action check also failed; rerunning with a longer route timeout passed. Both background windows averaged about 68 ms/rendered frame while multiple Studio instances were open, with focus/throttling uncontrolled. This is not a performance benchmark. Network incoming lag was 0; no emulation settings were changed.

- Portable, previously verified Blender 4.5.14 LTS ran headlessly. No installation, addon, new account, asset upload or publication was needed.
- v2: 160 × 140 footprint, 84-high ceiling, 83 original rock/stone objects, 2,464 exported mesh triangles; 4,854 native BaseParts, including 4,800 noncolliding art wedges and 35 solid collision pieces. Four solid wedge ramps are included in those 35 pieces.
- Blender exported FBX and reimported it: object count and bounding dimensions were unchanged. Generated rock meshes pass watertight-edge and nondegenerate-triangle checks. Roblox 3D Importer was not exercised.
- `python tools/verify_rocklock.py` runs and includes the existing movement/foundation checks: formatting, lint, strict types, builds, source fidelity and private/test isolation, plus map checks. It does not execute Roblox.
- Both public and private Rocklock builds contain the current movement scripts. Shared/client sources are unchanged; generated server source differs only at the initial spawn expression. Existing lab/foundation source and mappings remain unchanged.
- Eight Blender views were inspected. Revisions corrected cameras inside boundary rock, overbright Studio lighting, crowded corner approaches, ramp direction, flat wall presentation and the density explicitly rejected by the owner.

## Studio evidence and limits

See [sanitized runtime evidence](evidence/2026-10-30-rocklock.json) for results and failure details. Final results are recorded after the v2 two-client test, rather than inferred from the offline build.

**Confirmed v1 observations, superseded geometry:** both flank routes and 22-stud perches were walkable. The underpass, wall run, wall kick, double-jump flip, slide-jump, kong vault and mantle were observed with the current controller. A clear running first-jump sample travelled about 16.44 studs and rose about 10.85 studs. A separate attempt near cover triggered another action and was not counted as a first-jump envelope measurement. One `wallrun-state` rejection occurred during a compound approach; no corrections were observed. These checks do not certify the revised map.

**Confirmed v2 static Studio checks:** opposing markers are about 115.11 studs apart; the central spawn axis is blocked by the north cover. Runtime movement uses R6 and the Athletic profile. Decorative wedges are noncolliding/nonqueryable; interaction markers are disabled. The four solid ramps rise from approximately 0.13 to 9.87 at sampled points just inside their ends. The full enclosing wall/roof collision is separate from the decorative rock.

**Implemented/verified v2, two actual clients:** both north/west and south/east routes passed all 11 navigation waypoints, including ordinary ramp ascent to the 10-stud shelves, flank crossing/return and a full underpass crossing. Both wall runs reached about 34 studs/s; both wall kicks, directional double-jump flips, slides and slide-jumps were observed. Each client saw its peer's WallRun, WallHop, Flip and Slide attributes. Both reset to their original opposite spawn. Server counters: **6 accepted, 0 rejected and 0 corrections per player**. Running first jumps sampled about **16.46 studs horizontal travel and 10.87–10.88 rise**. These are two samples, not universal reach limits.

**Implemented/verified public fallback smoke:** the public map spawned R6 with `privateClips=0`; an original directional flip and slide played. Server counters: 2 accepted actions, 0 rejections, 0 corrections. Full two-client traversal used the private clip build.

**Implemented/verified, limited enclosure checks:** 108 radial rays at y=5, 40 and 80 all hit enclosing boundary collision; all 4,800 decorative wedges had collision/query/touch disabled. This supports enclosure/collision intent but does not replace an active escape/stuck playtest. After multiplayer testing, four decorative flank buttresses were shifted outward to clear the wall-running body's visual space; collision and controller behavior did not change. Final lighting adds two noncolliding lane-fill hosts to make the expanded floor readable.

**Observed performance, unresolved interpretation:** over roughly 34 seconds, the two windows recorded mean render intervals of 68.03 ms and 16.85 ms (95th percentiles 67.84 ms and 17.88 ms). Focus/background throttling was not controlled, so this is neither a minimum-spec result nor a claim of stable 60 FPS. Legitimate traversal passed in these sessions despite the difference. Studio also logged an asset-type mismatch warning from a built-in asset request; no map code asset ID or imported mesh request was introduced.

**QA fixture failure:** the first two-client harness tried to read plugin-only `settings()` from a normal server Script while reporting results. Studio rejected that call. The test was ended, the harness was corrected, and the test rerun. This was a test-harness error, not a passed multiplayer result. Network emulation was not changed; the parent Edit context reported `IncomingReplicationLag=0`. Other emulator settings were not exhaustively audited.

## Owner playtest checklist — unresolved

- Judge the **enlarged v3**, especially whether the central arch still occupies too much space, whether the cavern scale reads from the unchanged third-person camera, and whether the side routes deserve their height advantage.
- Run both ways through every flank and the tunnel; test wall runs, cling, up-run, wall jumps, flips, slide-jumps and mantles onto the actual shelves. The removed training stones/crowns are not part of v2.
- Check camera clipping/contact on irregular rock, both shoulders/shift-lock orientations and ledge edges. Collision proxies are intentionally simpler than ornament; no exhaustive stuck/penetration or escape fuzz test has been completed.
- Try a real two-person duel once gun/slug behavior exists. The requested engagement time and sightline distribution have not been combat-tested. Outer lanes can be longer than the original sightline target.
- Define representative transformed-slug sizes, then test their collision and ability volumes. No future body or projectile dimensions were invented as a gameplay rule.
- Test mobile/gamepad, low-end devices, actual 30/60/144 rendered FPS, latency/loss, and sustained performance. Short local desktop frame samples are not a device performance guarantee.

No combat, destruction, round reset, matchmaking, permanent map decision or publication was implemented.

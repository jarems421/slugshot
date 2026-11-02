# Project memory

## 2026-11-01 — Three distinct kicks

- **Confirmed:** owner wanted "bam, bam, bam" in every state, not "drawing back a bow", then "too much like your screen's just zooming in". Sharp gun kicks plus a view roll and eye shove, with little zoom, were accepted: "perfect, that's good now". Slide gun, ADS on the move, arc look and running vibration also approved. See [status](status.md).

## 2026-11-01 — Slide gun position

- **Confirmed report:** owner: the slide "sometimes corrupts the gun shooting like position", "usually when you're sliding to the left and to the right, and like diagonally backwards... Not like just a standard forward slide."
- **Cause:** a slide turns the body to its travel direction. `FirstPersonAction == "Slide"` also switched off steadying and run framing in `Viewmodel.luau`, so arm and gun followed the turned body.
- **Implemented/verified:** see [status](status.md) and [evidence](evidence/2026-11-01-slide-gun.json). **Unresolved:** owner verdict. Lesson: compare slide directions, and ignore frame 0 of a slide when measuring, because it is still the running arm pump (up to about 120 degrees off the view in every direction).

## 2026-11-01 — Face, clean charge crosshair and ADS

- **Confirmed:** owner chose the clean crosshair from four charge-display options. Asked for three auto-cycling facial expressions with blinks, eye and mouth motion. Asked for quick, frictionless Valorant-style ADS with a clear pane and their own crosshair.
- **Owner follow-up:** expressions are good. Third-person ADS rejected as buggy and removed. Frame must use the exact shape of the owner's Valorant screenshot, in black, opened by a clean mechanism on the gun.
- **Second follow-up:** hull outlines morphed with the viewing angle, so lid outlines are now painted into the skin. Scope frame only, 30% smaller, smoother open and close.
- **Third follow-up:** owner: resting eyes and blink were "off-putting" rather than "tired and sick and lazy", and one lid looked malformed. Lids, rest pose, blink and gaze retuned; values are on the P panel under Floppy face.
- **Fourth follow-up:** owner: "finally, it is good" on the eyes. Full-charge glow must be diffused and "ping and go away"; the ring on slug return was disliked and is removed.
- **Fifth follow-up:** owner wants the big Floppy by spawn kept. Asked for a brighter ping, then decided against the ping: "we need to figure out a different way to do this whole charge up mechanic", because vibration is too hard to feel while running and it is now the only gauge of shot power. Owner chose the three-stage wind-up (count clunks; "more skill based") and a 25% quicker charge, 0.6 s. Implemented; the ping is removed.
- **Accuracy:** owner reported shots landing bottom-right. Cause was droop plus the gun's offset, not a bug in the aim ray. The owner then made this a mechanic: one and two charges keep droop and shorter reach, and only a full charge lands on the crosshair, which rewards counting kicks. Taps must stay useful.
- **ADS stability:** owner: ADS must stay stable while charging; wind-up motion now fades out through the sight. Third-person muzzle down set to 22.
- **Decided, for the owner to overrule:** one-handed ADS; no movement-speed penalty. Expressions are drowsy, smiling and surprised.
- **Implemented/verified:** see [status](status.md), [ADR 0019](decisions/0019-one-handed-ads.md) and [evidence](evidence/2026-11-01-face-and-ads.json). Rollback IDs for the previous upload are in ignored `private-assets/floppy/before-face-rig`.
- **Unresolved:** see status. Only Floppy has a face rig; other slugs do not exist yet.

## 2026-11-01 — Second feedback round

- **Confirmed:** owner likes the burrow animation; stain circle removed pending a different impact effect; underside must match the body and have slug folds; idle arms lower; idle gun 30° up; charge light spins inside a still spiral; return burst replaced by a soft gloom.
- **Implemented/verified:** see [status](status.md) and [evidence](evidence/2026-11-01-second-feedback-round.json). Rollback IDs for the previous upload are in ignored `private-assets/floppy/before-folded-underside`.
- **Confirmed permanent:** Floppy is 1 stud outside the gun and keeps the current design; the owner corrected "all slugs" to Floppy only. Charge also got a gun-only vibration and a 6 turns/s light.
- **Confirmed:** Floppy buffed "so they're not completely useless": 7 damage (was 5), 65-115 studs/s (was 55-100), drag 1 (was 1.2). Gravity kept so it still droops.
- **Unresolved:** owner verdicts; goo beads on impact were kept because only the circle was named; not committed until the owner asks.

## 2026-11-01 — Review response built

- **Confirmed:** owner took most of the review: gun-tip shots, return cue, tuning panel, more flip tilt, landing reaction, rounded underside, belly skid, steep rock fix, left-aim fix, idle arms, and asked for a much livelier burrow. Sound later. Expects at most 12 players per map. Field-of-view framing already checked by the owner.
- **Decision to confirm:** "lasts the 1.5 second window" implemented as impact to gone, since flight time varies. This shrinks the earlier 2.7-3 s recovery and its 1.0 s dig to 0.43 s. Adjustable on the P panel.
- **Implemented/verified:** see [status](status.md) and [evidence](evidence/2026-11-01-review-pass.json). New private Floppy upload; rollback IDs in ignored `private-assets/floppy/before-rounded-underside`.
- **Unresolved:** all owner feel verdicts; the wedged-in-rock fallback untested; chamber fit of the deeper model not inspected.

## 2026-11-01 — Codex chat hand-off, burrow finish and review

- **Confirmed:** owner asked for the Codex combat chat to be audited against the docs, its interrupted burrow work finished, the range reopened and the finished work reviewed. The session log is `~/.codex/sessions/2026/10/31/rollout-2026-10-31T16-52-35-01a192e0-98a0-79e2-b4fc-168f6839e3f1.jsonl`.
- **Audit:** messages 2-45 were documented, committed and merged. Message 46 (branch merge) is recorded. Messages 47-75 had notes, but only uncommitted in the integration worktree, with these faults: `?` corruption, stale "current" statements, no wording lessons for grip/recoil/arm, and no record of the rejected return options. All repaired.
- **Implemented/verified:** corrected burrow debris after close-ups showed it near-black, round and plank-like. Real-shot regression, four floor types and six-shot frame times recorded. [Evidence](evidence/2026-11-01-floppy-earth-shapes.json).
- **Measured:** third-person shots spawn 1.1-3.2 studs from the gun tip. [Review](reviews/2026-11-01-combat-feel-review.md).
- **Unresolved:** owner burrow verdict, commit of the integration worktree, and which review proposals to take. Proposals are not approved work.

## 2026-11-01 - Floppy ground friction and messy debris

- **Confirmed:** owner called burrowing almost perfect but wanted the ground to move while digging, then dirt/rock to accumulate; more debris and less uniform placement.
- **Contextual language:** "friction" in burrowing means visible resistance and ground displacement synchronized with digging, rather than a slug simply sinking and debris appearing afterwards. "Messier" means varied sizes, clustered spacing, staggered emergence and tumbling, while keeping the effect local.
- **Implemented/verified:** 1.0-second descent, seven ground-colored/material-matched moving surface patches and 24 varied debris pieces. Full combat checks and a real native Studio target shot passed, including heave/tilt and cleanup; four views inspected. [Evidence](evidence/2026-11-01-floppy-ground-friction.json).
- **Unresolved:** owner friction/appearance verdict, other surface palettes, multiplayer/load. No actual Terrain edits or Blender asset changes.

## 2026-11-01 - Floppy roll and digging refinement

- **Confirmed:** owner wants Floppy to roll from belly onto back before burrowing; digging should visibly wriggle and gradually gather a small dirt/rock pile or ring with smooth transitions.
- **Implemented/verified:** eased 0.95-second roll, back-to-dive interpolation and 0.85-second active digging descent. Twelve small mounds/rocks gather progressively with ground-sampled colors, then settle/fade. A real native Studio shot completed the roll, dig and rim cleanup; full combat checks pass. Four views inspected. [Evidence](evidence/2026-11-01-floppy-roll-dig.json).
- **Lesson:** the first ring radius sat under Floppy's broad exposed base. Move it just beyond the body silhouette so it reads as gathering around the burrow, without making a large pile. This fixes the observed occlusion; subjective motion and size approval remain pending.

## 2026-11-01 - Floppy recovery implemented

- **Confirmed:** owner requested implementation: shoot, hit, fall to the floor, belly wriggle, jump and burrow straight down, representing return to inventory.
- **Implemented/verified:** procedural runtime animation on the existing imported rig, including duplicate eye/ink skeletons. Target hits fall to supporting ground; the model is removed only after its burrow. Recovery no longer reads cooldown readiness. Full combat offline checks pass. One actual native Studio target shot traversed every phase, survived beyond cooldown, hopped 0.649 studs, animated upper-body bones and dived head-first, then cleaned up. Four-view pose evidence captured. [Evidence](evidence/2026-11-01-floppy-recovery.json).
- **Unresolved:** owner timing/appearance verdict, wider surface coverage and multiplayer. No Blender source or asset upload changed. The normal target range was reopened after the temporary review session.

## 2026-11-01 - Local burrow recovery approved

- **Confirmed:** owner approved slugs recovering where they land: land, shake off, burrow, representing return to inventory. Floppy specifically lands on its belly, may wriggle, then makes a little upward hop and burrows.
- **Confirmed context:** the owner rejected puff disappearance and worried that distant returns timed to the 1.5-second cooldown would race across a crowded 16-player map. Gun/capsule destinations also complicate switching and hidden capsules. Local creature animation avoids that traffic; cooldown availability remains independent. Do not revive timer-driven puff or fast map-spanning returns as the default.
- **Documented, implementation pending:** [recovery specification](slugs/recovery.md), [ADR 0018](decisions/0018-local-slug-recovery.md), combat and Floppy catalogue updated. The current runtime still has 0.94-second return hops and a puff; this turn adds no animation/code changes. Exact timing and wall/water/surface handling remain unresolved.

## 2026-11-01 — Larger fired/returning slug

- **Confirmed:** owner wants the slug small only for chamber fit, with a more visible 0.75–1 stud presentation after firing and on return. **Implemented/verified offline:** outside-barrel visual height 0.55 → 0.85 studs, shared by flight/impact/hops; loaded chamber fit and 0.3-stud hit radius remain separate. Combat checks passed and range reopened. Owner visual verdict pending.

## 2026-11-01 — Slower return hops

- **Confirmed/implemented:** owner requested about 33% faster after trying 1.25 seconds. Current duration is 0.94 seconds (1.25 / 1.33, rounded). Combat offline checks pass; range reopened, owner verdict pending.

- **Confirmed:** owner requests roughly 150% slower slug hopping after impact. **Implemented/verified offline:** return duration 0.5 → 1.25 seconds (150% more time), keeping the existing arcs and cooldown/puff behavior. Combat checks passed and range reopened. Owner speed and runtime appearance verdict pending.

## 2026-11-01 — Large base recoil and optional flip/catch

- **Confirmed:** earlier recoil remained too subtle. Owner explicitly requests a big upward base kick and a selectable post-shot gun flip/catch inspired by the existing draw animation, with a Slugterra-esque feel. Do not continue interpreting this as merely a slight kick.
- **Implemented/verified:** Kick up default and Flip & catch in Settings → Gameplay; charge scales the kick, the alternate reuses the accepted Toss.Draw curve. First-person gun recoil now applies directly after smoothing instead of relying on the hidden tool joint update. Native Studio full-charge pitch rises: Kick 36.94 degrees, Flip 32.10 degrees; both server-accepted, re-equip passed, bounded sample/endpoints passed. Combat offline checks pass. [Evidence](evidence/2026-11-01-recoil-options.json).
- **Unresolved:** owner subjective verdict, moving/tap feel, high-FPS and multiplayer playback. Recoil options are session-local and cosmetic.

## 2026-11-01 — Small gun recoil

- **Confirmed:** previous charge-scaled kick remained too subtle. Owner asked for “more animated,” slightly more dramatic recoil. **Implemented/verified offline:** changed timing to fast attack, readable peak, eased recovery and subtle settle; added first-person hand follow-through after smoothing. This interpretation of “animated” awaits acceptance. Combat checks passed and range reopened.

- **Confirmed:** initial recoil was too hard to notice while running; owner wants more upward kick, increasing with charge but capped. **Implemented/verified offline:** charge-scaled upward lift and wrist pitch, 30 ms attack / 230 ms recovery; accepted Shot events carry validated charge for observers. Combat checks passed; owner running/charge comparison pending.

- **Confirmed:** owner wants a small but noticeable gun kick when firing. **Implemented/verified offline:** shot-triggered cosmetic wrist recoil shared by first/third-person gun presentation; quick rise and return, no accumulation, aim stabilization preserves it. Combat checks passed and range reopened. Live feel and observer playback pending.

## 2026-11-01 — First-person gun tilt while shooting

- **Confirmed:** owner wants moving arms and fluidity, with substantially less movement-driven gun tilt during charging/firing. “Steady” here means settling the gun angle while retaining arm travel and positional motion.
- **Implemented/verified offline:** first-person hand/gun share aim-angle stabilization with slight residual angular motion and a short transition; acrobatic actions/flourishes release it. Combat checks passed and range reopened. Live feel and shooting verdict pending.

## 2026-11-01 — Third-person charging arm

- **Confirmed:** full arm-bounds clearance looked far too detached. Owner accepts slight torso overlap and requests rear aiming behind the back. **Implemented/verified offline:** capped shoulder shift at 0.22 studs and added front/rear sectors with 40-degree inward reach from either direction. Small side-boundary hysteresis and pose smoothing; combat checks pass. Visual/runtime verdict pending.

- **Confirmed:** wider aiming arc again swallowed the arm; owner supplied `Screenshot 2026-11-01 122739.png` as the maximum inward/backward pose. **Root cause found:** `chord()` retained rotation only, discarding the previous shoulder translation. **Implemented/verified offline:** apply R6 bounds-based forward clearance after limb folding, with tighter yaw limits; combat checks pass and range reopened. Owner visual/runtime verdict pending.

- **Confirmed:** owner found the first shoulder limit too restrictive for targets behind; wants the arm to reach as far as possible with a forward shoulder shift to avoid the body. **Implemented:** widened the aiming arc and added forward/outward clearance and rear-transition smoothing. Combat checks passed; live visual assessment remains.

- **Confirmed:** owner likes cursor tracking while charging but reports the arm and gun folding into the torso or behind the character at extreme relative angles.
- **Implemented/verified offline:** bounded third-person arm tracking and added modest shoulder clearance without changing the firing ray; extreme gun orientation may therefore differ from shot direction. Local first-person pose is unchanged. Combat checks passed and the range reopened; live appearance and shooting remain for testing.

## 2026-11-01 — Third-person blaster fit

- **Confirmed:** owner likes the revised hold much better. The dark housing around the illuminated line and circle can read chunky and hide the trigger from one view, but is low priority; leave it unless a clean improvement is found. No mesh or pose change made.

- **Confirmed:** initial grip change looked nearly the same to the owner. **Implemented:** increased downward angle from 3 to 9 degrees and upward shift from 0.07 to 0.18 studs; rebuilt and reopened the range. Combat checks passed offline; visual verdict pending.

- **Confirmed:** owner requested subtle third-person changes to angle the muzzle down, expose more grip and move the gun slightly up toward the trigger; preserve first person.
- **Implemented/verified offline:** a client presentation grip offset composes with the existing wrist and flourish, and is disabled for the local first-person view. Combat checks passed. Owner visual and Studio runtime verdict pending.

## 2026-11-01 — Crosshair centering and gun training range

- **Confirmed:** owner reported the crosshair drifting down and right while resizing and requested a separate training arena with the latest blaster and Floppy designs for gun mechanics work.
- **Implemented/verified offline:** centered-frame resize replaces the mark UIScale; Ring Dot stroke follows the chosen size. `python tools/verify_combat.py` passed. The range was rebuilt with the latest available private blaster and Floppy mappings and opened separately from the lobby Studio window.
- **Unresolved:** owner visual centering and refreshed Studio asset/shooting playback.

## 2026-11-01 — Main integration of committed branches

- **Confirmed:** owner authorized review, merge and push of committed branches ahead of main, including concurrent lobby/design work. Live worktrees were left untouched.
- **Implemented/verified offline:** merged creature, lobby and wall terrain histories into main integration. Preserved the later first-person combat camera, controls, reticle and single Athletic movement profile where older wall-run copies conflicted; terrain-following traversal was already present. Marked the 12-stud Eyrie to West Abutment route as a sprint jump after the pace retune. Renumbered creature ADRs to 0016 and 0017 to remove collisions. Creature Blender, combat and Rocklock V2 offline checks passed.
- **Unresolved:** Studio runtime and visual comparison of the combined snapshot; no private asset IDs or experience publication in this integration.



## 2026-10-31 — Review and backup of all local work

- **Confirmed:** owner requested review of the Claude handoff, final Floppy and blaster plus committing/pushing all work including movement.
- **Implemented/verified offline:** live multi-angle/idle review, source/export hashes, FBX reimport, full creature/movement checks and both Rocklock offline checks. [Detailed review](reviews/2026-10-31-work-review.md) records exact findings, branch separation and remaining gates.
- **Unresolved:** game-mesh winding/degenerate-face cleanup, genuine chamber illumination, Studio runtime/peers, slower-controller map integration and owner verdict. Art unchanged; private assets/IDs remain ignored.



## 2026-11-01 - Look test round 4: inside-out pieces, boundary ink, import axes

- **Confirmed:** owner said the look was better but some wall mushrooms rendered as black voids with no glow, sprout bases looked odd, few crystals showed and sparkles came from rock gaps.
- **Implemented/verified offline:** island check showed Blender's normal recalculation had flipped 13/52 wall caps, 15/34 stems, 7/32 crystals (half the crystal faces) and part of the gate. Builds keep the marching-cubes winding with a per-island guard; recheck reads zero flipped islands in every group. Boundary ink coverage fell from 63/42/23% (stems/caps/crystals) to 4/7/2%. Effect points now use a measured axis flip. StyLua, Selene, luau-lsp clean; Rojo build; Blender previews (back-face culled, low view) inspected. [Lessons](art/lessons.md).
- **Unresolved:** owner Studio verdict and the logged import-axes result.

## 2026-11-01 - Look test round 5: gate bands, stable lighting, vivid small caps

- **Confirmed:** owner said it looked better; the gate's iron band outlines looked corrupted (front and back), the lighting kept changing between views, and small mushrooms looked dull and pale.
- **Implemented/verified offline:** band edges bevelled 0.05 in the concept (library v15, gate turntables re-rendered); gate sampled at 0.04 with 4,000 iron triangles; close-up renders show clean outlines front and back, and every island faces outward. Nearby glows merged into shared lights (about 300 to about 90). Zone moods shift colour only. Small-cap colours deepened, glow strength 3.4 to 2.3. StyLua, Selene, luau-lsp clean; Rojo build.
- **Unresolved:** owner Studio verdict. The idea that Roblox's light limit caused the shifting is inferred from the light count, not measured.

## 2026-11-01 - Look test round 6: brighter small caps, rock texture options

- **Confirmed:** owner said small mushrooms have colour now but feel too dim; rocks look basic and need texture on a scattered portion (not moss everywhere).
- **Implemented/verified offline:** small-cap glow peak 1.0 to 1.6 (strength about 3.3) and cap lights 1.6; repainted, privately re-uploaded, fresh look-test window. Rock wall texture options in the library v16: carved fractures, mineral veins, weathering and lichen, chipped facets, mixed. Option 1 is pixel-identical to v6 (max diff 0). Turntables inspected; pockmarks rejected internally as bullet-hole-like.
- **Unresolved:** owner's pick; Roblox build of the chosen option.

## 2026-11-01 - Look test round 7: graphics-quality lighting flip, rock wall study

- **Confirmed:** owner showed identical shots with different lighting and wants the brighter one always; rejected round 6 rock options (squiggle cracks, deformed rocks) and asked for a separate rock artifact with Slugterra-style cracks on a third of the rocks per wall (different per wall, evenly spread), one unique texture and one general texture on all rocks.
- **Implemented/verified offline:** wall lights no longer cast shadows (the diagnosis that automatic graphics quality caused the flip is inferred from the screenshots). Rock shader rebuilt: angular, forked V-groove cracks (one per column, never the top row), fossil ammonite shells on two rocks, and grain, edge wear and crevice hatching on all rocks. Rock shapes unchanged; option 1 pixel-identical to v6. Turntables inspected over three iterations. [Rock Wall Study](https://claude.ai/artifact/N6fQNix47YnjrbyDbTig6C) published; library v17.
- **Unresolved:** owner verdict; Roblox build of the chosen layers as four wall variants.

## 2026-11-01 - Rock wall study round 8: real cracks only

- **Confirmed:** owner loves the carved cracks and wants a few more; remove the faint squiggly lines; fossil shells not wanted.
- **Implemented/verified offline:** cracks on five of the twelve big rocks with second cracks on about half; v6 painted cracks and buried-root boundary arcs removed from the study (surface ring test in the concept, convex lines off for study rock in the concept and painter); fossil code removed. Option 1 within 2 of 255 levels of v6. Turntables inspected; study page v2 and library v18 published.
- **Unresolved:** owner's final look; Roblox build of walls A to D.

## 2026-11-01 - Rock wall base design and Roblox walls A-D

- **Confirmed:** owner wanted a few more crystals (top left was bland) and asked for this to be the base design for rock walls, with crack, moss, mushroom and crystal positions changing per wall and every corner filled; then put it in the Roblox Studio look test.
- **Implemented/verified offline:** region-based dressing per wall (six regions, three crystal and three mushroom clusters shuffled, tiny mushrooms everywhere; 6-7 crystals per wall), measured on each wall's cracked surface; moss shifted per wall. v6 anchors frozen (they had drifted up to about 0.2 studs from the current surface). Walls A-D built, island orientation checked, privately uploaded, and alternating in the look-test ring.
- **Unresolved:** owner's Studio verdict.

## 2026-11-01 - Lobby round 10: crack spread, gate bands, moderation check

- **Confirmed:** owner loves the base wall design; reported one wall rendering oddly, top-left cracks rare, and one gate band unlike the others; asked to start Floppy and the blaster next.
- **Implemented/verified offline:** per-region crack picks (top-left cracks on three of four walls), top-row cracks from the lower rim, bands sized to each block. Rebuilt gate and walls A-D; islands outward; all uploaded assets Approved before reopening Studio. Odd wall attributed to pending moderation (inferred; textures were complete and Approved on read-back).
- **Unresolved:** owner's Studio check.

## 2026-11-01 - Floppy and the blaster in the Slugshot look; barrel options

- **Confirmed:** owner asked for Floppy and the blaster in the new style in their own artifact, and a more dangerous-looking barrel without a redesign or colour change.
- **Implemented/verified offline:** barrel variants from a copy of the accepted blaster (fangs, claws, armour and vents, combined) and turntable renders in the look; renders inspected (fangs enlarged after review). Page published.
- **Unresolved:** owner's choice; Roblox ink shells and glow for both.

## 2026-11-01 - Blaster: curved pincer tips

- **Confirmed:** owner dislikes the planar slanted tips and their corner on every option; bottom prong should point up; facing tips need a feature; front view needs a detail.
- **Implemented/verified offline:** tips lofted from the prongs' own cross-sections in four options; turntables inspected (a charge-node ray-cast fix after review). Page updated with Floppy's new bulbs and spots.
- **Unresolved:** owner's pick.

## 2026-11-01 - Blaster bladed ridge final, in Roblox

- **Confirmed:** owner picked the bladed ridge; asked to remove the dip before the blade, shorten about 15%, then make it the Roblox model.
- **Implemented/verified offline:** revised tip from a clean cut with slope lead and a ridge that only lowers; export with ink shells (orange part decimated to 7k), private upload Approved, mapping updated, Floppy test place rebuilt and opened.
- **Unresolved:** Studio check and owner verdict.

## 2026-11-01 - Documentation checkpoint for this chat

- **Confirmed:** owner asked to update all documentation from this chat (design, wording, lessons) and push as a checkpoint; Codex is doing the same for its own chat.
- **Implemented:** style guide gains the Roblox lighting rules and the character look; lobby assets records what is built; owner design language gains this chat's phrases and dictation slips. Detailed rounds remain in `docs/art/lessons.md`, `docs/art/look-pack.md`, `docs/slugs/blaster-refinement.md` and the Floppy catalogue entry (slug pipeline branch).




## 2026-10-31 - Blender skill routing guide

- Rewrote `docs/slugs/skill-routing.md` from the actual installed `SKILL.md` files (28 EL4CTEO, 30 RobLe3, 1 project). Replaced the generated inventory and removed `build_skill_routing.py`; `check_skill_routing.py` now checks coverage.
- Confirmed: the installed `blender` MCP lacks RobLe3's legacy tool names, local Python has no `cv2`, and RobLe3's world reset must not run on existing scenes.
- A disposable 5.2 probe passed all five routing cases. FBX roundtrip renames clips and can copy actions to stray objects (see lessons).
- Added `slugshot-creature-production`, an 11-step creature procedure using the routing guide as its manual. The orchestrator is kept as its short summary. A fresh Claude session auto-selected it and routed correctly. The Codex test was blocked by its usage limit.

## 2026-10-31 - Floppy silhouette/face variant
- The owner rejected the baseline look ("too solid and hard", eyes "glued on", lifeless mouth) and asked for a drowsy/drunk slug with spinning spiral eyes. Built `create_floppy_variant.py` as a separate variant; baseline untouched. Owner review pending.
- Owner calls the species "Floppy". That name is very close to the franchise "Flopper", so a final name stays Unresolved.
- Follow-up: added drool, jaw sag and faster spiral spin, an hourglass front, and eye rims; removed the lid crease. Opened the variant in the owner's live Blender.
- Second follow-up: domed eyes with lid shells, mirrored sockets and bags, brows and crown markings, flared antenna roots, a short tail, and squishier shape, material and animation. Reloaded the variant in the owner's Blender.
- The owner chose to agree the design on paper before more 3D work, and confirmed the tail stays short. Published a private concept sheet (four front/side body plans: Pear Puddle, Upright Trailer, Slumped Sleeper, Low Crawler, plus a face study): https://claude.ai/artifact/5FPBsEBNTuVZbbo34waKX8. Waiting for the owner's pick.
- The owner preferred concept C (Slumped Sleeper) but said the 2D drawings looked like flat shapes on a silhouette with no visible belly and no jelly or slime. They asked for closed concentric rings instead of a spiral, arranged differently in each eye and spinning, and for a dark comic-style drool drip in the mouth colour instead of a blue blob. Published a rotatable real-time 3D concept (blended soft volumes, jelly shading, ring eyes): https://claude.ai/artifact/MwVjdTDUNVQPdccC37VJyo. Its blended-volume construction could map to Blender metaballs/voxel remeshing for the game model. Waiting for owner review.
- Owner feedback on the 3D concept: drool should come out of the mouth like their anime reference (a pale strand whose dark outline continues the mouth line), not sit on top; eyes bulged like bug eyes; antennae looked angular. Concept v2 has a drool strand from inside the mouth with a toon outline, shallow lens-shaped eyes, and single smooth-curve antennae.
- Owner: drool must be part of the mouth, dropping from the bottom lip with no separate piece; motion was too bouncy (especially the top half); cheeks too chubby. Concept v3: drool drawn on the skin from the lower lip with the mouth's outline, wobble cut to about a third and slowed, slimmer cheeks.
- Owner: drool must continue from the bottom lip with no top bulb; the eyes poked out below the lids and looked crazy rather than drowsy; the dark eye patches were gone; the head was too wide and bulbous. Concept v4: drool starts inside the mouth so only the part below the lip shows; lower lids added and upper lids half-closed; slower spin and thinner rings; dark under-eye patches restored; narrower head with the face refitted.
- Owner: top of the head looked flat from the front; asked for antennae higher, a taller rounder head, a more drowsy/stoned grin, drool a tad right of the mouth corner, and a base that sticks to the floor instead of looking like a chess piece. Concept v5: crown dome and taller head, antenna roots raised, lazy lopsided grin, drool moved toward the centre, body melting into a soft spread foot (a flat plate attempt looked like a candle holder and was replaced).
- Owner: fill the sunken upper corners of the head so it reads round; smaller cheeks; shorten the mouth where it reached the eyelid; foot should stick to the floor like a snail's rather than round off; antennae further forward on the forehead at the same spacing. Concept v6: wider crown dome, smaller cheeks, shorter and lower mouth, a thin sole blended in with a concave fillet under a wider lower body, antenna roots moved forward.
- Owner: dark under-eye patches more prominent; eyes still bulged. Concept v7: larger, darker under-eye patches; eye lenses flatter (depth 0.11 to 0.07) and the eye/lid set sunk further into the face.
- Owner: remove the green dots for now (they clashed with the dark patches); make the under-eye darkness diffuse rather than a concentrated oval; remove the under-eye bulge and the eyebrow-like ridges. Concept v8: freckles, brow ridges and under-eye puff removed; wide, soft, uneven dark shading under the eyes.
- Owner: the diffuse patches looked like bruising; wanted normal tired dark circles under the lower lid, following the eye's round outline. Concept v9: a soft brown-grey crescent just outside the lower lid edge.
- Owner likes how the eye edges blend into the face (keep this). Asked for eyes slightly more raised and slightly further apart; the dark circles read as a vague shadow ring, not eye bags. Concept v10: eye depth 0.085 and eyes at x ±0.37; bags are now a mauve-brown crescent of darker skin under each lower lid, thickest in the middle.
- Owner: the lower lid looked multi-layered after the bags were added, and the darkness should diffuse onto the lids; 'almost there, basically perfect'. Concept v11: removed the hard bag edge and the lid tint ring, blended the lids more softly, and faded the darkness up onto the lower lid. Lesson: hard colour edges near a geometric lid edge read as extra layers.
- Owner: 'genuinely almost perfect'. Asked for a slightly smaller eye-bag area with a softer outer fade. Concept v12: smaller Gaussian-falloff bag that fades into the skin on every side.
- Owner: eye-bag size 'perfect' after re-expanding. Final tweak: antennae further forward on the forehead and the head top raised a little more. Concept v14: head and crown dome taller, antenna roots further forward.
- Owner called the concept 'perfect' after the head/antenna change. Final tweak: thicker rings that vary in thickness within each eye; the more open eye (character's right, viewer's left) has clearly bolder rings. Concept v15 published, and a copy of the concept source was saved as the build reference at docs/slugs/catalog/evidence/floppy-concept-3d.html.
- Owner: the base looked too flat, uniform, cleanly flared, slightly cut off, like a smooth bell; wanted a soft, bodyweight, squishy pooled edge with a subtle slime base, natural and asymmetric. Concept v16: lobed, asymmetric sagging lower mass with a thin rounded pooled edge, a see-through glossy slime film around it, wetter skin near the floor. Reference copy updated.
- Owner loves the new base. Asked to remove the slime film for now; a slime trail is a possible later addition (Considering, not approved). Concept v17: slime film and floor sheen removed, base unchanged, reference copy updated.
- Owner approved Floppy V1 ('this is perfect'). Saved the source and five renders to docs/slugs/catalog/evidence/floppy/, recorded the design spec in the catalogue, and deleted the rejected Blender variant and earlier concept files at the owner's request. Next: touch-up details, then the Blender build.
- Deleted the round-1 concept sheet page (its link no longer works).
- Owner supplied the Floppy palette (#91B8AE body, #8996AC upper lids, #31585B lower lids, #D8D3BE belly, #527F79 back markings) and asked for improvised, original, restrained patterns plus darker antenna stripes. Applied in the V1 page with spine lozenges and petrol-teal antenna stripes; reference copy and renders refreshed.
- Owner: the palette looked way too blue; wanted green/brown, belly stripes, no antenna stripes and coloured antenna-tip bulbs. Applied a warmer sage/taupe/moss/stone palette (hex values in the catalogue); reference copy and renders refreshed.
- Owner: upper lids too light; they should be a darker green, a bit darker than the skin but lighter than the lower lids. Belly stripes should be more prominent but still blend. Applied #7A8C62 lids and #A8946E stripes at higher strength; reference refreshed.
- Owner: body green should be paler and more yellow, closer to (but not matching) the belly; belly stripes should be the same colour strength. Applied #BAC1A2 body, #9CA77F lids, lighter back shading and an even stripe mask; reference refreshed.
- Owner: lower lids should be a muddy brownish green; add a brown outline around the belly enclosing the stripes; denser stripe colour; body a tiny bit darker with more yellow-brown-green. Applied #5A5934 lids, a #6B4E2E belly outline, #8E7550 stripes and a #B0B48A body; reference refreshed.
- Owner found the brown belly outline ugly; switched to a softer muddy brown-green outline (#6E6B3E). Reference refreshed.
- Owner disliked the painted brown belly stripes and chose soft belly folds: real geometric rolls with creases, uneven spacing and depth, inside the green outline. Reference refreshed.
- Owner: the folds looked like creases; wanted actual folds. Changed the profile to overhanging rolls (steep tucked underside, gentle top), made them fewer and fuller. Reference refreshed.
- Owner: upper lids a little darker than the skin but less dark than the lower lids. Applied #888F68; reference refreshed.
- Owner: 'this is perfect... this is the Floppy design. This is our Floppy.' Renamed the page and record to Floppy, replaced the V1 save with docs/slugs/catalog/evidence/floppy/ (floppy.html plus five renders). The committed baseline Blender model is still kept pending the owner's decision.
- Built Floppy in Blender with tools/slugs/build_floppy.py (concept SDF ported to NumPy, surface nets, exact texture bake, ring-eye textures, 9-bone rig, 12 s looping idle). Concept motion rates aligned to the loop. Opened in the owner's Blender. Game-budget version and FBX/Studio are next.
- Owner: the build is perfect but too pale; wanted more depth, then the Roblox version. Added baked AO, a deeper grade and less SSS. Made the Roblox export (8k body, 400 per eye, 1024 maps, 8 bones, scale-free 12 s idle, faces -Z in Roblox). Verified by FBX reimport. Studio import is the owner's step (no Studio connection; importing uploads assets).
- Owner approved uploading Floppy to their account; uploaded the GLB via Open Cloud (ID kept in private-assets). Added a Floppy test place with a client-side idle and opened it in a new Studio window (Rocklock's Studio left open). Registered the Roblox Studio MCP at user scope so every worktree gets it after a restart.
- Owner: Floppy looks the same in Studio, but needs a subtle slimy gloss and must fit in the blasters. Export now at 0.09 scale (0.22 studs, asserted against the blaster canister) with roughness maps; re-uploaded; test place shows Floppy on a pedestal next to the blaster.
- Owner: the blaster-sized Floppy (0.22 studs) was invisible; set it to about 1 stud tall and said the gun will be resized to fit. More gloss on the bottom half. Export now 0.405 scale (1.0 stud) with base-to-head roughness 0.10 to 0.22; re-uploaded; test place reopened.
- Owner: about 33% smaller, mostly thinner, mainly a narrower base. Narrowed base/pooled edge/tail in the concept and build; export now 0.304 scale (0.60 × 0.54 × 0.75 studs); re-uploaded; test place reopened.
- Owner: 0.75 studs is the smallest a slug should be; make it a little taller, not thicker; resize the gun so the slug fits in the shell and let them equip it. Torso-only stretch (0.83 studs); display blaster Tool scaled 3.05x in the Floppy test place with Floppy in a glass canister; real Rocklock blaster untouched (out of scope here).
- Owner: the 3x blaster was ridiculously big; slugs should be a bit bigger on the ground and shrink when loaded. Ground Floppy 0.34 scale (0.92 studs); test blaster back to Rocklock size; loaded Floppy scaled at runtime to the canister; idle scale derived per model from eye spacing.
- Owner: loaded Floppy far too small for the canister. The fit used an inflated bounding box; now sized from eye spacing and source dimensions and centred on the root bone, so he fills the shell.
- Owner: brighten the chamber so the loaded slug shows better. The canister glass is now clearer (0.78 transparency, pale tint) with a soft PointLight inside.
- Owner: the clear glass read as dark, not lit. The chamber is now faint see-through neon (0.86 transparency) with a stronger inside light and a soft Highlight fill on the loaded slug.
- Owner: the slug looked pale/white inside (the white Highlight fill); wanted deep blue glass that glows as the light source. Removed the fill; canister now deep blue see-through neon (0.72) with a blue PointLight.
- Owner: glass good, but the slug looked dark blue. Inside light now neutral warm white (brightness 4); glass more see-through (0.82) but still glowing blue.
- Owner: slug still deep blue; glass should glow without tinting the slug; dark sky to show the glow. A neon shell tints whatever is behind it, so the canister is now clear lightly-blue Glass (0.88) with neon blue rings and edge strips, a warm 3-stud light inside, and the test place is at night with bloom and a lamp on the pedestal.
- Owner: glow underwhelming and not lighting the slug. Glass material blurred/darkened him; shell now clear SmoothPlastic (0.9), two warm white lamps beside the slug, a blue 6-stud area glow, thicker neon trim and stronger bloom. Lesson: Roblox Glass blurs what's behind it and Neon tints it; light the subject with nearby lights.
- Owner: blue too strong/neon; wanted a clear, light-blue, subtler glow with the inside of the shell well lit. Trim now pale blue at 0.45 transparency and thinner, spill light pale and weak (1.2, 3.5 studs), bloom reduced, inside lamps slightly stronger.
- Owner: lighting flickered between an orange-flare state and a dark state; the inside wasn't lit. Small PointLights inside the gun flicker with Roblox light culling and flared the orange prongs. Removed them; the loaded slug now has a constant sage-green Highlight fill (0.55); one faint pale-blue spill light remains. Lesson: don't rely on tiny interior lights for visibility.
- Owner: light the inside calmly and lightly, not pale. Inner sage glow softened to 0.72 fill transparency. Session paused here at the owner's request; open items: owner verdict on the chamber glow, resizing the real Rocklock blaster (other branch), Studio MCP available after a session restart.

## 2026-10-31 — Review and backup of all local work

- **Confirmed:** owner requested review of the Claude handoff, final Floppy and blaster plus committing/pushing all work including movement.
- **Implemented/verified offline:** live multi-angle/idle review, source/export hashes, FBX reimport, full creature/movement checks and both Rocklock offline checks. [Detailed review](reviews/2026-10-31-work-review.md) records exact findings, branch separation and remaining gates.
- **Unresolved:** game-mesh winding/degenerate-face cleanup, genuine chamber illumination, Studio runtime/peers, slower-controller map integration and owner verdict. Art unchanged; private assets/IDs remain ignored.

## 2026-10-31 - Floppy chamber and gun repairs

- **Confirmed:** owner reported corruption, asked for a shorter handle, 12% smaller gun, topology and actual chamber illumination fixes. Follow-up: geometry looked fine; requested belly-down and reported both copies lost colour.
- **Implemented/verified offline:** preserved source baseline, added repaired variant; source/game QA clear of prior errors; FBX and full creature checks pass. Grip shortened 18% and tools scaled 0.88. Uniform whole-model placement, duplicate bone-set motion, inward neutral SurfaceLight. Explicit Image maps plus private PBR templates replace unavailable importer textures confirmed in Studio logs. New ColoursFixed place opened.
- **Unresolved:** final material/pose/light/fit approval and imported runtime evidence. [Detailed repair](slugs/floppy-chamber-repair.md).
- **Verified, limited Studio sample:** owner-started ColoursFixed Play logged four loaded parts, eight bones, a material, completed belly-down placement, and pedestal/equipped idle initialization; no earlier texture-pack or Floppy errors in that sample. Colour/light/contact still need owner visual approval.

## 2026-10-31 - Angular blaster and lighting visibility

- **Confirmed:** owner approved the burnt-orange/graphite preview, rejected upward-flared tips, and specified downward angular cuts retaining the central firing gap and barrel reach. Slug animation is for the next pass.
- **Implemented/verified offline:** compact proportions, solid capped downward muzzle bevels and nine clear channel rays; white spiral vanes, metal/grip separation. Broad shadowless fills and constant albedo-modulated material emission replace dependence on tiny light pools. Full creature/Blender checks and targeted Rocklock verifier pass. [Evidence, QA findings and limitations](slugs/blaster-refinement.md).
- **Unresolved:** owner verdict on the final angular tips and lighting over time; generic gun QA retains rear mechanical-contact flags. Studio launch reported low resources with eight existing windows, which were preserved. No slug animation changes or experience publication.

## 2026-10-31 — Original blaster draw/holster

- **Confirmed:** owner wants quick, expressive wrist twists for drawing/putting away, fitted to the Roblox hand, with no throws or body spins.
- **Implemented/verified offline:** original 0.42/0.34 s gestures, shared Floppy/Rocklock driver, native-grip additive poses and skinned/PBR-preserving cosmetic holster. Creature/movement/type/lint and numerical R6 sampling pass; [sources and evidence](slugs/blaster-motion.md).
- **Unresolved:** actual Studio feel, rapid switching/death, peer rendering and owner art approval; official trailers were located but could not be downloaded, so no shot-specific motion claim.

## 2026-10-31 — Solid angular blaster muzzle

- **Confirmed:** slightly extend barrel; lengthen/flatten downward slants; fill the two oval side vents with orange while keeping the central slug channel.
- **Implemented/verified offline:** +0.080 stud muzzle reach, 0.24 versus 0.14 source-unit bevel run, solid front panels extruded from the existing cross-section. Orange mesh QA and exact-overlap checks pass; nine channel rays and six solid-panel samples pass; twelve GLB mesh bounds reimport exactly. Private mappings and test builds updated. [Evidence and inherited limits](slugs/blaster-refinement.md#solid-muzzle-and-shallower-bevel-follow-up-2026-10-31).
- **Unresolved:** owner visual verdict and refreshed Studio playback. Existing rear contact flags remain; accepted files and eight prior Studio windows preserved.

## 2026-10-31 - Owner design language record

- **Confirmed:** owner asked that lessons from the Floppy design rounds be recorded so later slugs avoid the same errors, including what their phrases mean in practice (e.g. "dark spots").
- **Implemented:** [owner design language](slugs/owner-design-language.md) collects phrase-to-outcome mappings drawn only from recorded rounds, the owner's working style, and the draw/holster runtime lessons from `experiment/rocklock-unified`. The creature-production procedure (both skill copies) now reads it first and records new meanings there.

## 2026-11-01 - Floppy: glowing bulbs and spore spots

- **Confirmed:** owner liked Floppy in the look and asked for slightly luminous antenna bulbs and a few medium, diffuse greenish-brown spots on the plain body only.
- **Implemented/verified offline:** concept and build rules, in-place paint of the repaired source (checkpointed), export glow mask; concept and look renders inspected.
- **Unresolved:** owner verdict; Roblox upload and Studio check.

## 2026-11-01 - Floppy spots revised; blaster final in the Floppy test place

- **Confirmed:** owner saw no spots and a glow on the skin by a bulb; wants noticeable, sickly, blended spots. Blaster: bladed ridge chosen; remove the dip before the blade, shorten about 15%, then make it the Roblox model.
- **Implemented/verified offline:** two-tone blotches and bulb-only glow; packed-image bug fixed (game texture changes verified). Blaster export with ink shells privately uploaded (moderation Approved), private mapping updated with backup, `build/SlugshotFloppyTest-SlugshotBlaster.rbxlx` opened. Rocklock's blaster mapping left unchanged.
- **Unresolved:** owner's Floppy verdict and Studio check of the blaster.

## 2026-11-01 - Floppy sores: sick, not dirty

- **Confirmed:** owner loves the blaster; Floppy spots looked dirty rather than sick, mainly the colour and the spot above the mouth.
- **Implemented/verified offline:** brief research on sick versus dirty palettes; sores inverted to a lighter bilious centre with a bruised rim and sallow halo, face spot removed; concept and game-model renders inspected; page updated.
- **Unresolved:** owner verdict; then Floppy's Roblox outline and glow.

## 2026-11-01 - Floppy in the Slugshot look, in Roblox

- **Confirmed:** owner asked for sore centres in the top-eyelid colour, keeping the glow, then said they like the design a lot and to put it in Roblox.
- **Implemented/verified offline:** sage sore centres with own-colour glow; export adds a skinned ink shell (reimport checks pass); real emissive mask and strength scaling; appearance styles the shell; private uploads Approved; Floppy test place rebuilt and opened with the final blaster. luau-lsp clean.
- **Unresolved:** Studio check by the owner.

## 2026-11-01 - Floppy sore glow toned down

- **Confirmed:** owner said the glow made the sores look much lighter than the eyelids; keep a light glow.
- **Implemented/verified offline:** sore glow 0.45 to 0.15 (concept 0.9 to 0.3); repainted, re-exported, emissive mask re-uploaded (Approved), Floppy test place rebuilt and reopened; page updated.
- **Unresolved:** owner Studio check.

## 2026-11-01 - Floppy final design

- **Confirmed:** owner liked the sores and asked for brighter, really glowing antenna bulbs, then made this the final Floppy design.
- **Implemented/verified offline:** luminous bulb cores (Roblox emission follows surface colour), head-bone PointLight, repaint, export, private re-upload (Approved), test place rebuilt and reopened; page updated. luau-lsp and Selene clean.
- **Unresolved:** owner Studio check.

## 2026-11-01 - Combat/first-person checkpoint for main

- **Confirmed:** owner requests a checkpoint of this chat on main, including the latest wording lessons and recurring fixes. They moved on from running tweaks after the posture/grip correction and praised the crosshair work; this is the current playtest baseline, not proof of final subjective approval for every movement/charge detail.
- **Implemented/verified:** Spot default with Anchor/Ride alternatives; source-driven first-person arms and direction-specific flip framing; stable shared aim with hidden native pointer during gameplay; mid-flip shot catchup; compact white charge ring; seven crosshair styles, independent color and 75–140% size. Full combat offline checks and limited native Studio checks are recorded in linked evidence throughout [combat](combat.md).
- **Contextual lesson:** "animated" and "gravitas" in charge feedback settled toward purposeful intake, localized held vibration and moving light after the owner rejected blocky fill, broad breathing, corner locks and cursor shake. "Robust/glitchy" running meant source rhythm and angled body participation, not random jitter or a faster animation clock; an apparent speed regression was actually a camera eye/focus mismatch. Preserve [the wording and regression guide](combat.md#owner-language-contextual-interpretations-to-carry-forward) as context, not universal values.
- **Unresolved:** latest overall appearance/feel verdict, multiplayer/latency/touch/gamepad coverage and persistence beyond a session.

## 2026-11-01 - Upright Triad and crosshair size

- **Confirmed:** owner wants Triad symmetric with one mark pointing north; preserve the hidden gameplay mouse cursor. Micro Cross lines should be equally long.
- **Implemented/verified:** angles -90, 30 and 150 degrees; Micro line dimensions already match. Added 75–140% session size control, default 100%. Native slider and Studio gameplay/menu checks pass, including hidden pointer after Settings closes, white charge and accepted shot. [Evidence/limits](evidence/2026-11-01-crosshair-size-symmetry.json).

## 2026-11-01 - Crosshair choices and independent color

- **Confirmed:** owner wants tasteful functional alternatives, including tiny dot/cross, twin bars and a three-mark/dot design; crosshair color is customizable, white charge is expressly excluded.
- **Implemented/verified:** seven presets, eight swatches/custom hex, previews and tabbed session settings. Native input and live rendering/firing/respawn checks pass. See [evidence/limits](evidence/2026-11-01-crosshair-settings.json).
- **Lesson:** share geometry between previews and gameplay, preserve fixed dark outlines and charge palette, propagate preview ZIndex through descendants in raised menus. Shape selection never changes the shared aim point. Aesthetic approval/device coverage remain open.

## 2026-11-01 - Tight translucent ring, fine vibration and inked edges

- **Confirmed:** owner rejects slow expanding/contracting, solid/blocky white and excessive ring size. They subsequently like the tighter/softer vibrating base and request dark definition outside and inside plus a slight spinning feel.
- **Implemented/verified:** radius 22 to 19, thinner partly transparent white with feathered edges, constant UIScale and continuous unclipped full circle. Held energy uses a tiny ring-only tremor and light/width shimmer; the aiming mark is independent and fixed. Fine charcoal rims bound both sides; a traveling reflection adds spin without rotating geometry. Preserve quick taps and source firing time. Full checks/native tap/full shots and geometry/animation assertions pass. [Evidence/limits](evidence/2026-11-01-tight-ring-rims.json).
- **Contextual lesson:** the requested “vibration” is not slow macro resizing or aim/camera jitter. “Spinning feel” can be conveyed by moving light. Accepted base appearance is confirmed; new rim/sheen feel still awaits owner review.

## 2026-11-01 - Simpler charge intake and gentle held energy

- **Confirmed:** remove four outer slanted corners (`ReadyLock` decorations), preserve the crosshair's own ticks. Owner wants gentle energy while holding full charge, a better-blended outer halo and simpler loading that does not penalize quick taps with crosshair/screen shaking.
- **Implemented/verified:** remove ready corners/glints, comet trail and orbiting wisps. One soft inward halo with two faint motes starts after 0.14 seconds; this is a visual gate only. Loading scale stays 1. Full ring breathes between 1 and 1.022 over 1.1 seconds with modest width/glow variation. Crosshair center/shape/size stays fixed. Offline checks and native tap/full-shot, repeated pulse and unequip checks pass. [Evidence/limits](evidence/2026-11-01-simple-charge.json). Owner look/feel remains open.
- **Interpretation:** explicit held-charge pulsing supersedes the earlier still-hold design; do not treat it as permission for random aim/camera jitter or repeated large impacts. Keep primary progress truthful and quick input immediate.
- **Fixture lessons:** wait for a gameplay probe's explicit PASS before starting an art-pose override; overlapping them can falsely fail cleanup. Screen copying can capture another foreground Studio window; use/verify window-handle capture for parallel workstreams. Neither fixture artifact justified a gameplay change.

## 2026-11-01 - Carry lobby art direction into combat UI

- **Confirmed:** owner likes the reticle, wants stronger black/charcoal edges and the overlapping native pointer removed. Prior charging animations remain rejected: plain, blocky, without gravitas. Read Claude's lobby philosophy/code/live scene before further visual work.
- **Research:** read-only lobby references through `fed0779`, including Living Comic-Book Fantasy, material-dependent ink, calm bases/selective glow, intentional detail and restrained motion; inspected its open Studio rock/crystal/fungus display. [Source record and translation](research/charge-art-direction.md). No lobby work edited/imported.
- **Implemented/verified:** accepted reticle sizes/shape with bolder ink; ink-backed white charge flow, tapered head, sparse inward motes and a short full-charge closure into a still ready seal. Remove rubbery spring. End-of-render cursor policy plus re-enable guard; forced late resets, native menus, charged fire, three-mode alignment and unequip checks pass. [Evidence/limits](evidence/2026-11-01-ink-charge.json).
- **Lessons:** “plain” does not mean add random motifs. Use loading -> closure -> readable hold with a clear hierarchy. Inspect native previews: tiny font glints can look like boxes; use drawn shapes. Thicker curved ink needs padded clips. `CURSOR_SHOWING` can describe a transparent native cursor; it is not sufficient evidence of a visible pointer.
- **Unresolved:** owner style/gravitas verdict; specific original cursor-overlap writer/path was not reproduced by the initial audit. No mobile/multiplayer/performance approval inferred.

## 2026-11-01 - Larger crosshair and white charge tension

- **Confirmed:** owner likes the crosshair design; wants +15% in third person and +22% in first person, a white base ring, less blocky/more fluid fill and stronger loading/full-charge feel.
- **Implemented/verified:** mode scales are 1.15/1.22 around the fixed aim point. Native circular strokes, clipped/gradient-masked into two arcs with rounded caps, replace the small rectangles. White fill remains tied to actual charge. Increasing compression/thickness builds tension; a damped spring and one fading ripple mark readiness. Source charge duration, projectile speed, aim and camera are unchanged.
- **Contextual interpretation:** “friction” here is a proposal for visible loading resistance and release, not random shake, aiming drag, fake slow progress or a firing delay. Owner feel verdict remains open. Initial teal/gold styling is superseded.
- **Evidence:** full combat checks pass; Studio verified exact idle widths, both arc halves, compression/thickness, full cue/settle, fixed aim center, accepted charged shot and menu/unequip cleanup. [Evidence/limits](evidence/2026-11-01-white-charge-tension.json).

## 2026-11-01 - Circular charge feedback and matching crosshair

- **Confirmed:** replace the long charge bar with a circle/ring and improve the crosshair to match; owner delegates palette. Future selectable crosshairs/colors are considering, not an instruction to build settings now.
- **Implemented/verified:** native `Reticle` renderer with an off-white dot/four short ticks, dark contrast edges and an outer 48-pixel ring. Actual charge fills clockwise, teal to gold near full, with one small outward full-charge pulse and no repeated breathing. Parent to the existing reticle so centered/free placement and menu hiding remain shared. Release/unequip clear charge feedback. Color/geometry constants are together for future changes, no external assets.
- **Evidence:** full combat checks pass; Studio observed partial/full/pulse/cleanup, accepted full-charge fire and three accepted mode-alignment shots; native full-ring frame inspected. No stable-frame-rate, mobile or subjective art approval claim. [Evidence/limits](evidence/2026-11-01-charge-ring.json).

## 2026-11-01 - One cursor/reticle and firing point

- **Confirmed:** owner moves on from movement tuning. Hide native cursor over centered aim in first person/shift lock; unlocked third person can use a cursor or mouse-following custom reticle. Implemented the latter.
- **Implemented/verified:** `AimCursor` shares viewport coordinates across the single reticle, charge/hit feedback and actual shot ray. Separate IgnoreGuiInset aim HUD preserves movement panel layout. Settings/core menus/text input restore the native pointer and suppress the gameplay reticle; menus prevent new charges. Full offline checks pass; native Studio accepted aligned launches in all three modes and verified M/Esc menu transitions. [Evidence/limits](evidence/2026-11-01-aim-cursor.json), [ADR](decisions/0015-shared-aim-cursor.md).
- **Lesson:** use a shared mode/point rather than assuming a locked OS mouse is centered. When measuring GUI pixels, convert AbsolutePosition with the live GuiInset; IgnoreGuiInset root AbsolutePosition can be negative. Allow normal half-pixel rounding at odd viewport sizes instead of treating it as a mismatched firing ray.
- **Unresolved:** owner reticle appearance, touch/gamepad and multiplayer coverage. Preserve the finished movement tuning unless requested.

## 2026-11-01 - Fast running arms and submerged grip

- **Confirmed:** owner reports arms moving at lightning speed after the lean change; asks for the earlier running pace and a slightly shallower first-person grip.
- **Implemented/verified:** restore 90/s run follow and remove the four-degree stroke accent. Advance `Camera.Focus` with the translated eye and undo both before the next native update. The missing focus translation caused native first-person body facing to reverse repeatedly; this was not a faster source animation clock. Live controlled facing is stable after the fix, with ordinary arm angular peaks. Do not mask facing regressions by retiming clips.
- **Implemented:** move the first-person gun 0.1 studs toward the fingertips through the common gun/muzzle mapping. Third-person grip, source poses, forward lean and arm dimensions remain. Full offline checks pass; [runtime evidence/limits](evidence/2026-11-01-run-pace-grip.json). Owner pace/grip appearance verdict remains open.

## 2026-11-01 - First-person running posture

- **Confirmed:** owner's remaining running critique is the upright feel; preserve the latest robust hand cadence and shortened first-person arms.
- **Implemented/verified:** actual final-view forward/down eye advance follows source chest lean/pace after native follow; undo before the next input/camera update. Keep the offset in world space so body turns do not create lateral sway. Chest-driven run shoulder height/depth complements the eye position; idle, spacing, source animation, physics and Spot stay as before. Full combat checks and idle/run/charged/Spot-flip shots pass.
- **Lesson:** inspecting `Humanoid.CameraOffset` alone does not prove the rendered viewpoint moved relative to the animated body. Measure final `Camera.CFrame` against the rendered root/head at the end of the frame. Earlier offset-only evidence is preserved with this limitation.
- **Unresolved:** owner running appearance/feel verdict and broader device/multiplayer/latency coverage. [Evidence](evidence/2026-11-01-running-posture.json).

## 2026-10-30 - Rocklock cavern art pass

## 2026-10-31 — Slower movement pace (v7.39)

- **Confirmed:** owner asked for run 18, sprint/wall run 24, slide cap 26, slower locomotion and camera bounce, slightly slower flips and shorter jump reach at the existing heights.
- **Implemented:** speed/cadence/camera/horizontal launch retune in the existing movement worktree; v7.38 source checkpoint retained under ignored `build/checkpoints/`. Baseline remains a stock-speed comparison. No private animation source edits or uploads.
- **Implemented/verified offline:** full movement verifier and private build pass. Compared all profile jump power/gravity and action vertical launches plus slide decay/timing to the checkpoint; unchanged. New Studio process launched on the private v7.39 build, preserving other windows.
- **Unresolved:** live gameplay and multiplayer checks, feet/limb cadence and flip/landing timing, camera comfort and owner verdict. [Details](movement-verification.md#v739-slower-movement-pace-2026-10-31).

## 2026-10-31 — Wall-run terrain continuation

- **Confirmed:** owner requested smooth traversal over small wall bumps/ledges, a corner-turn animation, and a new Studio test window.
- **Implemented:** v7.38 on isolated branch/worktree `experiment/wallrun-terrain` / `C:/Users/runni/slugshot-wallrun-terrain`; bounded lookahead, multi-height probes, seam grace, inside turns and outside arcs, turn brace and test course. Existing private clip module copied only into ignored private storage for the local build. No external resources added.
- **Implemented/verified offline:** `python tools/verify_movement.py` passed (foundation and movement formatting/lint/types, public/test builds, isolation); private Rojo build passed. New engine-raycast test fixtures compile and are isolated to the test place, but have not executed in Studio.
- **Unresolved:** runtime and multiplayer evidence, collision/contact at speed, input reversals and owner visual approval. [Evidence and playtest checklist](movement-verification.md#v738-uneven-walls-and-corners-2026-10-31).


## 2026-10-31 — Slower movement pace (v7.39)

- **Confirmed:** owner asked for run 18, sprint/wall run 24, slide cap 26, slower locomotion and camera bounce, slightly slower flips and shorter jump reach at the existing heights.
- **Implemented:** speed/cadence/camera/horizontal launch retune in the existing movement worktree; v7.38 source checkpoint retained under ignored `build/checkpoints/`. Baseline remains a stock-speed comparison. No private animation source edits or uploads.
- **Implemented/verified offline:** full movement verifier and private build pass. Compared all profile jump power/gravity and action vertical launches plus slide decay/timing to the checkpoint; unchanged. New Studio process launched on the private v7.39 build, preserving other windows.
- **Unresolved:** live gameplay and multiplayer checks, feet/limb cadence and flip/landing timing, camera comfort and owner verdict. [Details](movement-verification.md#v739-slower-movement-pace-2026-10-31).

## 2026-10-31 — Wall-run terrain continuation

- **Confirmed:** owner requested smooth traversal over small wall bumps/ledges, a corner-turn animation, and a new Studio test window.
- **Implemented:** v7.38 on isolated branch/worktree `experiment/wallrun-terrain` / `C:/Users/runni/slugshot-wallrun-terrain`; bounded lookahead, multi-height probes, seam grace, inside turns and outside arcs, turn brace and test course. Existing private clip module copied only into ignored private storage for the local build. No external resources added.
- **Implemented/verified offline:** `python tools/verify_movement.py` passed (foundation and movement formatting/lint/types, public/test builds, isolation); private Rojo build passed. New engine-raycast test fixtures compile and are isolated to the test place, but have not executed in Studio.
- **Unresolved:** runtime and multiplayer evidence, collision/contact at speed, input reversals and owner visual approval. [Evidence and playtest checklist](movement-verification.md#v738-uneven-walls-and-corners-2026-10-31).


## 2026-10-31 — Blender skill ecosystem for both agents

- **Confirmed:** owner approved the Slugterra-inspired visual recommendations and asked for hanging rock icicles (stalactites), all authored in Blender.
- **Implemented/verified, limited:** original Blender stone and crystal revisions, 12 overhead stalactites, new separately named source/export/place, full automated checks and FBX roundtrips. In one Studio client, west shelf, underpass and a west wall run worked. [Preview and details](rocklock.md); [test evidence and limits](rocklock-verification.md).
- **Unresolved:** owner judgment, actual Roblox visual capture, clipping and collision seams, opposite route, multiplayer and performance. Gun and animation files were not edited.

## 2026-10-30 - Rocklock visual comparison

- **Confirmed:** owner requested comparison against actual Slugterra cavern imagery to identify visual improvements.
- **Considering:** more irregular layered cavern silhouettes, a natural central arch, textured blue-violet stone and less uniform crystal clusters while retaining open combat space and close-fitting collision. Sources, reference limits and priorities are in [visual comparison](research/rocklock-slugterra-visual-comparison.md).
- **Unresolved:** the existing Rocklock renders predate crystal lighting, and a Studio capture was blank; current in-game visuals need a successful capture and owner review. No map or gun/animation work was changed by this research.

## 2026-10-30 - Rocklock rock collision

- **Confirmed:** owner requested solid cavern walls and collision closely following visible rocks, including dips instead of broad invisible boxes.
- **Implemented:** the original Blender rock triangles now form collidable native wedge surfaces; hidden skinned-box proxies are noncolliding. The crystal geometry remains noncolliding. The separately named `-accurate` place preserves earlier builds and concurrent gun/animation work.
- **Verified, limited:** automated foundation, movement and map checks passed; a Studio client landed on the arch and crossed the west shelf and underpass. A slide into the wall stopped, but one wall-run rejection followed, and a visual capture was blank. Facets have finite authored thickness; limb clipping, traversal seams, multiplayer and performance require further checks. See [Rocklock](rocklock.md) and [validation](rocklock-verification.md).

## 2026-10-30 - Rocklock crystal lighting

- **Confirmed:** owner requested Slugterra-inspired crystal formations as cavern light sources and asked that concurrent gun and animation work be preserved.
- **Implemented:** five original Blender designs, 16 formations, visible crystal-hosted point lights and a cool native Roblox post-processing look, in separately named `-crystals` place builds.
- **Verified, limited:** Blender FBX roundtrip and automated movement, foundation and map checks passed. **Unresolved:** subjective visual review and Studio/device performance. See [research](research/rocklock-crystals.md) and [Rocklock](rocklock.md).



## 2026-11-01 — Look test round 3

- **Owner feedback:** add a mini stairway/slab under the portal energy; walls looked blue ("don't just make the rocks blue"), so light them from above instead; small wall mushrooms look like angular shards.
- **Implemented:** gate v4 steps (concept and library updated); neutral ambient and fog plus a warm-white spotlight above each wall; small-detail triangle floor, 0.05-stud wall sampling and thinner small-cap ink. Rebuilt and re-uploaded the wall, mushroom and gate; library v14. Checks: lint, types and build pass; not yet seen in Studio by the agent.

## 2026-11-01 — Look test round 2

- **Owner feedback (Studio screenshots):** likes every design; walls too dark and far to see; crystals and mushrooms glow but don't light the walls; giant mushroom slightly deformed. Wants subtle animation: graceful spore stream from giant mushrooms that lights the area and dissipates at the floor, star twinkles on every crystal (wall ones too) scaled by size, portal animation. Small mushrooms: glow only (spores would be too much).
- **Implemented:** per-crystal and per-cap lights, twinkles, spore stream with light-carrying lead spores, portal sparks, embers and pulse; brighter ambient, thinner fog; rebuilt mushroom cap. Checks: StyLua, Selene, luau-lsp, Rojo build. Not yet seen in Studio by the agent.
- **Process note:** a PowerShell `-like "*`**"` unsaved check matched every title (the backtick is consumed inside double quotes), so stale Studio windows stayed open; fixed by closing them by start time. Studio window titles do not show unsaved state reliably.

## 2026-11-01 — Look pack first pass

- **Confirmed:** Roblox has no custom shaders, so the owner asked for our own look pack built from Roblox features plus baked assets; approved private Open Cloud uploads; asked that Floppy and the blaster get the same ink/glow look.
- **Implemented:** [look pack](art/look-pack.md) pipeline and runtime module; five final assets uploaded privately; look-test place built and opened. Problems solved on the way: marching-cubes winding (shells went inward), smudgy vertex-colour ink (switched to per-texel painting), invalid bake texels (Cycles fills the whole image; validity from zero positions), stale glow entries, ink shells greyed by lights (black Neon).
- **Unresolved:** owner's Studio verdict; Floppy skinned ink shell and blaster outline.

## 2026-11-01 — Designs final, lessons recorded

- **Confirmed:** owner approved every library design as final and asked for documentation of what was hard and how it was solved, including how to read vague phrasing next time.
- **Implemented:** library v13 marks all designs Final; new [art lessons](art/lessons.md); environment phrase table and working pattern added to [owner design language](slugs/owner-design-language.md); roadmap, asset plan, index and status updated.

## 2026-11-01 — Wall dressing anchored; designs ready for final review

- **Owner request:** no wall mushrooms (especially tiny ones) or crystals hovering off the rock. Bark mushrooms on the giant mushroom were requested, then withdrawn ("too much mushroom"). After reviewing the wall change the owner considers all designs approved and ready to hand off.
- **Implemented/verified:** the wall's rock body is now `wallMass`; `tools/lobby/wall_sites.py` ray-marches 23 dressing spots onto that surface on the GPU, searching a small neighbourhood for front-facing, non-overhang rock, and writes the anchors into the page (21 placed, 2 skipped with no suitable surface). Mushroom stems root 0.15 studs inside the rock and grow out along the normal and up; crystals sink 0.25 studs. A bounding early-out without margin first produced false sphere hits; fixed with a 0.5-stud margin. The agent inspected four turntable frames: dressing sits on the rock. Library v12.
- **Unresolved:** owner's final review.

## 2026-10-31 — Smoother library viewing

- **Owner report:** views now render but moving around feels laggy and glitchy compared with the first version.
- **Implemented:** turntables now 36 frames (10 degree steps) drawn to a 2D canvas only when the frame changes (was 16 frames moved as a large CSS background every frame); Live 3D restored to near-original smoothness (starts at 90% resolution, keeps 80% while dragging, full frame rate when animating, no draws when idle with motion off). Library v11. **Unresolved:** owner confirmation.

## 2026-10-31 — Library without WebGL

- **Owner report:** WebGL stayed disabled after a full Chrome restart with graphics acceleration on; asked for a working approach, suggesting rendering on open rather than all at once.
- **Implemented/verified:** the page is split into a shared `lib` script (asset data and pure uniform maths) and page logic. `tools/lobby/render_library.py` renders 32 turntable sheets (16 frames each) offline from the same shader in about 17 s; the agent inspected the rock wall sheet and a contact sheet of six assets. The page defaults to these rendered views, loading each sheet only when that asset/variant is opened; Live 3D (per-asset shaders, adaptive resolution) is opt-in and falls back to renders on failure. Published as library v10 with the renders as artifact files.
- **Unresolved:** owner confirmation in their browser. Noted while inspecting renders: PvP energy reads pale yellow rather than orange, the geode interior is hard to read, and the crimson field's rock is a flat slab.

## 2026-10-31 — Asset library freezing Chrome

- **Owner report:** opening the library froze the whole Chrome browser.
- **Implemented:** one small shader program per asset, compiled lazily (the single all-asset shader was the likely GPU hang on Windows/ANGLE); bounding early-outs for crystals, rock chunks, wall dressing and baby mushrooms; fewer march/shadow/AO samples; adaptive resolution starting at 45% and an idle frame cap of about 25 fps. JS syntax and shader structure checked; **not verified in a browser**.
- **Unresolved:** owner confirmation that the page now opens smoothly.

## 2026-10-31 — Concept round 5

- **Owner feedback:** crystals liked except the crimson shard field (shards detached from the rock); wants seven more, more unique designs (14 total). Rock wall vines "ruin it": remove them and add a few tiny glowing mushrooms in cracks. Mushrooms need a colour bank (purple, green, lime, violet, etc.) viewable for the giant mushroom; small mushrooms take a random colour from a bank of 14.
- **Implemented (library v7):** crimson v2 (tighter spread on a larger rock); designs 8-14: Sapphire geode, Magenta floating heart, Jade crystal tree, Gold spiral, Molten split boulder, Pearl hanging cluster, Aurora urchin; rock wall v5 without vines, plus tiny glowing mushrooms; a 14-colour mushroom bank (mint, cyan, azure, violet, purple, magenta, pink, coral, amber, gold, lime, green, teal, frost) with a Colour selector for the giant mushroom and random bank colours for every small mushroom.
- **Unresolved:** owner review; not visually checked by the agent.

## 2026-10-31 — Concept round 4

- **Owner feedback:** raised gate symbols hard to read under bold ink; gates 1.5x bigger; mushroom only needs to look more attached to the ground plus spores; crystals "basically perfect" but need seven variants in seven colours ("we need a lot of variety"); rock wall v3 "the worst", v1 best for simplicity: rebuild simply with moss, cracks, sprouting mushrooms, poking crystals and vines, after Slugterra/fantasy walls.
- **Implemented (library v6):** symbols as flush glowing inlays with a fine painted edge (no ink outline); gates scaled 1.5x (about 21 studs); mushroom v2 with five ground-diving roots, mossy mound, baby mushrooms and drifting glowing spores; crystals with seven variants (Cyan cluster, Violet spire, Amber fan, Rose crown, Emerald spray, Frost spires, Crimson shard field); rock wall v4 = v1 masses plus painted broken cracks, more moss, three sprouting mushroom clusters, five poking crystals and four vines with glow bulbs. A reference search found only stylised asset packs; the common pattern is simple rock with dressing.
- **Unresolved:** owner review; page not visually checked by the agent.

## 2026-10-31 — Gate identities and rock wall v3

- **Confirmed:** Slugshot mix is "amazing". Rock wall v2 still not liked: the lines through the face looked weird and it felt plain. Gates get a symbol on the keystone gem (PvP two swords, exploration a map) and gate colours for energy, bolts and gem: PvP orange, Training green, Veylume purple (owner "100% sure"); symbol grey or matching.
- **Implemented:** library v5: three gate variants (Training symbol chosen as a target; symbol in grey metal); rock wall v3 with strata removed, a crystal-lit alcove, bracket fungi, ledge mushrooms and painted warm/cool stone patches.
- **Unresolved:** owner review; crystal cluster and mushroom critiques pending.

## 2026-10-31 — Slugshot mix treatment and rock wall v2

- **Confirmed:** owner loves Inked Cavern and wants it as the main treatment, but keeps the others: dark rocks look better with Comic Cavern; glowing/clear things (mushroom, crystals) with Inked Cavern; characters always Inked Cavern. Comic Cavern swallowed the portal's grey bands and orange bolts, which Living Comic did not. Rock wall v1 "too basic".
- **Implemented:** per-material "Slugshot mix" default in the asset library (rock/stone/floor = Comic, glow/organic/characters = Inked, metal details = thick outline with Living Comic inner lines) and rock wall v2 (skyline spires and notch, overhang ledge, strata, hanging moss, glowing crystal shards). Recorded in the [style guide](art/style-guide.md#treatment-rule-slugshot-mix-confirmed-2026-10-31).
- **Unresolved:** owner review of v2 and the remaining critiques.

## 2026-10-31 — Treatment direction

- **Confirmed:** owner rejected the Enchanted treatment and wants a look between Comic Cavern and Living Comic, closer to Comic Cavern but not as heavy. **Implemented:** Inked Cavern treatment (ink width 1.45x, near-black charcoal ink, slightly reduced glow/bloom) as the asset library's default; Enchanted removed. **Unresolved:** owner confirmation.
- **Owner follow-up:** Inked Cavern was "not there enough": the owner wants Living Comic's clean look with Comic Cavern's thick ink and shadowing. **Implemented:** treatments now set ink, interior-line density, shadow depth and shadow-edge hardness separately. Inked Cavern = Comic Cavern ink (1.7x, near-black), slightly fewer interior lines than Living Comic, Living Comic glow, deeper shadows (floor 0.1) with a crisp comic light-to-shadow edge (0.65).

## 2026-10-31 — Lobby branch and asset library

- **Confirmed:** owner agreed with the build order (a few Blender hero assets first to set the look, then a greybox layout, then all assets built in Blender to fit it) and asked for a live 3D concept library like Floppy's.
- **Implemented:** branch `experiment/lobby` in worktree `C:/Users/runni/slugshot-lobby` (private Floppy/blaster files copied, ignored). [Asset library](https://claude.ai/artifact/77cwAiKc1n5SfsVwD1njyr) v1 shows four concept assets (rock wall, crystal cluster, giant mushroom, portal frame) with treatments A/B/C, views and a 5-stud figure. A first-pass headless Blender build script exists but was not run; it waits for concept approval.
- **Unresolved:** owner review of the four concepts and the treatment; the page was not visually checked by the agent before publishing.


## 2026-10-31 — Bridge style leaning

- **Considering:** owner is not fully decided but thinks droopy wooden suspension bridges would look best. Recorded in the [roadmap](art/lobby-roadmap.md#layout) and [asset plan](art/lobby-assets.md).

## 2026-10-31 — Floating spawn and bridges

- **Confirmed:** spawn is a floating rock above the Maelstrom and below the Sky Well. Four bridges: forward to the portals, back to the entrance, left and right to the two exhibition sides. Each lands on solid mainland where the terrain and biomes are built. Invisible barriers stop players jumping off bridges.
- **Implemented:** [roadmap layout](art/lobby-roadmap.md#layout) and [asset plan](art/lobby-assets.md) updated.

## 2026-10-31 — Hub centrepiece

- **Confirmed:** after rejecting four slug-themed centrepieces, the owner asked for something dramatic and natural, then chose a **Sky Well** (ceiling opening with a light column and floating rocks) above a **Maelstrom** (glowing water spiralling down a central sinkhole), with spawn on a pillar between them and bridges out to the ring.
- **Implemented:** [roadmap centrepiece](art/lobby-roadmap.md#hub-centrepiece-sky-well-and-maelstrom) and [asset plan](art/lobby-assets.md) updated.
- **Unresolved:** fall behaviour into the Maelstrom; Roblox technique for the light column and swirl.

## 2026-10-31 — Veylume, round hub, terrain features

- **Confirmed:** the exploration world is named **Veylume** (owner-typed spelling). Hub is round/octagonal; exhibition positions basically right. Chosen extras: bounty and duel board, a slug workshop (Slugterra-esque, not a real forge), glowing pond, slug murals. The owner's main interest is terrain: spiralling caverns, a little volcano, a ravine with lava pouring down, a waterfall mountain with Slugterra-type greenery. Descent shaft, overlook, canteen and map table not chosen.
- **Implemented:** [roadmap](art/lobby-roadmap.md#layout) and [asset plan](art/lobby-assets.md) updated; dictation slips recorded in owner design language.

## 2026-10-31 — Lobby layout and Slugterra research

- **Confirmed:** owner layout: central spawn facing the PvP gate; Training gate left of PvP, exploration gate right of PvP (mode added later; needs a less generic name); entrance behind spawn; a slug exhibition and a gun exhibition; Slugterra-type terrain and structures all around. The wider map is planned as merging biomes.
- **Implemented:** [Slugterra environment research](research/slugterra-environment.md) (search-confirmed vs from-memory items; the wiki and TV Tropes refused direct fetches); layout diagram, zone moods, name options and extra-area ideas in the [roadmap](art/lobby-roadmap.md); exhibition, frontier, slug-energy and biome-hint assets in the [asset plan](art/lobby-assets.md).
- **Unresolved:** exploration name, exhibition positions, which extra areas to include, owner review before Phase 1.

## 2026-10-31 — Art direction and lobby plan

- **Confirmed:** the owner pasted an art-direction chat, agreed with its proposals, and added: Slugterra-type vibrant colours that are not neon, a mix of calm and vibrant, and Borderlands-style ink outlines so nothing goes unnoticed. They asked for general style rules (no strict colours or layout), a lobby roadmap and a plan of Blender assets, including distinct Slugterra-category props such as giant mushrooms, so the lobby doesn't look like AI slop. In the owner's dictation, "Badlands" means Borderlands.
- **Implemented:** [style guide](art/style-guide.md), [lobby roadmap](art/lobby-roadmap.md), [lobby asset plan](art/lobby-assets.md); links in the index, status and vision.
- **Unresolved:** owner review; Phase 1 style test (three treatments A/B/C, outline methods, low-graphics check); a separate lobby branch/worktree before any build.

## 2026-10-31 — Blender skill ecosystem for both agents

- **Confirmed:** owner authorised installing 28 EL4CTEO skills, 30 RobLe3 skills, BlendRelay and MCP for Blender for both Codex and Claude, plus Slugshot routing and quality records. Preserve the current creature and unrelated Rocklock/movement work; no GPU image-to-3D services or publication.
- **Implemented/verified:** pinned source libraries and all 58 namespaced skill copies per host; source validators and representative fresh Codex/Claude discovery/invocation; two local MCP registrations per host; both add-ons enabled and live-tested in Blender 4.5.14 and checksum-verified side-by-side 5.2.3. EL's 67 tests, RobLe3's 12 export tests and a disposable four-view modelling/rig/animation/export example passed. BlendRelay queried and edited a disposable cube, then restored a checkpoint exactly. See [installation audit](slugs/install-audit.md) and [routing](slugs/skill-routing.md).
- **Unresolved:** automatic routing, all 58 individual invocations, RobLe3 recipes referencing older MCP tool names, Roblox import and owner artistic approval. The owner still reports weak silhouette/cohesion/expression in the first creature; its source remains intact.

## 2026-10-31 — Symmetric antennae and modelling lessons

- **Confirmed:** owner wants the outward antenna to match the more inward one, with both clear of the forehead; capture actionable visual/technical lessons without rebuilding the pipeline or treating automated checks as art approval.
- **Implemented/verified:** mirrored rest curves, geometry-based tip symmetry and forehead-clearance checks across sampled idle poses; full offline generation/export/project checks pass. [Blender lessons](slugs/blender-lessons.md) links preserved historical renders and distinguishes confirmed fixes from unresolved Studio/visual review.
- **Unresolved:** owner review of symmetry and clearance, and Roblox import/runtime.

## 2026-10-31 — Image-right antenna clearance

- **Confirmed:** owner reports the right antenna still touches the forehead.
- **Implemented/verified:** moved the image-right tip (model `feelers_left`) outward/forward; checked the front/side projected gap with geometry assertions and reviewed the new renders. All offline project/source/FBX checks pass; evidence updated in the [design record](slugs/catalog/flopper-inspired.md).
- **Unresolved:** owner visual approval and Roblox import/runtime.

## 2026-10-31 — Forehead, side depth and upper-body softness

- **Confirmed:** owner likes the general direction but wants a forehead, head depth in side view, and a squishier-looking head and perimeter rather than softness only at the floor.
- **Implemented/verified:** fuller forward crown/cheeks, gently settled flanks, softer Blender light scattering and subtle idle head-volume deformation. Antenna tips were advanced to stay free of the fuller forehead; a closed-volume topology check caught and prevented a tip/head loop. Full offline pipeline, side-depth/forehead and existing contact/colour/motion checks pass. [Art and evidence](slugs/catalog/flopper-inspired.md).
- **Unresolved:** owner softness verdict, real Roblox material/skin/scale playback and production optimisation. No soft-body simulation or gameplay introduced.

## 2026-10-31 — Muddy markings and gentle head/waist contour

- **Confirmed:** owner wants the markings slightly darker and muddy rather than vibrant, and the upper head a little wider to create a gentle, non-exaggerated hourglass shape.
- **Implemented/verified:** muted olive vertex colours, a slightly broadened/rounded head and gentle middle narrowing; base remains widest. Source, full offline pipeline, FBX clips/colours, contact, connected skin and new silhouette checks pass. See [current design record](slugs/catalog/flopper-inspired.md).
- **Unresolved:** owner review and Roblox materials/skin/animation import. No gameplay or publication added.

## 2026-10-31 — Softer forward antennae

- **Confirmed:** owner wants antennae less stiff/attached and turned a little forward rather than to the sides.
- **Implemented/verified:** deeper/smoothed roots, thinner drooping curves and a longer head-to-feeler weight gradient in the same connected skin. Both antenna tips now bend down/forward; all offline source, FBX and project checks pass. Sampled cream and existing body/face directions are retained. See [design record](slugs/catalog/flopper-inspired.md).
- **Unresolved:** owner visual verdict and actual Roblox skin/animation/material import.

## 2026-10-31 — Reference cream and fused floppy antennae

- **Confirmed:** owner requested downward-flopping antennae that extend from the slug; rejected the guessed yellow/brown and instructed the base colour to match their original Flopper image.
- **Implemented/verified:** cream sampled from the supplied 3D reference, neutral lighting, two curved antennae voxel-fused into the head with blended head/feeler weights. All source/model/clip and strict Luau checks pass, including a single connected skin, downward tips, grounded squash and vertex colours. See [design/evidence](slugs/catalog/flopper-inspired.md).
- **Unresolved:** colour and antenna art review, higher-detail mesh optimisation, Roblox materials/skin/animation playback. No external model or reference texture imported and no asset uploaded.

## 2026-10-31 — Grounded resting shape and integrated tail

- **Confirmed:** owner wants slightly dirty/warm off-white rather than clean white or cream, a fully relaxed/slumped base on the floor, and a short squishy triangular tail made from the body's continuation.
- **Implemented/verified:** spread/flattened underside and tail are one continuous original mesh; lower contour has mild asymmetry, material highlights are softened and the base colour is subtly warm. Idle and impact samples retain a broad flat contact patch; source and five FBX clips, vertex colours, strict Luau and all pipeline checks pass. See [design/evidence](slugs/catalog/flopper-inspired.md).
- **Unresolved:** subjective softness, colour and tail shape; Roblox import/rendering/scale animation remain unverified. The resting geometry is authored, not simulated soft-body physics.

## 2026-10-31 — Sick/dizzy slug redesign

- **Confirmed:** owner rejected the blocky/hard first design, oversized head, protruding eyes, green belly and feet; requests a squishy white body with hypnotic spiral eyes on the head, vivid diffused green bacteria-like spots all around and a very small tail.
- **Implemented/verified:** an original seven-mesh Blender draft replaces the prior art; no feet, small tail, surface-fitted spiral eyes, full-circumference blended vertex colours, retained rig and idle/blink/hop/launch/impact. Full offline Blender/FBX and Luau checks pass, including body quadrant colours, tail length, eye offset and FBX vertex-colour preservation. See [design record](slugs/catalog/flopper-inspired.md).
- **Unresolved:** owner review; Roblox rendering of vertex colours, animated bone scaling and skin deformation; no Studio runtime/import claim. No gameplay or asset publication.

## 2026-10-31 — First slug and permanent design catalogue

- **Confirmed:** owner supplied two Flopper images and a description, requesting a distinct original soft, expressive, non-transforming slug and reusable notes for every future species. Slippery patch, smoke and tripwire are gameplay ideas rather than approved implemented rules.
- **Implemented/verified:** [first design record](slugs/catalog/flopper-inspired.md), [catalogue/template](slugs/catalog/index.md), original editable Blender draft, rig and five animation slots. Headless Blender renders and FBX reimports passed, as did project checks; see that record for exact hashes, measurements and limits. The named Sketchfab collection was inaccessible; only the supplied screenshots and a search-indexed community wiki entry were reviewed.
- **Unresolved:** owner visual feedback, Studio native/import runtime and animation-scale behavior, 21-mesh device performance, final name and any gameplay design. No assets uploaded or published, and unrelated work was not touched.

## 2026-10-31 — Isolated slug asset tooling

- **Confirmed:** the owner's attached request authorizes universal creature tooling and original temporary placeholders, while Claude owns concurrent Rocklock/map/destruction work. No final creatures, full combat, merge into main or asset publication authorized.
- **Implemented:** separate worktree `C:/Users/runni/slugshot-slug-pipeline`, branch `feature/slug-asset-pipeline` at baseline `913f9e6`; versioned JSON custom rigs/species and generated strict Luau; native Blender 4.5.14 LTS generation/actions/export/previews; independent-rig, flight-time-aware visual interfaces and isolated lab. See [ADR 0016](decisions/0016-slug-asset-pipeline.md).
- **Implemented/verified:** configuration failure tests, Blender corruption cases and a one-eye/horn-free variant; source/export hash and animation-motion/loop/timing roundtrips; foundation/strict Luau/Rojo checks. [Evidence and exact limits](slugs/verification.md).
- **Unresolved:** Studio MCP lists no connected instances; native fixture runtime, actual Roblox mesh/clip import, scale channels, permissions and visual quality need the [manual checklist](slugs/studio-import.md). Original movement and map files were not edited. No addons/accounts/assets installed or published.


## 2026-10-30 - Drag limb spacing

- **Confirmed:** the overall drag pose is positioned correctly, but the owner sees a compressed wall-side shoulder and odd legs.
- **Implemented/verified:** an R6 shoulder offset reduces torso overlap and the free leg no longer intersects the other leg in the sampled Studio pose. Automated checks pass; the v7.37 place is reopened. **Unresolved:** owner judgment and the mirrored wall. See [results](movement-verification.md#v737-drag-limb-spacing-2026-10-30).

## 2026-10-30 - Wall drag leg direction

- **Confirmed:** the owner likes the drag body and arm pose but wants the legs sideways like the Mario reference, not forward.
- **Implemented/verified:** the drag's hip transforms now angle both rigid R6 legs toward the wall; automated checks pass and one Studio client rendered the wall action with angled legs. **Unresolved:** visual assessment and opposite-wall contact; the capture was blank. See [results](movement-verification.md#v736-wall-drag-legs-2026-10-30).

## 2026-10-30 - First-jump reach and wall drag

- **Confirmed:** the owner says wall stopping works; requests a less flat, braced drag pose and a longer, slightly higher first jump, explicitly excluding the double jump.
- **Implemented/verified:** the ground-jump arc and input speed target were adjusted; one Studio probe comparison measured 13.93 to 15.80 studs of travel and 10.01 to 10.88 studs of height. The R6 drag is braced farther from the wall; a pre-final pose was viewed in Studio. **Unresolved:** final pose, both sides, double-jump regression and subjective feel. See [evidence](movement-verification.md#v735-first-jump-and-drag-pose-2026-10-30).

## 2026-10-30 - Front flip and Studio handoff

- **Confirmed:** the owner wants Studio closed and reopened on the updated movement place after playtestable changes.
- **Implemented/verified:** the chosen front full step-out is refined with flowing asymmetric arms and a clearer leg step while retaining its rotation and timing. Automated checks passed; the reopened Studio client's source was checked for v7.34. **Unresolved:** the owner's visual assessment. Build after closing Studio: an earlier close overwrote the build with the older place.

## 2026-10-30 - Wall drag input follow-up

- **Confirmed:** the owner still saw unwanted running on no-input wall catches and a long delay after release, and supplied two pose references.
- **Implemented/verified:** v7.33 uses current wall input, starts a no-input catch without along-wall momentum and brakes quickly; a one-client probe observed a 34-to-zero stop within 0.1 s and a resumed run. Checks and limits are in [movement verification](movement-verification.md#v733-wall-input-and-drag-2026-10-30).
- **Unresolved:** the revised R6 pose and wall contact need visual review; real-key jump-off and multiplayer were not tested. Studio's temporary test sources were restored.

## 2026-10-28 — Foundation setup

- Inspected an empty workspace and read the pasted request and PDF background. Kept the request authoritative; PDF gameplay instructions were not adopted.
- Reused existing Rokit 1.2.0 and cached Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0 and Luau LSP 1.70.1. No tool, addon or third-party skill was installed.
- Created minimal source probes, isolated Studio test project, verification tooling, editor configuration and CI. Normal build contains exactly three scripts; no gameplay or authored environment.
- Created shared agent instructions, three original mirrored procedure skills, Markdown knowledge system, asset/creature/ADR templates and specialist research.
- Verified local formatting, linting, shared-module types, both Rojo builds, sourcemap, built script placement/source fidelity, test isolation, skill metadata/parity and local HTTP serve. The API uses MessagePack in this Rojo version; connectivity verification checks HTTP status/content without claiming a Studio sync.
- Kept integration examples inactive and documented approval-dependent steps. No global client configuration, account connection, GitHub remote or publishing action was changed.
- Deferred Studio runtime/multiplayer/MCP tests because no approved active session/connection was available. The bundled skill validator lacks PyYAML; no dependency was installed to work around it.
- Initialized local Git and created the foundation snapshot on `main`. See [verification](verification.md), [status](status.md) and [research](research/tooling.md).

## 2026-10-28 - GitHub publication

- User requested GitHub publication with a simple README, then explicitly selected public visibility.
- Reused the authenticated GitHub CLI to create https://github.com/jarems421/slugshot and configure `origin`.
- Simplified the README to a project description, setup commands and links. Updated current notes to reflect the approved remote.
- First hosted Linux CI passed: https://github.com/jarems421/slugshot/actions/runs/40719697932. Local foundation checks also passed previously. Studio/MCP setup remains separate.

## 2026-10-28 - Approved Studio integrations verified

- The owner approved the matching Rojo plugin, Studio MCP for Claude Code/Codex, runtime/two-client verification and pushing results.
- Installed the plugin bundled with Rojo 7.7.1. Studio auto-updated to 0.745.0.7451137 during launch; its built-in MCP setting was already enabled and was verified live.
- Claude's private project-local entry reports Connected. Codex's project config is active; native app-server discovered 31 tools and made live list/read calls without a model turn. Only this workspace's trust was added.
- Single-client and separate server/two-client tests passed. Each client logged once, saw both players, loaded the shared module and could not see the server bootstrap. EndTest returned success and the parent returned to Edit mode.
- Verified filesystem-to-Studio sync with a temporary source comment, then restored and verified exact original source. The normal place has no test folder.
- Captured sanitized evidence in [the Studio record](evidence/2026-10-28-studio.json). Documented avatar asset-type and built-in MaterialManager warnings without changing design/assets. Host config, tokens, raw logs and scratch helpers remain untracked.
- No requested integration/runtime test remains pending. No gameplay or unrelated plugin was added. See [verification](verification.md) and [reproduction](testing.md).
- Final local checks and the hosted [integration setup CI](https://github.com/jarems421/slugshot/actions/runs/40724542365) passed for `407102e`; runtime evidence remains separate from hosted checks.

## 2026-10-28 - Movement research and isolated prototype

- Owner authorized movement research, relevant verified free assets/tools and an isolated playable study; subsequently explicitly requested pushing the work. Used `experiment/movement-sandbox`, preserving foundation source/projects.
- Inspected actual controller source/licences and extra leads. Movement Base had no implementation. Selected a small native Humanoid layer experimentally; full CCL opt-in remained unvalidated. No third-party controller/runtime/editor plugin installed.
- Downloaded both Cinderlore starter packs to ignored private storage, audited zero scripts and confirmed seven relevant clips playing on R15. Inspected private captured samples. No source clips, converted poses, screenshots of private clips or reusable IDs enter Git/public builds.
- Built an arena, comparison profiles, smoothed running, compact directional evade, visual aerial flourish, original procedural R15 poses, aim pose and harmless marker. No combat or final game-design decisions added.
- Actual tests caught AnimationConstraint compatibility, blend-state overwrites, jump-probe timing, server position/velocity lag and respawn mouse cleanup. Corrected these and reran relevant checks.
- Single-client tests, native W/Shift/Q/Space/F input and two-client movement/presentation passed. One 60 ms/direction plus 10 ms jitter trial completed and settings were restored. Server rejected 32 invalid/rate-limited requests. Broad FPS/device/security claims remain unverified.
- Added movement skill and mirrored Claude copies, public-safe evidence and CI coverage. Human playtesting is the next gate; see [movement guide](movement.md), [research](research/movement.md) and [results](movement-verification.md).

## 2026-10-28 - Movement refinement (v2)

- v1 playtest feedback (owner): evade read as a dash, flourish as a procedural spin, running/jumping lacked expression; target is fast, light, athletic and fluid without floatiness.
- Owner first chose Mixamo + Blender. Built and verified (on synthetic data) an original retargeter with portable Blender 4.5.14 LTS in ignored `.tools/`. Owner did not download clips and, after a trade-off discussion, chose original clips for now with Mixamo as a later upgrade.
- An intermediate build only changed controls because visuals depended on missing clips; the owner noticed. Lesson: never gate the visible improvement on an asset the owner has not yet supplied.
- Implemented original keyframed clips, clip player, rig-accurate ground contact, single Q/B acrobatics control, root-motion rolls, airtime-fitted flips, landing-roll buffer and a v1 comparison build. Removed the v1 procedural presentation from the working tree (kept in `e2b5688`).
- Studio tests caught and fixed: Humanoid braking against roll velocity, server rejecting landing rolls (replication lag), roll contact on the head (now a diagonal shoulder roll), observers cancelling flips (interpolation lag), remote rig streaming. A suspected "remote velocity is zero" turned out to be test timing; the workaround was removed.
- An interrupted test run left Studio network emulation at 60 ms/10 ms in the test window; detected, reset to 0 and verified; the two-client script now requires a 0 baseline. Never cut test output with `head` while a script holds temporary settings.
- See [movement guide](movement.md), [results](movement-verification.md#v2-refinement-2026-10-28) and [ADR 0003](decisions/0003-clip-presentation.md). Next gate: owner playtest of v2 versus v1.

## 2026-10-29 - Traversal from Place1 (v3)

- The owner asked why the lab was not adapting established free movement systems. Answer given: the mechanics already sit on Roblox's native Humanoid, and the reviewed frameworks bring first-person/gravity/stamina baggage and no roll/flip animation; the gap is animation. The owner chose Mixamo (later, own download) plus parts of Place1, and picked mantle and wall hop over slide and bunny-hop.
- Adapted Place1's MIT detection (pinned `87da75e`) into `client/Traversal.luau` with the full notice. Added `MantleLow`/`MantleHigh`/`WallHop` original clips, a clip `climb` curve (also produced by the Mixamo converter's new `traversal` mode), server geometry checks and a traversal course. v2 comparison build added. See [ADR 0004](decisions/0004-place1-traversal.md).
- Studio tests caught: server rejecting genuine wall hops because the hop request overtook replication of the jump (fixed by polling and recent positions); possible out-of-order validation (now one action at a time per player); FloorMaterial lagging takeoff and dropping early second presses (grounded check now needs low vertical speed, plus a 0.15 s hop buffer); a belly-flop press pose and an overhead reach on chest-high ledges (retuned, threshold 3.2 studs).
- Lesson: a test that keeps moving after an action can falsely fail (the character ran off the far side of the ledge). Sample during the action, not only at the end.
- See [results](movement-verification.md#v3-traversal-2026-10-29). Next gate: owner playtest of v3 against v2/v1; Mixamo needs the owner's downloads.

## 2026-10-29 - Owner's Mixamo clips (v4)

- The owner downloaded 49 Mixamo clips (several per state) and asked for all of them to be used for variation, and to be told what else is needed. All 49 are used, as 54 runtime clips, via named variants (`Name.2`). See [ADR 0005](decisions/0005-mixamo-variants-transitions.md).
- The downloads went to `Desktop\mixamo`, and `private-assets/` had been moved to the Desktop (probably an accidental drag). Both were copied back into the ignored project folder; the Desktop copies were left in place.
- The first run on real files exposed converter problems that synthetic data had not:
  - pelvis-yaw facing correction (removed)
  - travelling loops offset by half their travel
  - one-shot clips carrying their own travel
  - run-out roll recovery
  - turn clip facing
  Lesson: look at held poses on the real rig before trusting a converter report.
- Added crouch, vault, wall run, motion-derived transitions and three landing tiers. Studio tests then caught that a reversal passes through a stop (which had cleared the turn direction) and that early jump presses cleared low walls instead of vaulting (look-ahead added).
- Test-process lessons:
  - Client-side teleports can trigger the server's motion correction; teleport from the server in two-client tests.
  - Multiplayer test windows from earlier runs had stayed open for hours; they were ended with `StudioTestService:EndTest`. Check for leftover Studio windows after multiplayer tests.
- See [results](movement-verification.md#v4-mixamo-clips-2026-10-29). Next gate: owner playtest of the private v4 lab.

## 2026-10-29 - Owner feedback on v4 (v4.1)

- **Wrong build.** The owner first played the public build by mistake: four Studio windows were open. The HUD names the clip source (`original + N private clips`); point to it when handing over a build.
- **Owner's feedback on v4.** Wall run/jump did nothing, too many jump variants, a crouch drop to all fours, cuts between stop/idle/fidget, short fast running strides, a slow mantle, and a falling pose on box edges. A second round said the v4 "wall run" was a hop: a standard wall run attaches when you jump onto a wall while running. Sloped walls were raised, then deferred.
- **Root cause of the dead wall moves.** `UserInputService.JumpRequest` did not fire for Space in Studio, and v4 tests had called the jump handler directly. Lesson: test inputs through the real input path (`user_keyboard_input`), not only probes.
- **Implemented** (see [ADR 0006](decisions/0006-wall-run-and-v4-feedback.md)):
  - wall run as an automatic attach state with kick-off (procedural pose)
  - wall jumps from the owner's kick clips
  - a parkour mantle from Vault Over Box
  - one running and one standing jump
  - crossfaded crouch and transitions; no fidget
  - a restyled stride
  - a sphere ground check
- **Observer bug.** The wall-run action could reach observers before the body left the ground, ending it at once; observers now wait 0.35 s before end checks.
- **Lag emulation left on again.** Studio network emulation was found at 60/60/10/10 ms in two windows (cause not established; probably an earlier test of mine) and reset to 0. The owner's v4 playtest may have run with that lag. Check it at the start of each session.
- **Updating open Studio windows.** `ScriptEditorService:UpdateSourceAsync` works where `Source` assignment is capped at 200,000 characters. Studio relaunches hung while orphaned test windows were open, and force-closing Studio was not permitted.
- Next: the owner reviews v4.1; running animation rework.

## 2026-10-29 - Owner feedback on v4.1 (v4.2)

- The owner asked for:
  - the crouch idle at the crouch-walk height
  - up/down control on the wall (suggested: Space up, otherwise slide)
  - a wall hand that stops at the wall
  - no mantling over small steps ("only mantle where it's too tall to jump over")
  - only the jump look they liked, not the "Spider-Man" one
- **Ambiguity resolved by comparing poses.** "Spider-Man" was ambiguous. Held poses of the running jump, standing jump and Falling Idle side by side showed Falling Idle as the crouched, limbs-out pose. Falls now sway about the jump clip's apex. The first fall hold landed on a straight-diagonal-arms frame, so it was moved to the apex.
- **Mantle rule.** Predict the feet's path to the ledge face, and mantle only when the jump won't clear it, for ledges at least 2.2 studs above the ground. The first version still mantled steps when descending onto them; the ground-height floor fixed that.
- **Testing lesson.** The MCP keyboard tool has about 0.3 s of latency, so a press "at 4 studs" arrives at about 1.8 studs. Measure where the press actually lands before blaming the logic. Also, the harness `call` overrides `studio_id`; pass `sid=` to target a test client.
- Next: the owner reviews v4.2; running animation rework.

## 2026-10-29 - Owner feedback on v4.2 (v4.3)

- The owner asked for:
  - a wall run that stays on until the floor or a jump-off
  - responsive wall jumps between two walls
  - a parkour one-hand "breakdance" mantle for ledges at your level, and the climb only when reaching
- **Causes found.**
  - Wall run: a 2 s limit, plus input-based drop-offs.
  - Wall jumps: a 3-kick-per-airtime cap and a 0.15 s press buffer.
- **Mixamo did not have the mantle.** Mixamo's vault selection is thin. Vault Over Box contains the motion, but even spin-cancelled (new `flattenYaw` converter option) it read as a hunched ball on the R15 rig. An original keyframed speed vault reads clearly. Lesson: on the blocky rig, a hand-keyed clip can beat mocap for silhouette-driven moves.
- **Possible interference with tests.** A two-client run showed crouch/flip input the script never sent, plus 5 rejections. The owner may have been playing in the popped-up test window, and that session's windows stayed open. The HUD now shows the last rejection; avoid long Studio test runs while the owner may be playing.
- Next: the owner reviews v4.3; running animation rework.

## 2026-10-29 - Owner feedback on v4.3 (v4.4)

- The owner wants wall jumps that go up or sideways as well as out, running up a wall then mantling over the top, and mantles that feel near-instant ("frictionless").
- **Kick direction.** The held input picks it, reusing the camera-relative move vector: toward the wall, up; along, side; away or none, out.
- **Limits.** One up-kick per wall per airtime prevents climbing a wall forever; the 8-kick limit still bounds chains.
- **Mantle.** Mantles can interrupt a wall run or a kick; from a wall they look toward it and always take the top. Duration is 0.2-0.3 s.
- **Testing.** Two-client tests were not re-run, to avoid popping up test windows while the owner may be playing.
- Next: the owner reviews v4.4; running animation rework.

## 2026-10-29 - Running style (v4.5)

- The owner finds the Mixamo run too athletic ("a sprinting game") and wants a Robloxy run: straight arms and legs, long strides and arm strokes, same energy.
- **Restyle, not new clips.** New converter options `knees`, `planar`, `upright` and `limit` act on the existing jog/run/sprint/diagonal loops. Straightening elbows alone was not enough: the source pumps across the chest, so a straight arm swung out sideways, and the 35° lean still read as athletics.
- **Lesson.** Render the converter output (a stick figure from the generated data is enough) before handing it over. It caught the sideways arm and the overhead arm swing on the Run clip without opening Studio.
- Next: the owner tries v4.5 in Studio; tune the strength of each option from their feedback.

## 2026-10-29 - Owner feedback on v4.5 (v4.6)

- The owner tested v4.5 in Studio: "looks horrible". Hands showed (they want no hands anywhere in the game) and the arms were tucked in "like a walking stance".
- **Reference.** The owner pointed to Huss Valley's Runner run (no knife). Approved yt-dlp to fetch their YouTube link; frames came from the Blender sequencer. Look for the role in the HUD: "PRESS SPACE TO CATCH" means a Catcher with a knife, "PRESS SPACE TO DASH" a Runner.
- **Lesson.** Scaling a source clip's arm swing cannot fix a clip whose arm barely moves (Sprint Forward). Deriving the arms from the legs gave every clip the same even stroke. Measure the swing ranges, not just the renders.
- Aiming switched off (`Config.Lab.Aim`); the owner says aiming is not in scope yet.
- Next: the owner tries v4.6.

## 2026-10-29 - Owner feedback on v4.6 (v4.7)

- Owner's final verdict: no elbows, knees or hands, only block limbs. The run was still shaky, slid, was not sharp, and was too upright ("looks disabled").
- **Root cause of the shake.** Two-sided ground contact pulled the body down whenever straight legs split. Feet now only push up. The forward tier also blended three mocap loops whose cycles did not line up.
- **Decision.** Stop restyling mocap for locomotion. Run, Sprint and the back-pedal are generated in `OriginalClips` for rigid limbs, and the joints are locked at runtime for everything else ([ADR 0007](decisions/0007-block-limbs-and-original-run.md)).
- **Lesson.** For a stylised blocky look, a small analytic cycle tuned against reference frames beats bending mocap: speed, sharpness and lean are each one number.
- Next: the owner tries v4.7. Crouch, landings and mantles may need block-limb versions.
## 2026-10-29 - Owner feedback on v4.7 (v4.8)

- The owner said the v4.7 run "looks like a basic Roblox run", nothing like the reference. Asked for an honest comparison first, I agreed: an even pendulum swing is the default R6 structure.
- **Reference, properly read.** It is pose-to-pose: a held kick (trailing leg back near horizontal, the opposite arm reaching forward), then a snap through the pass. The v4.6 "arm flare" was a misread of the forward reach from behind. Before calling a direction, confirm facing from a front view (accessories such as the shoulder cat and the front bag).
- **Owner also wants:** symmetric arms (the no-knife run); no slow-motion run or gap when stopping; a sharp, smooth reversal with no turn clip sliding after it. All mocap start/stop/turn transitions removed.
- Next: the owner tries v4.8.
## 2026-10-29 - Owner feedback on v4.8 (v4.9)

- Arm and leg movement "almost perfect". Asked for: more forward lean but only in the upper half, slightly wider legs, longer arms.
- Lean split into whole-body `lean` plus waist `bend`; arm angles were compensated so the approved swing keeps its look against the ground. "Wider" was read as sideways spread (6° per leg), with the stride kept; to confirm with the owner.
- Arms stretched 1.25x on the server (part size, attachments, Motor6D offsets), so peers see the same rig.
## 2026-10-29 - R6 rig (v5.0)

- The owner was frustrated: v4.9 still looked nothing like the reference ("limbs disconnected", "free where they join"). The real cause was the rig. The reference is classic R6, and its arm pivot sits a quarter of the way down the arm. Approved: switch to R6 and keep comparing until identical, while staying consistent with the other moves.
- **Lessons:**
  - Check the reference's rig type first. Plain avatars and line-ups reveal it; a puffy outfit hides it.
  - Without Studio access, compare with a solid-block renderer of the actual rig geometry. Stick figures hide pivot effects.
  - Read every frame at 60 fps when timing matters.
  - Per-limb timing matters: in the reference, the reach is early and the fall back is late.
- Clips stay in R15 terms and are converted at runtime, so no clip data changed. Mocap jumps and landing clash on R6; next candidates for block versions.
## 2026-10-29 - Idle fold and wall-run controls (v5.1, v5.2)

- R6 idle looked like floating: the mocap idle's bent knees tipped the block legs forward along the thigh. Limbs are now folded root-to-end (`FoldLimbs`/`chord`).
- Wall run: the kick fired on release and only under 0.2 s, so owner presses counted as climbs ("double tap to jump off"). It now kicks on press, and the climb is Space held from the jump. The held climb kept full speed for only part of its 2 s taper; it now stays full for 3 s.
- Lesson: release-timed taps under about 0.25 s read as unresponsive. Prefer acting on press, and give hold behaviour to the press that is already held.
## 2026-10-29 - Wall-jump direction (v5.3)

- The owner wants full control of the wall-jump direction, from a normal run or a wall run. The v4.4 three-way kick read wrongly: W along a wall run was a "side" kick (mostly forward), and W into a wall was an up-kick, then a forced bounce back on the second press.
- The kick now follows the camera-relative input, at least 30° off the wall, facing the launch. The up-kick is only for input nearly straight into the wall.
- Open question for the owner: what should holding straight into the wall do? It currently leaps up once, then bounces out.
## 2026-10-29 - Double-jump flips (v5.4)

- The owner wants flips as a double jump, with the direction picked by WASD as seen on screen (front, sides, back and diagonals).
- There were no side-flip downloads, so all eight directions come from one original tucked flip spun about the axis across each direction; the mocap flips were unmapped for one consistent set. The body turns to the camera's facing so the keys read on screen.
- Trade-off: an early press meant for a wall kick now double-jumps unless the wall is already in reach (the wall-kick buffer only applies once the flip is used).
## 2026-10-29 - Fast double taps (v5.5)

- A fast double tap gave a small jump with no flip. Likely causes (not reproduced live): presses within 0.12 s were debounced away, presses in the first 0.1 s of a jump were dropped, and the client reset the flip on lagging FloorMaterial, so the server could reject the flip after the relaunch.
- Lesson: buffer early inputs instead of dropping them, and keep client and server rules for one-per-airtime resources identical.
## 2026-10-29 - Spammed double jumps (v5.6)

- Flips were still lost when chaining double jumps. The server's 0.1 s, |vy| < 8 landing check missed one- or two-frame touchdowns, so it kept the flip spent and rejected the next one after the client had relaunched.
- Fix: a per-frame touchdown check on the server, a 0.8 s backstop between accepted flips, and a client reset on the Humanoid's `Landed` state. Lesson: a server rule that depends on seeing a brief event needs per-frame sampling or a backstop.
## 2026-10-29 - Wall-run tap versus hold (v5.7)

- Kick on press (v5.2) broke climbing that started later in a run. Back to deciding on release, with a 0.3 s tap window (0.2 s was shorter than ordinary taps); a press climbs at once, so holding has no lag. The climb allowance now counts held time.
- Lesson: when one button means both tap and hold, start the hold behaviour on press and resolve the tap on release, with a generous window.
## 2026-10-29 - Slide and sprint controls (v5.8)

- Design talk: I recommended a ground dash plus crouch-slide; the owner judged a dash too much movement alongside the double-jump flip and chose **slide on Shift** only (no C slide), with no ground rolls. Sprint is double-tap W.
- The slide follows CoD/Rivals/Tribes: boosted, momentum-keeping, jump-cancel into a slide-jump, Shift to stand. Air momentum above the run target now bleeds slowly, so slide-jumps carry.

## 2026-10-30 - Faster slide, buffered slide input, new slide pose (v5.9)

- Owner on v5.8: the slide should be noticeably faster; presses straight after a jump or a wall run were lost; the animation should be cooler.
- Cause of lost presses: the slide was accepted only when already grounded and free, so presses in the air or on the landing frame were dropped. Now they wait 0.4 s, or as long as Shift stays held, and fire on touchdown. Boost became additive (+15, max 46, end 20, 0.8 s).
- Lesson: every action key that can be pressed slightly early (jump, flip, slide) needs a buffer, not just a state check.

## 2026-10-30 - Higher, bouncier jump (v6.0)

- Owner: the first jump should be noticeably higher and bouncier, not frog leaps. Height comes from JumpPower (52 to 62); the bounce comes from 1.12x gravity during a ground jump only, which keeps airtime about the same (higher power alone adds float). Double jumps, kicks and other actions turn it off, so their tuning is untouched.
- Next, per the owner: fine-tune flips, then vaults and mounts (mantles). The higher jump now clears some ledges that used to be mantled.

## 2026-10-30 - Flashy flips (v6.1)

- Owner: flips felt like loose tumble rolls; they want them far cooler, compact and distinctive, as Slugterra is about style. Web searches found nothing on the show's choreography, so the set uses real tricking moves: front tuck, back full, aerial, off-axis split, corkscrew.
- Causes found: an R15 knee tuck folds into straight, splayed legs on R6; rotating about the hips makes the body orbit a point below itself; even spin speed reads as a tumble. Fixes: R6-native poses, a clip pivot at the torso's middle, and spin that is fastest while compact.
- Lesson: author R6 poses directly. Bent-limb R15 shapes fold into something else on block limbs.
- v6.2 (same day): the owner liked only the back full (a layout backflip with a full twist, 'a really cool twirl') and disliked the trail. Every direction is now a full-twist spin with that timing, distinct by axis and shape; trail off. Owner taste: twisting spins over plain tucks or splits.

## 2026-10-30 - Ctrl shift lock (v6.3)

- Owner asked for shift lock on Ctrl. Roblox's mouse lock was already off in the lab projects (EnableMouseLockOption false, which keeps Shift free for the slide), so the lab has its own: the mouse is re-locked after the camera's render step, the body turns to the camera when no action runs, and the shoulder offset is computed in camera space.
- v6.4: the owner standardised the diagonals on the back-side corkscrew; W+A/W+D now use it, tipping forward (the butterfly twist is gone).
- v6.5: the diagonals are 'perfect'. The front, back and side looked alike (twisting with the legs up), so only the back (now arms overhead) and the diagonals twist. W is a double front tuck with a kick-out; A/D is a parkour side flip with the outside leg leading.
- v6.6: the double front and side tuck were 'too basic'. After several single guesses were rejected, there are now three candidates per direction (front: Webster, flip kick, swan dive; side: aerial, butterfly kick, barrel roll), switched in the lab with F/G so the owner picks by playing. Remove the unpicked ones afterwards.
- v6.7: the owner picked the flip kick for W (slowed a little). The side candidates 'all look the same': the selection reaches the animation, so they likely did not read at speed. New side candidates each end or pause in a held, readable shape (side flip kick, tornado kick, aerial holding a split). Lesson: at about 0.4 s of airtime, a flip needs a held silhouette to read; spin alone blurs together.
- v6.8: the owner wants side flips as a horizontal twist, the flat counterpart of the back and diagonal twists, acrobatic and not a 'torpedo'. Researched the butterfly twist (Wikipedia, FlashMavi, FIG aerobic code): dip, straight-leg kick, flat straddle with wing arms, hands in to twist, open to land on one leg. Three candidates on G: single, double, twist into a side kick.
- v6.9: the owner picked the single butterfly twist; arms crossed through the twist looked 'restricted', so they now windmill (one overhead along the body, one swept back, swapping). Flip set settled for now: W flip kick, S back full (arms overhead), A/D butterfly twist, diagonals corkscrew.

## 2026-10-30 - Continuous run candidates (v7.0)

- Flips 'pretty much perfect'. The run and sprint are 'still poo': stiff, robotic, choppy, with the arms, legs and lean all off. The owner chose in-game candidates and a sprint more extreme than the run.
- The pose-to-pose holds matched to the reference read as freeze-and-jerk in motion. Replaced with a continuous generator and three styles (Stride, Power, Dash) on G.
- Lesson: matching a reference's still frames does not guarantee its motion reads well; judge the cycle in motion.
- v7.1: the owner picked the Power run and wants it bouncier and more energetic. They reported an arm stuck up when running upstairs (the presentation took any rise over 6 studs/s as airborne, so it played the jump pose) and a poor idle (the mocap breathing idle's slouch reads as rolled-forward shoulders on R6) with a cut into it. Fixes: springier Power, a StepRise grounded rule, three original R6 idles on G, and a gentler idle blend.
- v7.2: the owner said the idles looked basic, falls were too dramatic (the mocap jump apex has an arm up, held on any fall) and strafes and back-run were underwhelming and slow (the old strafe was built for 16 studs/s, played at 24). Fixes: an R6 Air clip with the flail only on long falls, bolder idle candidates, and strafes and back-run made from the run generator.
- v7.3: the owner picked the Restless idle (legs not spread) and asked for more animation. They missed the mocap running jump: it only looked wrong when walking off stairs (a rise over 10 studs/s counted as a jump). Real jumps use the mocap again; edge drops use the calm R6 air; the jump test uses StepRise (30).

## 2026-10-30 - Fall transition and R6 mantles (v7.4)

- Owner: falling from stairs cut in (no fade on the first air pose); mantles were too fast (0.2-0.3 s) and the vault was horrendous (mocap on R6). Asked for research into parkour mantles.
- Walk-offs now blend from the run into the fall. Four original R6 mantles (climb-up, step-up, pop-up, kong vault) were modelled on parkour technique and checked against ledge geometry with the client's root path; 0.38-0.6 s; private mocap mantles skipped via OriginalClips.replaces.
- Lesson: an earlier 'faster' request can overshoot; when the owner says something is too quick, check the numbers first.

## 2026-10-30 - Wider legs (v7.5)

- Owner: the legs look narrow; move them further apart without splaying them into a V.
- Each R6 hip joint's C0 moves 0.15 studs out on the server (`Avatar.LegSpread`); renders of 0-0.25 studs showed 0.15 as a clear gap that still reads as one body.
- v7.6: at 0.15 the legs 'look too disconnected': with the idle's 7-degree stance, the tops stuck out past the torso. Now 0.06, nearly flush. The idle's arms moved too much, so they keep about a third of the swing. The owner asked for a neck stretch and a dust-off with no cut in. Both are original R6 fidgets that alternate after 6-10 s idle, start and end on the idle's centre pose, and fade in over 0.5 s and out over 0.6 s on top of the live idle.

## 2026-10-30 - Mocap neck stretch layered on the idle (v7.7)

- Owner: the original neck stretch looked weird. Use the Mixamo clip, make the transitions smooth (not idle → stretch → idle) and remove the dust-off.
- The Mixamo clip's body stance differs a lot from the R6 idle, so a weighted blend visibly changed stance. Fix: layer the clip's motion since its first frame onto the live idle (`Clips.layer`). Studio check: body within 6°, head steps up to 10.4° per 0.1 s, no snaps.
- Lesson: when a mocap one-shot plays over an original idle, layer its motion rather than blending its pose.

## 2026-10-30 - Whole-system review and cleanup pass (v7.8)

- The owner asked for a review of the whole movement system, then for every problem found to be fixed before committing, and confirmed the ground roll should go.
- Done: roll removed; dead references removed (clip-less start/stop/turn moves, diagonal sprint and jog names, hanging climb, old idle, flip trail, `OriginalClips.replaces`, unused private mappings); full strict type check in `verify_movement.py` with pinned luau-lsp definitions; multi-height, multi-lane ledge detection; per-frame waste trimmed; server counts unexplained air boosts without correcting them; pose preview tool in the repo; private clips audited on R6.
- Two sessions edited this branch in parallel (v7.7 in another session). Check file timestamps and `docs/memory.md` before building on stale context, and coordinate before large edits.
- Lesson: checks that type-checked one 17-line file gave false confidence about 6,000 lines marked strict; the full check found 26 errors.
- Lesson: a review hypothesis (back-diagonal blends cancelling the leg swing) was wrong when measured; check numerically before reporting.

## 2026-10-30 - Light server authority (v7.9)

- The owner chose the light option after the explanation of client-trusted physics: keep client-owned movement for feel, correct what nothing explains.
- The server snaps back unexplained air boosts and wall passes (resolved 0.6 s later, against accepted actions) and clamps upward speed over 75. It is counted, shown on the HUD and switchable per kind. Server-run movement stays open for competitive play.
- Unverified at runtime; the first playtest should watch `Corrections` stay at 0.
- v7.10: the owner reported first jumps from a ledge edge turning into the double-jump flip. The Humanoid's floor check misses edges, so the jump check now uses a footprint spherecast plus 0.15 s coyote time, and launches the jump itself when the Humanoid thinks it is falling. The server's touchdown check uses the same footprint, so the new air-boost correction does not snap edge jumps back.
- v7.11: the owner found the wall run slow and wanted wall jumps to carry further. Wall run at 34 minimum (was 26), stronger kicks, and kicks keep up to 44 studs/s after their lock. Lesson: the post-kick handover had capped speed at sprint (30), silently cancelling any stronger kick.
- v7.12: running landings showed spread legs (the landing clip still at ~45% on the run) and cut into the run; strafe left-to-right cut (velocity through zero flips the travel angle in one frame). Fixes: no landing clip when moving plus a 0.22 s crossfade, and smoothed direction-clip weights. Lesson: any blend keyed off the velocity's direction needs smoothing, because reversals flip it instantly.
- v7.13: the owner found wall-run attach delayed (and lower than aimed) and wall jumps unresponsive. Causes: a 0.13 s post-takeoff lockout, a low cap on kept rise, air presses near walls falling through to the flip, and wall-run kicks firing on release. Lesson: when one button means several things, an input that misses its first meaning must not silently fall through to another.
- v7.14: the owner asked for more animated, parkour-style vaults. The kong vault is rebuilt with nine keys and checked with the in-repo preview tool; a first try dragged the trail foot through the far edge, which the new feet past-face report caught.
- v7.15: the owner said the vault lost momentum afterwards (it ran at about 13 studs/s over a fixed 2.4-stud landing and eased to a stop). It now keeps the approach speed and lands as far as that carries; the start gained a wind-up. Lesson: traversal clips that move the root must match the speed going in and coming out, not only look right.
- v7.16: a flip onto a wall still delayed the wall run (the flip blocked other actions until it ended). Flips now give way to wall runs, kicks and mantles.
- v7.17: the owner did not want holding Space on a wall run to mantle by itself. Holding now runs along the top edge; a fresh press mantles, and a press aimed off the wall jumps off.
- v7.18: the owner wanted sprinting clearly different from running: run 22 (owner's number), a subtle sprint camera shake, and a wider sprint field of view.
- v7.19: the sprint shake was 'really bad': no camera tilt or wobble, only a very subtle step bounce. Keep camera effects minimal for this owner.
- v7.20: the front flip kick looked out of place next to the twisting flips. Three candidates on G (twist kick, tornado kick, star full) for the owner to pick, following the earlier lesson that single guesses kept being rejected.
- Lesson: Windows PowerShell 5.1 `Get-Content`/`Set-Content` re-encodes UTF-8 (it garbled the HUD's separators in v7.14). Edit files with the Edit tool or Python bytes, never PowerShell text cmdlets.
- v7.21: the owner rejected all v7.20 front flips and found the twist kick too fast to read. They asked for research first. New candidates from gymnastics and tricking references (front aerial, layout step-out, X-out) spin slower through open, held shapes. Lesson: very fast twists blur at game speed; this owner wants flips readable as well as flashy.
- v7.22: the owner picked the front aerial and asked for it slightly faster with more flair: rotation done by 0.44, arms windmilling through the split. Flip set: W front aerial, S back full, A/D butterfly twist, diagonals corkscrew.
- v7.23: the owner rejected the untwisted front aerial: the front flip needs spin like the others, but must not be basic. Three twisting candidates on G, with the twist spread over the flip (about 1100°/s) through open shapes. The owner's tension: spinning like the rest, yet readable (the 1650°/s twist kick was too fast).
- v7.24: the owner picked the front full step-out, asked for it a fraction faster and for the face never to look back at the camera mid-flip. A full twist that tracks the somersault exactly keeps the face away or side-on. Flip set: W front full step-out, S back full, A/D butterfly twist, diagonals corkscrew.
- v7.25: the owner said the front flip is now perfect. The mocap crouch's arms looked like holding an imaginary gun, so an original R6 crouch set replaced it (staggered stance, relaxed arms, sneaking steps), crossfaded in and out, and faster at 13 studs/s.
- v7.26: the owner said the v7.25 crouch did not squat at all. Lesson: on R6 with push-up-only ground contact, the body is only as low as the clip's RootPos and leg angles allow; a crouch needs legs angled well forward and a large RootPos drop, and the camera should dip too.
- v7.27: the owner removed crouch as a feature for now (after two crouch attempts), from all code and notes.
- v7.28: the owner had no directional control on a wall run. Input along the wall now sets the speed, no input clings (Space: straight up), and back turns round.
- v7.29: the owner wanted a cling: jumping into a wall and doing nothing (or stopping a wall run) stays on the wall, dragging slowly down. Head-on jumps now attach (unless a ledge is in reach to mantle), and a slow 4 studs/s drag replaces the speeding slide when not running along the wall.
- 2026-10-30: the owner asked for everything to be pushed and put on `main`. The branch was fast-forwarded into `main`; the movement code stays in `experiments/movement`, separate from the foundation place.
- v7.30: the owner described the cling: Spider-Man-like, facing the wall, one hand on it, one arm off, feet stuck to it, slowly dragging, a quick stop from a run. Fitted on the renderer; the body moves in to 1.2 studs while clinging so the hand and feet reach the wall.
- v7.31: the owner shared wall-slide reference images (back to the wall, hand flat on it behind, other arm out) and wanted an instant stop and a straight-down slide. Fitted on the renderer at the blocks' corners. Lesson: contact for R6 blocks must be measured at the block corners, not the end centre, or limbs sink into surfaces.
- v7.32: the slide began about 2 s after stopping (Space held kept the old 'climb with no direction' rule going), and the pose blend counted the pull toward the wall as running, so the owner saw a half-blended pose. Stopping now always slides; the pose was refitted with the hand at head height.

## 2026-10-30 — Rocklock spacious cavern greybox

- **Confirmed:** the pasted owner request authorized the isolated playable map, original procedural Blender geometry, source/exports/previews and Studio tests; no controller/camera rebalance, main merge, publication or private-asset redistribution. Work is on `experiment/rocklock-greybox`.
- **Confirmed correction:** the owner saw the first map and found it crowded. They want wide Slugterra-like caverns for gunplay and larger transformed slugs, not many closely packed structures. v2 expands 100 × 90 to 160 × 140, removes crowns, tower stairs, shoulder blocks and training stones, and uses broad ordinary ramps. Keep that spaciousness preference in later iterations.
- **Implemented/verified:** shared layout → headless Blender → native, noncolliding faceted art plus 35 simple collision pieces; editable `.blend`, FBX roundtrip, eight previews, structured coordinates and disabled interaction metadata. Separate Rojo projects preserve the lab/foundation. A generated server copy adapts only initial placement through stable opposite spawn slots before validation history initializes; controller and camera sources are untouched. [ADR 0010](decisions/0010-rocklock-map.md).
- **Implemented/verified:** full offline checks passed. Two Studio clients completed flank ramp/crossing, wall-run/kick, underpass, first jump, flip, slide/slide-jump, peer action observation and stable opposite respawn; each had 6 accepted actions, 0 rejected requests, 0 corrections. Two first-jump samples: about 16.46 travel and 10.87–10.88 rise. 108 enclosure rays hit boundary collision. [Results and limits](rocklock-verification.md).
- **Unresolved:** subjective feel/scale, gunfight timing/balance, actual larger-form dimensions, exhaustive camera/escape/stuck tests, devices/controlled FPS/network impairments. One test client averaged ~68 ms/frame, the other ~16.85 ms; window focus/throttling was not controlled. A first harness failed because plugin-only settings() was called inside a game Script; it was corrected and rerun.
- **Workflow lesson:** a fresh Studio file can show a Lighting Technology Migration dialog if the generated place defaults to Compatibility. Rocklock explicitly uses Voxel. Close the generated test window and discard temporary QA edits before rebuilding; preserve unrelated unsaved windows. Never save a stale open place over the rebuild.
- **Implemented/verified final handoff:** the public original-clip build passed a spawn/flip/slide smoke (0 rejections/corrections). The final private map was rebuilt and reopened; W/Space reached the north cover with 0 rejections/corrections, then play stopped. Two noncolliding fill-light hosts improve the expanded floor visibility; final count 4,854 Parts / 35 solid pieces. QA fixtures are absent.

## 2026-10-30 — Rocklock v3 size change

- **Confirmed:** the owner said v2 was too small and requested about 33% more size as the first change. **Implemented:** v3 scales both horizontal dimensions and the existing geometry/coordinates by 1.33, from 160 × 140 to 212.8 × 186.2 studs; floor area rises about 76.9%. Traversal heights, movement and camera stay unchanged.
- **Implemented:** separate `-v3` public/private build outputs leave the owner’s already-playing v2 place and its unsaved session alone. Existing Blender source and export matched their recorded hashes before regeneration.
- **Verified, limited:** full automated foundation/movement/map checks passed; the v3 Studio place opened with 153.10-stud spawn separation, direct spawn cover, and all 108 boundary rays hitting collision. One correction was observed in an active play session; cause and repeatability remain unresolved. Two-client checks are recorded separately.
- **Verified, v3 two-client rerun:** both clients completed their flank and underpass routes, wall runs/kicks, flips, slides/slide-jumps, observed peer actions and respawned to opposite ends; each had 6 accepted, 0 rejected and 0 corrections. The first attempt timed out at the old seven-second spawn-route limit under background throttling; the rerun used twice the limit. The separate owner play session had 1 correction and 1 suspect air boost (42 accepted, 0 rejected); cause unresolved and not reproduced by the scripted routes. [Evidence](evidence/2026-10-30-rocklock-v3.json).

## 2026-10-31 - Rocklock V2 redesign (Claude)

- **Confirmed:** the owner's Rocklock V2 brief and addendum: all attacks damage all ordinary destructibles via structural HP; four categories; anchored large rubble; no mid-round regeneration; exact reset; build alongside v1 (Codex continues the existing map).
- **Implemented:** `tools/rocklock_v2` (layout, Blender geology, build, render, diagram), `experiments/rocklock-v2` (destruction config/server/self-test/client), `rocklock-v2*.project.json`, `tools/verify_rocklock_v2.py`, [docs](rocklock-v2.md), [ADR 0011](decisions/0011-rocklock-v2-destruction.md).
- **Verified offline:** 105 v2 checks and the movement/foundation suites pass; 6,107 parts.
- **Owner feedback:** 140 × 112 felt "tiny and packed"; scaled to 210 × 168 with movement-tuned heights and gaps fixed. The first draft also had the Eyrie brace blocking the shaft seal (fixed with two side legs). **Not run:** Studio, self-test, two clients. The owner's PC froze several times on 2026-10-30 while Studio was driven automatically (a local upload plugin, stacked Studio windows and disk paging errors), so Claude now leaves Studio runs to the owner.
- **Research limits:** the Rocklock wiki (HTTP 402) and Slug Arsenal pages (certificate failure) were unreadable; Rammstone and Armashelt abilities were confirmed via search results only.


## 2026-10-31 - Floppy silhouette/face variant
- The owner rejected the baseline look ("too solid and hard", eyes "glued on", lifeless mouth) and asked for a drowsy/drunk slug with spinning spiral eyes. Built `create_floppy_variant.py` as a separate variant; baseline untouched. Owner review pending.
- Owner calls the species "Floppy". That name is very close to the franchise "Flopper", so a final name stays Unresolved.
- Follow-up: added drool, jaw sag and faster spiral spin, an hourglass front, and eye rims; removed the lid crease. Opened the variant in the owner's live Blender.
- Second follow-up: domed eyes with lid shells, mirrored sockets and bags, brows and crown markings, flared antenna roots, a short tail, and squishier shape, material and animation. Reloaded the variant in the owner's Blender.
- The owner chose to agree the design on paper before more 3D work, and confirmed the tail stays short. Published a private concept sheet (four front/side body plans: Pear Puddle, Upright Trailer, Slumped Sleeper, Low Crawler, plus a face study): https://claude.ai/artifact/5FPBsEBNTuVZbbo34waKX8. Waiting for the owner's pick.
- The owner preferred concept C (Slumped Sleeper) but said the 2D drawings looked like flat shapes on a silhouette with no visible belly and no jelly or slime. They asked for closed concentric rings instead of a spiral, arranged differently in each eye and spinning, and for a dark comic-style drool drip in the mouth colour instead of a blue blob. Published a rotatable real-time 3D concept (blended soft volumes, jelly shading, ring eyes): https://claude.ai/artifact/MwVjdTDUNVQPdccC37VJyo. Its blended-volume construction could map to Blender metaballs/voxel remeshing for the game model. Waiting for owner review.
- Owner feedback on the 3D concept: drool should come out of the mouth like their anime reference (a pale strand whose dark outline continues the mouth line), not sit on top; eyes bulged like bug eyes; antennae looked angular. Concept v2 has a drool strand from inside the mouth with a toon outline, shallow lens-shaped eyes, and single smooth-curve antennae.
- Owner: drool must be part of the mouth, dropping from the bottom lip with no separate piece; motion was too bouncy (especially the top half); cheeks too chubby. Concept v3: drool drawn on the skin from the lower lip with the mouth's outline, wobble cut to about a third and slowed, slimmer cheeks.
- Owner: drool must continue from the bottom lip with no top bulb; the eyes poked out below the lids and looked crazy rather than drowsy; the dark eye patches were gone; the head was too wide and bulbous. Concept v4: drool starts inside the mouth so only the part below the lip shows; lower lids added and upper lids half-closed; slower spin and thinner rings; dark under-eye patches restored; narrower head with the face refitted.
- Owner: top of the head looked flat from the front; asked for antennae higher, a taller rounder head, a more drowsy/stoned grin, drool a tad right of the mouth corner, and a base that sticks to the floor instead of looking like a chess piece. Concept v5: crown dome and taller head, antenna roots raised, lazy lopsided grin, drool moved toward the centre, body melting into a soft spread foot (a flat plate attempt looked like a candle holder and was replaced).
- Owner: fill the sunken upper corners of the head so it reads round; smaller cheeks; shorten the mouth where it reached the eyelid; foot should stick to the floor like a snail's rather than round off; antennae further forward on the forehead at the same spacing. Concept v6: wider crown dome, smaller cheeks, shorter and lower mouth, a thin sole blended in with a concave fillet under a wider lower body, antenna roots moved forward.
- Owner: dark under-eye patches more prominent; eyes still bulged. Concept v7: larger, darker under-eye patches; eye lenses flatter (depth 0.11 to 0.07) and the eye/lid set sunk further into the face.
- Owner: remove the green dots for now (they clashed with the dark patches); make the under-eye darkness diffuse rather than a concentrated oval; remove the under-eye bulge and the eyebrow-like ridges. Concept v8: freckles, brow ridges and under-eye puff removed; wide, soft, uneven dark shading under the eyes.
- Owner: the diffuse patches looked like bruising; wanted normal tired dark circles under the lower lid, following the eye's round outline. Concept v9: a soft brown-grey crescent just outside the lower lid edge.
- Owner likes how the eye edges blend into the face (keep this). Asked for eyes slightly more raised and slightly further apart; the dark circles read as a vague shadow ring, not eye bags. Concept v10: eye depth 0.085 and eyes at x ±0.37; bags are now a mauve-brown crescent of darker skin under each lower lid, thickest in the middle.
- Owner: the lower lid looked multi-layered after the bags were added, and the darkness should diffuse onto the lids; 'almost there, basically perfect'. Concept v11: removed the hard bag edge and the lid tint ring, blended the lids more softly, and faded the darkness up onto the lower lid. Lesson: hard colour edges near a geometric lid edge read as extra layers.
- Owner: 'genuinely almost perfect'. Asked for a slightly smaller eye-bag area with a softer outer fade. Concept v12: smaller Gaussian-falloff bag that fades into the skin on every side.
- Owner: eye-bag size 'perfect' after re-expanding. Final tweak: antennae further forward on the forehead and the head top raised a little more. Concept v14: head and crown dome taller, antenna roots further forward.
- Owner called the concept 'perfect' after the head/antenna change. Final tweak: thicker rings that vary in thickness within each eye; the more open eye (character's right, viewer's left) has clearly bolder rings. Concept v15 published, and a copy of the concept source was saved as the build reference at docs/slugs/catalog/evidence/floppy-concept-3d.html.
- Owner: the base looked too flat, uniform, cleanly flared, slightly cut off, like a smooth bell; wanted a soft, bodyweight, squishy pooled edge with a subtle slime base, natural and asymmetric. Concept v16: lobed, asymmetric sagging lower mass with a thin rounded pooled edge, a see-through glossy slime film around it, wetter skin near the floor. Reference copy updated.
- Owner loves the new base. Asked to remove the slime film for now; a slime trail is a possible later addition (Considering, not approved). Concept v17: slime film and floor sheen removed, base unchanged, reference copy updated.
- Owner approved Floppy V1 ('this is perfect'). Saved the source and five renders to docs/slugs/catalog/evidence/floppy/, recorded the design spec in the catalogue, and deleted the rejected Blender variant and earlier concept files at the owner's request. Next: touch-up details, then the Blender build.
- Deleted the round-1 concept sheet page (its link no longer works).
- Owner supplied the Floppy palette (#91B8AE body, #8996AC upper lids, #31585B lower lids, #D8D3BE belly, #527F79 back markings) and asked for improvised, original, restrained patterns plus darker antenna stripes. Applied in the V1 page with spine lozenges and petrol-teal antenna stripes; reference copy and renders refreshed.
- Owner: the palette looked way too blue; wanted green/brown, belly stripes, no antenna stripes and coloured antenna-tip bulbs. Applied a warmer sage/taupe/moss/stone palette (hex values in the catalogue); reference copy and renders refreshed.
- Owner: upper lids too light; they should be a darker green, a bit darker than the skin but lighter than the lower lids. Belly stripes should be more prominent but still blend. Applied #7A8C62 lids and #A8946E stripes at higher strength; reference refreshed.
- Owner: body green should be paler and more yellow, closer to (but not matching) the belly; belly stripes should be the same colour strength. Applied #BAC1A2 body, #9CA77F lids, lighter back shading and an even stripe mask; reference refreshed.
- Owner: lower lids should be a muddy brownish green; add a brown outline around the belly enclosing the stripes; denser stripe colour; body a tiny bit darker with more yellow-brown-green. Applied #5A5934 lids, a #6B4E2E belly outline, #8E7550 stripes and a #B0B48A body; reference refreshed.
- Owner found the brown belly outline ugly; switched to a softer muddy brown-green outline (#6E6B3E). Reference refreshed.
- Owner disliked the painted brown belly stripes and chose soft belly folds: real geometric rolls with creases, uneven spacing and depth, inside the green outline. Reference refreshed.
- Owner: the folds looked like creases; wanted actual folds. Changed the profile to overhanging rolls (steep tucked underside, gentle top), made them fewer and fuller. Reference refreshed.
- Owner: upper lids a little darker than the skin but less dark than the lower lids. Applied #888F68; reference refreshed.
- Owner: 'this is perfect... this is the Floppy design. This is our Floppy.' Renamed the page and record to Floppy, replaced the V1 save with docs/slugs/catalog/evidence/floppy/ (floppy.html plus five renders). The committed baseline Blender model is still kept pending the owner's decision.
- Built Floppy in Blender with tools/slugs/build_floppy.py (concept SDF ported to NumPy, surface nets, exact texture bake, ring-eye textures, 9-bone rig, 12 s looping idle). Concept motion rates aligned to the loop. Opened in the owner's Blender. Game-budget version and FBX/Studio are next.
- Owner: the build is perfect but too pale; wanted more depth, then the Roblox version. Added baked AO, a deeper grade and less SSS. Made the Roblox export (8k body, 400 per eye, 1024 maps, 8 bones, scale-free 12 s idle, faces -Z in Roblox). Verified by FBX reimport. Studio import is the owner's step (no Studio connection; importing uploads assets).
- Owner approved uploading Floppy to their account; uploaded the GLB via Open Cloud (ID kept in private-assets). Added a Floppy test place with a client-side idle and opened it in a new Studio window (Rocklock's Studio left open). Registered the Roblox Studio MCP at user scope so every worktree gets it after a restart.
- Owner: Floppy looks the same in Studio, but needs a subtle slimy gloss and must fit in the blasters. Export now at 0.09 scale (0.22 studs, asserted against the blaster canister) with roughness maps; re-uploaded; test place shows Floppy on a pedestal next to the blaster.
- Owner: the blaster-sized Floppy (0.22 studs) was invisible; set it to about 1 stud tall and said the gun will be resized to fit. More gloss on the bottom half. Export now 0.405 scale (1.0 stud) with base-to-head roughness 0.10 to 0.22; re-uploaded; test place reopened.
- Owner: about 33% smaller, mostly thinner, mainly a narrower base. Narrowed base/pooled edge/tail in the concept and build; export now 0.304 scale (0.60 × 0.54 × 0.75 studs); re-uploaded; test place reopened.
- Owner: 0.75 studs is the smallest a slug should be; make it a little taller, not thicker; resize the gun so the slug fits in the shell and let them equip it. Torso-only stretch (0.83 studs); display blaster Tool scaled 3.05x in the Floppy test place with Floppy in a glass canister; real Rocklock blaster untouched (out of scope here).
- Owner: the 3x blaster was ridiculously big; slugs should be a bit bigger on the ground and shrink when loaded. Ground Floppy 0.34 scale (0.92 studs); test blaster back to Rocklock size; loaded Floppy scaled at runtime to the canister; idle scale derived per model from eye spacing.
- Owner: loaded Floppy far too small for the canister. The fit used an inflated bounding box; now sized from eye spacing and source dimensions and centred on the root bone, so he fills the shell.
- Owner: brighten the chamber so the loaded slug shows better. The canister glass is now clearer (0.78 transparency, pale tint) with a soft PointLight inside.
- Owner: the clear glass read as dark, not lit. The chamber is now faint see-through neon (0.86 transparency) with a stronger inside light and a soft Highlight fill on the loaded slug.
- Owner: the slug looked pale/white inside (the white Highlight fill); wanted deep blue glass that glows as the light source. Removed the fill; canister now deep blue see-through neon (0.72) with a blue PointLight.
- Owner: glass good, but the slug looked dark blue. Inside light now neutral warm white (brightness 4); glass more see-through (0.82) but still glowing blue.
- Owner: slug still deep blue; glass should glow without tinting the slug; dark sky to show the glow. A neon shell tints whatever is behind it, so the canister is now clear lightly-blue Glass (0.88) with neon blue rings and edge strips, a warm 3-stud light inside, and the test place is at night with bloom and a lamp on the pedestal.
- Owner: glow underwhelming and not lighting the slug. Glass material blurred/darkened him; shell now clear SmoothPlastic (0.9), two warm white lamps beside the slug, a blue 6-stud area glow, thicker neon trim and stronger bloom. Lesson: Roblox Glass blurs what's behind it and Neon tints it; light the subject with nearby lights.
- Owner: blue too strong/neon; wanted a clear, light-blue, subtler glow with the inside of the shell well lit. Trim now pale blue at 0.45 transparency and thinner, spill light pale and weak (1.2, 3.5 studs), bloom reduced, inside lamps slightly stronger.
- Owner: lighting flickered between an orange-flare state and a dark state; the inside wasn't lit. Small PointLights inside the gun flicker with Roblox light culling and flared the orange prongs. Removed them; the loaded slug now has a constant sage-green Highlight fill (0.55); one faint pale-blue spill light remains. Lesson: don't rely on tiny interior lights for visibility.
- Owner: light the inside calmly and lightly, not pale. Inner sage glow softened to 0.72 fill transparency. Session paused here at the owner's request; open items: owner verdict on the chamber glow, resizing the real Rocklock blaster (other branch), Studio MCP available after a session restart.

## 2026-10-31 — Review and backup of all local work

- **Confirmed:** owner requested review of the Claude handoff, final Floppy and blaster plus committing/pushing all work including movement.
- **Implemented/verified offline:** live multi-angle/idle review, source/export hashes, FBX reimport, full creature/movement checks and both Rocklock offline checks. [Detailed review](reviews/2026-10-31-work-review.md) records exact findings, branch separation and remaining gates.
- **Unresolved:** game-mesh winding/degenerate-face cleanup, genuine chamber illumination, Studio runtime/peers, slower-controller map integration and owner verdict. Art unchanged; private assets/IDs remain ignored.

## 2026-10-31 - Shorter blaster grip and 12% smaller gun

- **Confirmed:** owner requested a shorter handle and about 12% smaller gun while refining Floppy's loaded test.
- **Implemented:** Rocklock Blaster scale multiplies by 0.88; its private mesh mapping now points to the owner-approved existing gun with geometry below the grip junction shortened to 82%. Native fallback grip is shortened too. The same refit is used by the Floppy test tool. Map/destruction and movement behaviour are unchanged. The reproducible refit script is on `feature/slug-asset-pipeline` under `tools/slugs/refit_floppy_blaster.py`; source input and reusable IDs stay private.
- **Verified offline:** `python tools/verify_rocklock_v2.py --skip-movement` passes (types, lint, layout, builds and isolation). **Unresolved:** final hand fit/appearance in Studio.

## 2026-10-31 - Angular blaster finish and downward muzzle bevels

- **Confirmed:** owner requested a less toy-like finish, more compact grip/barrel and a white glowing spiral, then specified downward angular tips retaining the open firing channel.
- **Implemented:** private mesh mapping updated to the final solid-capped downward-bevel version with burnt orange, graphite/steel and white Neon vanes. Native stand-in uses the updated palette, shorter grip/nose and white charger. Existing 0.88 overall scale remains. No map or movement change. Refitter/evidence are on `feature/slug-asset-pipeline` (`docs/slugs/blaster-refinement.md`).
- **Verified offline:** Rocklock v2 verifier with `--skip-movement` passes. **Unresolved:** owner art/hand-fit judgment and inherited rear contact QA; final lighting changes are scoped to the Floppy test place.

## 2026-10-31 — Original gun draw and holster

- **Confirmed:** owner requests brief wrist twists/twirls for equip/unequip, with no throws or body spins.
- **Implemented/verified offline:** shared original 0.42/0.34 s Floppy/Rocklock gestures, palm-pivot additive driver and material-preserving holster clone; removed the competing old full spin. Movement/foundation and Rocklock v1/v2 checks pass. See [motion notes](blaster-motion.md).
- **Unresolved:** actual Studio hand fit, rapid switching/death and peer playback. Maximum Studio windows blocked the new test window; existing sessions preserved.

## 2026-10-31 — Solid muzzle private mesh update

- **Confirmed:** owner requests slightly longer, flatter angular muzzle tips and solid orange replacing both oval vents.
- **Implemented/verified offline:** new private model mapping, with prior mapping preserved; Rocklock private places rebuilt and v2 checks pass. Source and geometry validation live on feature/slug-asset-pipeline. [Record](solid-muzzle.md).
- **Unresolved:** refreshed Studio art/runtime; no map, movement or draw/holster code changed in this follow-up.


## 2026-10-31 — Blaster draw/holster flourish redo

- **Confirmed (owner):** the previous draw left the gun held out to the side after re-equips and showed no visible flourish. Wants acrobatic, Slugterra-esque but original spins, short, never disruptive, clean under offhand spam, several options to pick from.
- **Cause:** `BlasterAnimator` and `Presentation` both wrote `RightGrip.C0`; Presentation captured the animator's first draw frame (about -70° roll) as its rest grip, baking the twist into the hold and overwriting the flourish each frame.
- **Implemented/verified offline:** the animator now writes only `RightGrip.C1` (tool Grip side), leaving C0 to the hold presentation. Four candidate styles in `BlasterMotion` (Trigger twirl, Flip toss, Pinwheel, Snap spin), spins pivot at the trigger guard and are carried clear of the R6 block arm; interrupted flourishes blend (0.08 s, short-way angles); switches within 0.6 s play at 1.6×. J cycles the draw style (H is the lab's Hurt key). `verify_movement.py` passes; unified place rebuilt.
- **Unresolved:** Studio runtime/visual check (MCP not connected this session), peer replication of the chosen style (attribute is client-local), owner's pick among the four.
- **Follow-up (owner):** picked Flip toss (now default). Arm felt static, so the Toss shoulder track now cocks back, flicks up to launch, follows the gun, gives on the catch and rebounds; the free arm counter-swings at 0.3× the gun arm's pitch. Checks pass; Studio look unverified by agent.
- **Follow-up (owner):** from behind while running, the toss draw's backflip read as flipping the gun downward; the draw now flips forward like Trigger twirl. Holster unchanged.
- **Follow-up (owner):** while running the flourishes were hidden by the run arm swing (carry weight 0.4-0.6) and by the hold dropping as soon as the tool left. BlasterAnimator now sets a client-local BlasterFlourish attribute; Presentation lifts the gun arm to the full hold (Carry.Flourish, eased at FlourishRate 20) for the draw and through the holster, then eases back to the run swing. Actions keep their own arm weights.
- **Follow-up (owner):** still too subtle while running; holster cut to nothing. Cause read: third-person camera sits behind/above and the low hip flourish is occluded and edge-on. Flip toss now has moving variants (RunDraw/RunHolster, blended by speed to 14 studs/s): arm swings up and out to shoulder height, toss rises ~1 stud. Holster slides the gun onto the lower back (diagonal sling, Motion.Mount) where a visual copy stays until the next draw, which lifts it from there (Unstow 0.12 s). No fade-outs remain. Studio look unverified by agent (MCP not connected).
- **Follow-up (owner, after market check):** back sling rejected. Holster is now a setting (K): Hip hangs a scaled copy muzzle-down beside the upper thigh, in the gap the R6 arm (lowest corner 0.08 below the torso) and spread leg (within the torso's width) never enter, so running never passes a hand through it; Vanish shrinks it to 0.3 and fades it into the same spot. Draws grow the copy back into the hand before the real gun shows. Owner: arms must be neither tucked in nor flared; the Flip toss run variant now raises the arm forward with roll at most 10 degrees, the stow stage releases the arm to its own pose, and the Gunslinger hold arm went from yaw 0.14/roll -0.08 (across the body) to 0.04/0.02. Studio look unverified by agent.
- **Follow-up (owner):** after the first holster the blaster vanished from the hotbar and could not be re-equipped (K then removed the hip copy); Studio log shows no script errors and one draw/holster only. Cause not yet found (MCP not connected). Hip copy moved under the camera with its cloned Handle renamed; a [BlasterTrack] diagnostic now warns if the local blaster leaves the backpack/character or is destroyed. Hip copy also sat at the knee: now a level belt-holster (muzzle back, 10 degree rake) just under the torso, about 0.7 scale.
- **Follow-up (owner):** hotbar loss fixed: with the hip copy under the camera and its handle renamed, the next session's log shows eight draw/holster cycles and no [BlasterTrack] warnings (a stripped tool clone with a part named Handle in the workspace was the trigger). Hip copy read as reversed, too small and still on the leg: now muzzle forward, 8 degree rake, up to 0.9 scale, its top flush with where the leg meets the torso (the highest clear of the hanging/swinging R6 arm).
- **Follow-up (owner, reference photos of hip holsters):** holster is now the classic shape: muzzle down canted 15 degrees forward, grip up and back, side out, 0.65 scale, its top 0.4 above the leg joint. It sits just behind the resting R6 arm and outside the leg (clear at rest; a running backswing passes it, accepted as 'not interfering initially'). In Hip mode the hand reaches back to the grip (shoulder -22 pitch) as a draw starts and as a holster stows; Vanish keeps the arm's own motion.
- **Follow-up (owner screenshot):** holster tucked behind the arm read as floating and the -22 degree reach pulled the arm back. Now centred on the hip (0.1 behind centre), flush to the leg's outer face, top 0.05 over the leg joint (grip tip may touch the arm, owner-accepted); reach softened to -6 pitch.
- **Follow-up (owner):** holstered gun shrank visibly at 0.65; now 0.95.
- **Follow-up (owner):** holster trailed the body when running/jumping: the anchored copy was positioned in the render step, a physics step behind. Its parts are now massless, unanchored and welded to the torso (weld C0s updated per frame; welds disabled during Model:ScaleTo so it cannot drag the character). Raised to 0.3 over the leg joint.
- **Follow-up (owner):** welding the copy to the torso made the blaster impossible to re-equip again (no [BlasterTrack] warning: the tool stayed in the backpack), and a torso mount looked left behind when the right leg swung forward. Welds removed: the copy is anchored again and re-placed in PostSimulation (after animation/physics) from the part it follows - the right leg when holstered, the hand during flourishes. Mount is now leg-relative, top 0.45 above the hip joint.
- **Follow-up (owner):** hip holster approved (screenshots, 2026-10-31). Held poses read goofy/basic and running felt restricted: a light pistol should leave the arms free. Carry weights for run/sprint/air/actions are now 0 (hold fades out by 10 studs/s; follow-through spring scales with the hold), and a new default Relaxed hold (arm hanging slightly forward, barrel down and ahead) heads the G order; draw/holster flourishes still lift the arm.
- **Follow-up (owner):** Relaxed kept as the only hold (others and the G key removed). Spamming equip left the arm stuck back: the shoulder layer re-read the live C0 as its base, so one missed restore baked an offset in. Each shoulder's rest C0 is now captured once and always restored exactly.
- **Follow-up (owner):** arm-stuck-back after equip spam persisted after the rest-C0 change, with no script errors in the log. Added an idle safety reset of both shoulders to rest and a [BlasterArm] diagnostic (idle, holstered, still, arm >20 degrees off the torso: reports C0 vs R6 rest and Transform) to identify the layer. Unresolved pending the owner's reproduction.
- **Cause found (owner repro + [BlasterArm] log):** shoulder C0 was exactly at rest; the ~34 degree tilt was in Presentation's Transform. The base pose can be a clip's reused sample table (Clips.sample refreshes only that clip's joints, never clears) and the hold/spring layers edited it in place, so the spring's per-frame shoulder multiply accumulated after equip spam. Presentation now layers onto a per-frame copy (scratch 28). Diagnostics kept until the owner confirms.
- **Root cause (detailed [BlasterArm] log):** Presentation's own shoulder output was a normal idle pose but the joint's Transform was ~36 degrees off: Presentation rescans 0.1 s after any part is added (equipping) and re-read each joint's live C0 to build its Transform conversion frames, and the blaster draw layer tilts the shoulder C0 mid-flourish, so a rescan landing then baked a timing-dependent tilt in (owner: stuck angle varied forward/back with click timing). Joint frames are now read once per joint and reused.
- **Follow-up (owner):** arm fix confirmed. Flip pace varied with click timing (the 1.6x back-to-back speed-up); removed so every flourish plays at authored speed, interrupts still blend. Diagnostics ([BlasterTrack], [BlasterArm], Presentation.inspect) and the idle shoulder safety reset removed.
- **Follow-up (owner):** flourishes a tad faster: Motion.Speed 1.12 scales the whole timeline.

## 2026-10-31 - Slug shooting and temporary range

- **Confirmed:** owner brief for shooting (tap/charge, Floppy 5 damage vs 100 HP with splat and no knockback, cooldown-only reload with a quick hop-back, always-transform rule for later slugs, no failed transforms); the range must be labelled temporary; the current map is a placeholder.
- **Implemented/verified offline:** `experiments/combat` and the temporary range; `verify_combat.py` passes (formatting, lint, strict types, builds). [Design record](combat.md). **Unresolved:** Studio playtest and the in-place self-test results.
- **Follow-up (owner):** Rivals-style first person by scrolling, Settings (FOV, holster mode), and a grounded first-person feel (camera follows the animated head, legs visible, viewmodel driven by the body's motion). See [combat](combat.md#first-person-and-settings-2026-10-31). Offline checks pass; Studio feel unverified.
- **Follow-up (owner):** one-handed first-person pistol; first-person flips turn the view with the body, wall runs roll 10 degrees away from the wall, slides lean; legs hidden in air actions. [Record](combat.md#actions-in-first-person-2026-10-31).
- **Follow-up (owner):** first-person flip/slide view compounding fixed (camera-script feedback); running left arm and swinging gun arm in first person; legs fade only near the eye; gun hand stays on the gun on gun-side wall runs. [Record](combat.md#action-view-fix-running-arms-and-gun-side-wall-runs-2026-10-31).
- **Handoff (owner, 2026-10-31):** flips in first person still feel choppy (crosshair flies, hard to aim); first-person arms look elongated at any FOV and must match third-person R6 arms. Slides fine, wall run almost perfect. Not fixed; next agent continues from combat.md "Open issues".

## 2026-10-31 - First-person flip aim and arm proportions

- **Confirmed:** owner moved the movement/combat work to Codex, requested the temporary target range remain the test area, and reiterated close/reopen Studio after changes.
- **Implemented/verified offline:** removed animated head rotation from first-person flip view; fade head translation during flips and filter entry/recovery. Viewmodel arms use actual character limb sizes (R6 fallback 1 x 2 x 1), uniform FOV scaling and natural free-arm amplitude. Respawn clears camera blend state. Full `python tools/verify_combat.py` passes. [Details](combat.md#flip-aim-and-r6-arm-proportions-follow-up-2026-10-31).
- **Unresolved:** Studio runtime/aim/visual approval; no Studio control tools available in this session. Test at FOV 60/72/110, all flip directions, flip interruption, fire/charge, equip/holster and respawn.

- **Follow-up, confirmed:** owner found the arms too blocky/inward, shoulders narrow and gun arm stubby; requested broad shoulders, straight parallel arms, alternating swings and a gun extending from a full-length hand.
- **Implemented/verified offline:** viewmodel shoulders at +/-1.25 studs, arm width/depth 72% with full character length, pitch-only opposing running swings driven by the real left arm, and gun mounted at the right arm endpoint. `verify_combat.py` passes. **Unresolved:** owner visual verdict and Studio runtime checks. [Details](combat.md#broad-shoulders-parallel-arms-and-full-gun-arm-reach-2026-10-31).

- **Follow-up, confirmed:** owner rejected that variant as narrowed robotic paddles, supplied first/third-person screenshots, and requested the actual relaxed idle and fluid third-person running animation.
- **Implemented/verified offline:** replaced the duplicate arm/gun rig with visibility of the real character limbs and held blaster. Shared Presentation/BlasterAnimator now own all poses in both views; muzzle reads real gun geometry, limbs fade only near the eye. Removed separate recoil/charge motion calls. Stable flip view retained. Full `verify_combat.py` passes. **Unresolved:** owner feel/visual verdict and Studio runtime checks. [Current details](combat.md#shared-real-body-idle-and-running-presentation-2026-10-31-current), [ADR 0012](decisions/0012-first-person-body-presentation.md).

- **Follow-up, confirmed:** owner said the animation direction is improving; requested wider first-person shoulders, straight fluid run/sprint swing, thinner arms and 15-20% extra length (screenshot 181046).
- **Implemented/verified offline:** visual copies follow the real arm poses with +0.35 studs per shoulder, 0.76 thickness and 1.18 length multipliers. Running blends out lateral rotation/drift and retains each arm's animated pitch; idle/actions retain full rotations. Gun maps to the extended right hand, including bone animation/visibility, with a matching muzzle. Full `verify_combat.py` and a 361-angle numerical attachment/lane check pass. **Unresolved:** actual Studio motion/aim and owner proportions verdict. [Details](combat.md#first-person-proportion-correction-2026-10-31-current).

- **Follow-up, confirmed:** owner says running width is almost perfect, resting shoulders are too wide and running still angles inward slightly. **Implemented/verified offline:** rest shoulder offset 0.08 studs/side, blending to the existing 0.35 running; running shoulder lanes and pitch now use horizontal view facing instead of inheriting torso yaw/bank. Full `verify_combat.py` passes. **Unresolved:** visual verdict and Studio runtime.

- **Follow-up, confirmed:** large shoulder caps still visible in first person at rest/jumping; gun reportedly cannot re-equip after holstering. **Implemented:** crop the proximal 0.65 studs of visual arms, preserving hand reach; query authored draw visibility independently of source hiding; explicit high-priority `1`-key Tool toggle. Full `verify_combat.py` passes. **Verified limited runtime:** native Studio command-bar automation inserted a temporary LocalScript; three first-person equip cycles each recovered 19 visible copied gun parts, 1.71-stud cropped arm length and rig cleanup on exit. [Evidence](evidence/2026-10-31-first-person-equip.json). **Unresolved:** physical key input, precise original failure cause and owner visual verdict.

- **Follow-up, confirmed:** owner requested shoulders slightly closer together. **Implemented/verified offline:** moved both first-person shoulders inward 0.10 studs (rest -0.02, run +0.25 offset); full `verify_combat.py` passes. **Unresolved:** owner spacing verdict.

- **Follow-up, confirmed:** first-person run/flip/transitions feel bumpier/rigid compared with third person; wall-kick appears to phase out of first person; shoulder tops still too bulky, with spacing no longer the requested fix.
- **Implemented/verified offline:** latched first-person mode/native LockFirstPerson; quieter damped head follow with action rebasing; short view-space arm smoothing and continuity across tool rebuilds; narrower rounded upper arm sections while retaining spacing/hand reach. Full `verify_combat.py` passes.
- **Verified limited Studio:** additional vertical offset range run 0.300 to 0.064, flip 0.639 to 0.117, wall-run/kick 0.791 to 0.099 studs. Serialized regression passed ten forced camera-distance excursions, visible re-equip x3 and mode/rig cleanup. Both movement captures ran near 15 FPS; actual movement feel/high-FPS, shoulder approval and input/aim/multiplayer remain unresolved. [Full evidence and test limits](evidence/2026-10-31-first-person-smoothing.json).

- **Follow-up, confirmed:** owner says smoothness is much better; wants an ever-so-slight running shake and rejects rounded shoulders, requesting smaller square geometry. **Implemented/verified offline:** removed sphere/proximal sections; restored one square block per arm at 0.64 width/depth (previous 0.76), preserving reach/spacing/smoothing; smooth vertical gait pulse amplitude 0.006 studs. Full `verify_combat.py` passes. **Unresolved:** owner's shape/pulse verdict.

- **Follow-up, confirmed:** owner calls first person basically perfect but shake is imperceptible; asks for a more obvious shake first, then flips later. **Implemented/verified offline:** RunBounce 0.006 to 0.018 studs only; full `verify_combat.py` passes. **Unresolved:** owner amplitude verdict; flip work deferred.

- **Follow-up, confirmed:** owner wants flips to feel more rotational without screen rotation (currently feels like a double jump with visible legs), and asks to shorten first-person arms 9%.
- **Implemented/verified offline:** shared FirstPersonFlip envelope gives visible hand drive/tuck/release and a small positional camera cue timed to the original flip; aiming reduces gun-arm cue. Arm length and crop x0.91, matching gun reach; third-person clips/physics untouched. Full `verify_combat.py` passes.
- **Verified limited Studio:** all eight flips over 337 sampled frames; camera look dot >=0.99999994, cue magnitude <=0.073994 studs, hand/gun gap <=0.140009 studs, visible arm length 1.5561. [Evidence](evidence/2026-10-31-first-person-flip-cue.json). **Unresolved:** owner feel/length approval, aim/fire, wall/mantle interruption, physical input and networking.

- **Follow-up, confirmed:** tap/held shots sometimes disappear during flips. **Verified cause in Studio:** firing messages precede physics replication; original batch rejected five of eight origins although local muzzle distance was <4.4 studs. Server root/torso traces both measured about 7-10 studs, so the initial torso-motion hypothesis was insufficient.
- **Implemented/verified offline:** same six-stud root-relative bound with up to 0.25-second replication wait, reserved/rollback cooldown and original-time substepped flight catchup; NaN rejection; Studio-only press/release/ack inspection. Full `verify_combat.py` passes.
- **Verified limited runtime:** all eight tap/full-charge flip cases accepted; far origin, pending cooldown, NaN and recovery checks pass. Controlled delayed-validation fixture registered an early five-damage hit (target 100 to 95). [Evidence](evidence/2026-10-31-mid-flip-shooting.json), [ADR 0013](decisions/0013-combat-origin-replication-grace.md). **Unresolved:** physical input, imposed latency/loss, occlusion and multiplayer/load; mid-grace holster preserved by code, not separately exercised.

- **Follow-up, confirmed:** first-person arm swing was too filtered; owner approved the 90/s running follow but requested slightly narrower shoulders, more leg/footfall feel and more natural idle placement. Two forward idle passes were rejected; the following +0.18 shoulder retreat was too far back. Latest owner request: running midpoint closer to earlier placement, only a small idle forward nudge. Owner suggested 10-15% longer arms; applied 12%.
- **Implemented/verified offline:** run follow 90/s, source cadence preserved; camera bounce 0.03 studs synchronized to Presentation's actual gait phase/weight; lateral offsets reduced 0.06/side. Latest shoulder depth run -0.50, idle -0.05 in view space, idle carry 18 degrees; current visible arm length 1.742832 studs, gun reach follows. Full `verify_combat.py` passes.
- **Verified staged Studio:** matched ~60 FPS source-pitch RMS 26.12 to 3.75 degrees; initial framing accepted idle tap, run tap/charge and mid-flip shot; later stride phase mismatch count zero and hand/gun gap ~0.14 studs. [Stage measurements and rejected framing](evidence/2026-10-31-arm-cadence-framing.json). **Unresolved:** latest midpoint/idle/footfall feel verdict; no new multiplayer/latency evidence.

- **Confirmed, 2026-10-31:** owner requested player-feedback research and three playable first-person flip cameras, preserving the existing movement system and leaving the winner open. Reddit, Steam reviews/discussions and developer interviews show mixed comfort/immersion/aiming preferences; these are qualitative anecdotes, not a population survey. [Research](research/first-person-acrobatics.md).
- **Implemented/verified offline:** target-range-only Anchor/Spot/Ride picker, J cycle/K steady return, queued mid-flip changes, post-camera transform/FOV undo before input. Owner rejected generic arm cues and the larger substitute key trajectories; Anchor/Spot now reframe their actual variant's source shoulder choreography. Existing clips, physics, locomotion, Ride and foundation are preserved. Full combat checks and development probe lint/strict checks pass. [ADR 0014](decisions/0014-acrobatic-camera-comparison.md).
- **Verified staged Studio:** initial 24 directional tap/held shots accepted; look/root orientation, hand/gun contact and lifecycle checks passed. Three injected-look cases preserved 6.875-degree input; Spot leveled early; no accumulated FOV. Teleported wall fixtures produced local continuity but had geometry/correction artifacts. A separate walking approach passed WallRun/WallHop in all three modes with zero server rejections/corrections and no missing visual rig frames. **Unresolved:** final source-following arm runtime pass, owner visual/comfort verdict, physical input/device and multiplayer/latency evidence. [Measurements and fixture limits](evidence/2026-10-31-flip-camera-comparison.json).
- **Verified final source-arm follow-up:** 16/16 directional tap/held shots accepted for Anchor/Spot, unchanged look/upright physics root, gun/hand gap <=0.140022 studs, muzzle <4.82 studs and no missing rig frames. Final lifecycle-only pass covered queue, steady return, view exit and respawn/one panel. Background Studio ran ~15 FPS; initial camera comparison was ~60 FPS. Development probes were corrected to wait for actual render frames and honor the existing three-second respawn cooldown; gameplay settings were preserved. **Unresolved:** owner source-arm appearance/feel, competitive tracking/comfort, physical input/devices and multiplayer. Evidence above records failed fixture attempts separately.


- **Confirmed owner decision, 2026-10-31:** all first-person work from this chat is accepted in appearance/feel except the running look. Spot (the second/hybrid mode, what the owner calls the midpoint system) is now the requested base; Anchor/Ride remain Settings alternatives. Earlier no-winner/pending-look notes are superseded; technical device/network limits remain.
- **Implemented/verified offline:** added contextual wording interpretations and recurring-regression diagnoses/fixes to combat.md and linked them from index/development/movement/ADRs. Inferred meanings are explicitly scoped to this conversation. Settings now owns three camera choices, Spot is the Config default, selection is session-only and retained across respawn; temporary range picker/J/K are removed. Full combat checks pass; focused Studio check pending. Running is preserved and remains the next unresolved visual task.

- **Verified limited Studio, Spot Settings follow-up:** startup selected Spot without the old range flag. Native Windows mouse clicks selected Ride/Anchor/Spot/Ride while preserving third person. Ride preference and the same single Settings GUI survived respawn; old overlay absent. A Spot flip accepted a tap shot; Anchor selection queued during it, then Spot was restored and highlighted. Broader devices/networking remain unverified. [Evidence](evidence/2026-10-31-spot-default-settings.json). Target range is rebuilt/reopened after testing.


- **Confirmed running follow-up, 2026-10-31:** owner describes uniform up/down baby-like swinging versus angled, robust third-person momentum; requests only a slight forward shoulder/lean increase. Interpreted contextually as restoring spatial articulation/chest participation, not making a new larger oscillator or adding more damping.
- **Implemented/verified:** first-person retarget now retains bounded source flare/chest motion and its existing pitch timing; forward run base -0.62 (0.12 stud change), source chest depth <=0.11 and lift <=0.05, target outward angle 1-14 degrees, axial twist <=6 degrees. Idle geometry/placement, camera pulse, proportions and flip profiles remain unchanged. Full combat checks pass. Native Studio ~60 FPS run/sprint showed variable outward articulation/source-timed pitch and no missing rig frames; four idle/run tap/run charge/flip shot cases accepted. [Evidence/fixture limits](evidence/2026-10-31-running-volume.json). **Unresolved:** owner running appearance/feel verdict; do not mark first-person movement fully accepted yet. Root cause lesson: zeroing all lateral/chest motion fixed inward pointing but overcorrected into a planar paddle.


- **Confirmed follow-up, 2026-10-31:** owner asks for exactly 10% shorter arms only in first person, and stronger third-person-like forward running posture. Moving virtual shoulders alone was insufficient; the latest interpretation is a source-driven forward/down viewpoint, with level aim.
- **Implemented/verified offline and limited Studio:** multiply first-person length/crop by 0.9; visible R6 copies are 1.5685488 studs, source arms stay 2. Running eye offset follows actual chest pitch/velocity (up to 0.36 forward/0.12 down, rate 10; 35% while pointing), clears on view exit and is reset for death/character changes. Actual ~60 FPS check measured copy size 1.5685488, unchanged source size 2, mean forward run offset ~0.322 studs, zero induced look pitch and rest/third-person cleanup. Four idle/run tap, run charge and Spot flip shots accepted. [Evidence](evidence/2026-10-31-short-arms-run-lean.json). **Unresolved:** owner lean/length appearance verdict; death reset/device/multiplayer were not separately tested here. Source run rhythm/flaring, arm width, physics and Spot default are preserved.


- **Running cadence request, 2026-10-31:** owner again asks for less smooth/more robust hands like third person; calls “glitchy” the closest word. Contextual interpretation is crisper stroke beats/holds/reversals, not literal stutter, random shake or lower FPS. Still awaiting owner confirmation.
- **Implemented/verified:** remove additional steady free-run pose rounding after the entry blend; apply a bounded four-degree source-angle accent around the Run midpoint (20 degrees). No new clock; pointing/idle/actions retain their filters, shortened length and forward/down lean remain. Full combat checks pass. Native ~60 FPS samples show rendered/source angular peaks ~1745/1946 before and ~2247/1993 deg/s after, zero induced camera pitch and no missing visual rig; arm copies stay 1.5685488 studs and source arms 2. Idle/run tap, run charge and flip tap accepted. These are sampled traces, not proof of better subjective feel. [Evidence](evidence/2026-10-31-running-stroke-accent.json). Owner running approval remains open; pre-change source is checkpointed under ignored build storage.

## 2026-11-02 - PvP UI build

- Owner chose version 1 of the refined comic direction, with version 2's softer slug bar, slightly smaller slugs in slots and the neutral Moonlight accent, because it suits every slug's colours. Four slots, 13 slugs in total, sprint Toggle by default.
- Owner dislikes spinning slot icons (wants small animations and a smile) and the crosshair drawing under menus (fixed with a higher display order).
- Roblox exposes no usable side mouse buttons; the F13/F14 route is untested. Hover cannot show health in play because the cursor is locked. Status and limits: [status](status.md).

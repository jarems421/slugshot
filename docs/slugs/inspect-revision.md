# Inspect pose revision — 2026-11-02

**Confirmed:** owner rejected the first inspect as “horrible”: the gun was positioned incorrectly in both hands/views. First requested a readable side inspection based on pistol games, then clarified that the barrel should point upward in line with the raised arm, with the whole arm/gun angled diagonally back toward the holder. Floppy should hop, look at the holder, turn and wiggle before a smooth lower. This clarification governs the revision.

## Implemented

- A 5.8-second sequence: eased raise (0–0.85), hop/anticipation (0.82–1.65), look/smile, turn (2.65–3.3), wiggle (3.3–4.25), settle (4.15–4.75), lower (4.85–5.65). Joins ease to rest. Firing, aiming, switching and menus retain their existing interruptions.
- The barrel points up and slightly toward the camera. The first-person arm is solved through the actual grip joint, and that same rendered arm drives the gun. Removed the separate final gun placement that could separate it from the hand. Added a small inspect-only grip inset so the pistol is seated inside the block hand.
- The palm pivot and Tool.Grip remain fixed. Wrist rotation takes place at that pivot. The third-person shoulder remains attached to the torso; its raised diagonal pose accounts for the single rigid R6 arm.
- The raised barrel already stands Floppy nearly upright. His whole loaded model hops and turns through its existing cosmetic welds; face/head motion stays with the current bone drivers. A coherent basis derived from the actual eye/head facing avoids reversing the visible side. No mesh, weights, materials, Blender source or uploaded asset was changed.
- Loaded attachment rest frames are cached and restored after inspect/holster so a moved pose cannot become the next equip's baseline.

## Review method and failed attempts

The rejected baseline was preserved at commit `078c191` and in `build/inspect-v2/checkpoint`; its contact sheet is `build/inspect-v2/rejected-sheet.png`. Early revision sheets exposed an arm entering from above, an R6 pose lifted over the head, and Floppy hidden behind the gun's panels. These were rejected internally, not treated as successful because assertions passed. The owner's later upward-barrel clarification resolved the pose direction and gives Floppy a clearer standing silhouette.

Reference inspection was read-only: [USP-S side-inspect screenshot in an EsportFire recap](https://esportfire.com/article/market-recap-csgo-01082022) and [Riot's weapon-animation design discussion](https://playvalorant.com/en-us/news/dev/the-craft-and-fantasy-of-valorant-weapon-skins/). No game asset or animation was downloaded for reuse. The linked YouTube showcase could not be opened; it was not claimed as watched. The final orientation follows the owner's explicit upward pose rather than copying the reference screenshot.

`python tools/build_loadout_check.py --inspect-review` maps a disposable frozen-beat reviewer. It samples eleven times in each view and waits for a screenshot acknowledgement, preventing log polling from capturing a later pose. It checks the unchanged grip/palm pivot, first-person barrel/arm alignment (dot product >0.97 during the held pose), and actual head travel relative to the handle. This replaces the earlier weak test that only checked a non-identity bone value.

Screenshots/contact sheets and sanitized results are linked from [the revision evidence](../evidence/2026-11-02-inspect-revision.json). Normal projects do not map either review fixture. The ordinary loadout check still exercises actual server requests, wheel/keys, cooldowns, interruptions, rebinds, respawn and holster cleanup.

**Unresolved:** owner art/feel approval, multiplayer observer/latency coverage, and non-desktop devices. These checks do not establish that the owner likes the pose or the animation timing.

**Implemented/verified:** final frozen-beat review passes all 22 captures, fixed palm/Tool.Grip and held-pose barrel/arm alignment assertions. Actual head movement relative to the handle is about 0.244 studs. The ordinary native loadout test passes, including holstered attachment restoration; combat/foundation/movement and creature offline checks pass. The contact sheet was visually reviewed; its one difference warning crosses the first/third-person camera cut and is not an animation continuity claim. Final captures: `build/inspect-v3/delivery`, contact sheet: `build/inspect-v3/contact-sheet.png`, functional check: `build/inspect-v3/regression`. The existing art baseline is preserved.

## Final lean and spin follow-up (2026-11-02)

**Confirmed:** owner requested only a slightly stronger left lean and a slow spin while raising, then corrected the lowering request to include a spin on the down-flick too. Floppy's reaction stays as agreed.

**Implemented:** held barrel lean is about 9 degrees farther left. A forward 360-degree twirl spans the 0.85-second raise; the reverse 360-degree twirl spans the 0.8-second lower. Both ease into the seated held/rest poses. The flourish uses the accepted draw/holster trigger-guard pivot, with clearance from the forearm and a small first-person carry lift. It is applied after pose interpolation, using an unwrapped angle so quaternion interpolation cannot erase or reverse half the turn. The arm target removes only the flourish; the visible gun retains it, allowing the arm to carry the raise while the gun spins. Tool.Grip/C1 remains unchanged. The temporary toss offsets clear back to zero before the reaction and after lowering.

Verification and captures: [lean/spin evidence](../evidence/2026-11-02-inspect-spins.json), `build/inspect-v4`. Thirty frozen poses cover both transition spins and both views; the native loadout regression and combat/foundation/movement checks remain the technical gates. **Unresolved:** owner verdict on the final timing/feel; multi-client and device coverage.

**Visual refinement:** the transition twirl rolls about the barrel through the trigger-guard pivot, keeping the muzzle clear of the forearm. The earlier end-over-end trial swept the muzzle through the arm and was rejected before delivery.

**Implemented/verified:** 30 final frozen poses pass in Studio, including full-turn/end-state assertions and alignment through the unchanged reaction. The contact sheet was reviewed (`build/inspect-v4/contact-sheet.png`); spin and camera-cut differences are intentional. Native loadout regression passes; combat/foundation/movement checks pass, with final visual-axis/clearance refinement additionally checked by native review, formatting and lint. Final captures are under `build/inspect-v4/twirl`. Owner timing/feel approval remains open.

## Toss, catch and contained spring turn (2026-11-02, superseded for the gun by the section below)

**Confirmed:** owner corrected "flip" to "flip the gun up and then you catch it", followed by an exterior wrist twist that shows the inside-facing side. The barrel-roll interpretation above is rejected. "The slime shouldn't come out" explicitly rejects the previous lateral visibility offset. The turn should spring up, and the bum shake should be fluid without added jiggles.

**Implemented:** a 6.8-second sequence. Toss/end-over-end flip runs 0.18-0.82; catch dip finishes at 0.98; a separate 65-degree outward wrist turn reveals the chamber at 0.98-1.46. The held left lean remains. A wider lateral/upward arc clears the fist, and first-person carry depth keeps the early toss in frame. The reverse flip runs during lowering at 5.9-6.65, retaining the owner's preceding request. The native grip is unchanged at catch and hold.

Floppy stays centred on the chamber; the old sideways escape and rigid whole-model wiggle are removed. Loaded size now reserves a circular turn envelope and articulation margin. An axial hop is capped by available chamber length. He looks up and smiles, compresses at 2.62-2.86, springs upward and turns in flight at 2.86-3.36, cushions the landing, then sweeps his hips at 3.55-4.7 with a small lateral weight shift. Upper body/head counter the hips; they no longer rotate as one stiff block. Torso/head translations imply compression and extension without unsupported bone scale. Lids, gaze and smile follow anticipation/takeoff instead of random chatter; no new jelly oscillation is added.

**Review findings:** the first small toss arc still brought the barrel near the forearm; the wider arc replaces it. Early first-person framing clipped the muzzle, so carry depth was adjusted. The Scriptable review camera retained Roblox's first-person torso/head fade; the disposable reviewer now clears that cached fade when switching views. A cold native launch also exposed Handle/weld replication arriving after Floppy: setup now waits/retries before permanently registering the loaded animation driver. A close-up recording showed hip yaw alone was too subtle on the rounded back; a coordinated lateral pelvis sweep with upper-body countershift makes the gesture readable. These are runtime/capture fixes, not Blender source or art changes. Baseline `dd5887a` and all earlier failed sheets remain preserved.

Verification and limits are recorded in [catch/containment evidence](../evidence/2026-11-02-inspect-catch.json). Conservative envelope assertions are not a skinned-vertex collision proof. Owner motion/feel approval and multiplayer/device coverage remain **Unresolved**; code checks and screenshots do not grant art approval.

**Implemented/verified:** combat/foundation/movement and creature offline checks pass. Final Studio review has 36 frozen poses, 58/61 real-time captured frames in first/third person, unchanged native grip and held barrel/arm alignment, 0.042-stud head travel, and a 0.008-stud independent hip sweep. Conservative chamber-envelope and catch-before-reveal assertions pass. Final ordinary loadout regression passes real V/2/R/Q and wheel messages, interruption/completion, cooldowns, server rejection, respawn and holster restoration; shared flight regressions pass. Contact and close-up reaction sheets were visually reviewed. The contact report's sole difference warning crosses the camera cut. Captures: `build/inspect-v5/hip-sweep`; sheets: `build/inspect-v5/final-contact-sheet.png` and `final-reaction-sheet.png`; regression: `build/inspect-v5/final-regression`. Fresh normal place: `build/SlugshotInspectCatch.rbxlx`. Owner art/feel verdict remains unresolved.

## Quick backflip, arm-swing catch and plain drop (2026-11-02, gun current)

**Confirmed:** owner called the previous gun motion poor. They want a throw into a small backward flip, a small animated arm swing to catch it, then an outward tilt that shows the slug inside. Putting away is a normal, quicker drop with no second flip. The flip must be quicker and more dramatic, the hand grip right and third person must not look weird. Slug acting is deferred until this part is right.

**Implemented on `feature/inspect-polish`:** 4.52-second sequence. Wind-up 0-0.3; thrown backflip 0.3-0.72 (0.42 s, was 0.64), with the hand following through and rising to meet the gun; catch dip and wrist rock 0.72-1.22; outward tilt 0.8-1.26 with a small overshoot; lower 4.1-4.52 (0.42 s, was 0.75) with no flip. The flip turns the barrel back toward the holder. Motion uses keyed Hermite tracks instead of symmetric pulses. Floppy's existing reaction moved one second earlier and is otherwise unchanged.

First and third person now differ where each needs it. First person enters and leaves below the screen, and blends poses there, because blending directly swept the arm across the view and made the gun rise before lowering. Third person keeps a shoulder blend, pitches the rigid R6 arm through the same hand curve, and throws 1.6x higher (`Inspect.ThirdToss`) to read at the 10-stud camera. The first-person arm follow uses the fast rate during inspect so it cannot blur the flick. Idle fidgets are blocked and cancelled during inspect; one was tilting the head mid-flip.

**Review findings:** an unfinished wind-up tilt caused a 23-degree pop at release (caught by the new release assertion). `loadout_check.ps1` could wait out its timeout when its window was minimized; it now restores the window and stops after 90 s if Play has not started.

**Research limits:** no studio breakdown of inspect toss timing was found. Used: [Riot on first- and third-person weapon constraints](https://playvalorant.com/en-us/news/dev/the-craft-and-fantasy-of-valorant-weapon-skins/), which also says only the model silhouette reads to other players; a [Polycount critique on varying timing](https://polycount.com/discussion/comment/2540007) and one [on the hand reaching for a falling gun](https://polycount.com/discussion/comment/2657694); and a [community note that Counter-Strike flips sit at the end of the inspect](https://steamcommunity.com/app/730/discussions/0/490123832544873815?l=italian), which is anecdotal. The timing here is an owner-directed judgement, not an industry figure. No game animation was copied.

**Implemented/verified:** 54 frozen poses across three camera positions pass the inspect review (`build/inspect-v6/r4`, sheet `r4-sheet.jpg`), including unchanged native grip, release and catch at zero offset, no flip or toss on the lower, and barrel/arm alignment while held. Native loadout regression, `verify_movement` and `verify_combat` pass. The review's "front" camera actually sees the character's back, because the character turns with the camera, so the front of the pose is unchecked. Playable place: `build/SlugshotInspectFlip.rbxlx`.

**Unresolved:** owner feel verdict; real-time motion was recorded but only frozen poses were reviewed; multi-client/latency and non-desktop devices.

### Moving hold (2026-11-02)

**Confirmed:** owner said the upright hold "looks too frozen" and asked for a slight tilt, while keeping the gun relatively in place because the slug animation is the star.

**Implemented/verified:** a moving hold across 1.15-4.2 s: wrist roll (5 degrees over 2.7 s, 1.5 degrees over 1.3 s), pitch (2.5 degrees over 3.4 s), lean (2 degrees over 2.1 s) and 0.035-stud lift over 3.1 s. Unrelated periods avoid a visible loop. It fades out through the start of the drop. Both views share it: in third person the wrist turns at the palm and the arm takes the lift. The review now asserts the hold turns more than 3 and under 12 degrees and drifts under 0.12 studs; measured 7.1 degrees and 0.038 studs. Inspect review (`build/inspect-v6/r5`, sheet `r5-hold.jpg`), native loadout regression, `verify_combat` and `verify_movement` pass.

**Research limits:** [the moving hold is an established animation principle](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation), with [more on why frozen holds fail](https://animationmentor.com/blog/why-all-animators-need-to-master-the-moving-hold). No source described how specific games animate an inspect's hold, so these amplitudes are a judgement.

**Unresolved:** owner verdict on amount and speed. Real-time capture reached about 4 frames per second, so smoothness was not reviewed.

**Confirmed, later 2026-11-02:** owner called the gun motion and moving hold "perfect". Only the hold's end and the lower moved later in time, to fit the slug; the gun's motion is otherwise unchanged.

## Clear canister and spring-driven slug act (2026-11-02, act rejected; canister and idle stay)

**Confirmed:** the canister's "black background" must be its clear form. Floppy should look at the holder, make a "springy hop around", then do a bum shake that "looks like it's shaking a bum, not just wiggling its body side to side", then slowly transition back. In general he "looks like it's just a frozen frame" in the chamber and should be "animated, but not really animated". Stage transitions must be smooth; the old act was "too stiff".

**Causes:** (1) `CanisterTeal_Ink` is an inverted hull, so through clear glass you see its inside faces as a solid black wall. Hiding each blaster group in turn isolated it, and it also showed in the normal carry view. (2) Idle motion is authored in source units and scales with the slug, so at 0.076 scale it moved about 0.001 studs. (3) Hop height was capped at 0.035 studs in a chamber with far more room. (4) The rig's jelly bones were unused here, and hips and body shared one sweep.

**Implemented:** the hull is removed in `FloppyBlaster`, so the canister is clear everywhere. A loaded Floppy now runs on springs with SlugIcon's tuning, which the owner previously approved: every state only sets targets, so idle, stages and interruptions flow together. The act runs 6.27 s: look and one slow blink (1.2-2.05), three crouched hops turning 60/120/165 degrees with launch and landing kicks (2.05-3.69), bow and shake (3.72-5.25), slow return while the gun is still up (from 5.25), lower (5.85-6.27). In the shake the lower body swings about the waist with slide, roll, yaw and a double-time pop; the upper body undoes 85% of it; the cheeks push out in turn and drag behind; the head peeks back. Chamber idle adds a slow float (up to 10 degrees of roll) and icon-sized breathing and sway. No Blender source, mesh, weights or upload changed.

**Review findings:** first floor placement sank about a fifth of his height into the chamber's solid end cap, hiding the bum, while the top of a hop reached the upper ring. The visible window is shorter than the canister's bounds, so the lift now runs from on the cap to under the ring (about 0.06 studs). A close-up camera following the gun's axes spun, because the character turns to match the camera; anchoring did not stop it, and a fixed look direction did.

**Implemented/verified:** review passes 60 frozen poses in three views plus a real-time trace: shake 0.065 studs at the base against 0.006 at the head; idle turn 17.6 degrees and head wander 0.018 studs; fastest bone speed 1.58 studs/s with no pops; head and hip bones inside the chamber. Native loadout regression, `verify_combat`, `verify_movement` and `verify_slugs` pass. Real-time close-up frames at about 10 per second were visually reviewed: [contact sheet](../evidence/2026-11-02-inspect-slug-act.jpg), full run in `build/inspect-v7/r4`. Playable place: `build/SlugshotInspectFlip.rbxlx`.

**Research limits:** nothing specific to a bum shake was found. Used general principles: [crouch, stretch and overshooting landing](https://www.animationmentor.com/blog/tutorial-animate-a-jump-and-land/), and [one part leads and the others follow, with loose parts dragging](https://courses.cs.washington.edu/courses/cse457/02sp/lectures/animation-principles.pdf). Amplitudes are a judgement.

**Unresolved:** owner verdict on the act. Containment checks use bone positions plus visual review, not every skinned vertex; other players seeing it, latency and non-desktop devices are untested. Inferno still has no inspect runtime.

## Smile, then the HUD wiggle (2026-11-02, current)

**Confirmed:** owner rejected the hops and bum shake: "the slugs animation is just horrible. I give up on the current animation". They want the flip a bit faster and a shorter inspect, with Floppy looking up and giving a little smile, then the wiggle "it already does in the HUD", with a smooth transition.

**Implemented:** gun flight is 0.32 s, down from 0.42 s; the gun's catch, tilt and hold motion are otherwise unchanged. The inspect is 4.37 s. Floppy turns to the holder and looks up with a small smile, then does SlugIcon's wiggle with its shape and rate (2.3 s at 1.7 beats per second, from 1.7 s), including the whole-body lean about his base. It swells in from the smile and settles before the lower at 3.95 s. Hops, turn, bum shake, peek and cheek motion are removed. The clear canister and the looser chamber idle stay; neither was part of the rejection.

**Implemented/verified:** inspect review passes 51 frozen poses in three views and a real-time trace: 0.061 studs of side-to-side head travel in the wiggle, fastest bone speed 0.34 studs/s with no pops, head and hip bones inside the chamber. Native loadout regression, `verify_combat`, `verify_movement` and `verify_slugs` pass. Real-time close-up frames were reviewed: [contact sheet](../evidence/2026-11-02-inspect-smile-wiggle.jpg). Playable place: `build/SlugshotInspectFlip.rbxlx`.

**Unresolved:** owner verdict; other players seeing it, latency and non-desktop devices. Containment uses bone positions plus visual review, not every skinned vertex.

### Base stuck, body fluid (2026-11-03, superseded below)

**Confirmed:** owner said the wiggle was "too stiff": the slug should be "stuck to the bottom of the barrel", with the body "more fluid" and "just the top bit not the bottom bit".

**Cause:** the port kept the HUD icon's rigid whole-body lean about the base, which suits a loose icon but tilts the whole body and base as one piece. **Implemented:** the wiggle's beat and timing stay, but the lean is replaced by a bend up the spine: lower 3 degrees, upper 8, head 5, each on a spring trailing the joint below, with antennae trailing the head. Chamber float is fully off while upright, and the vertical pump is about half what it was.

**Implemented/verified:** real-time trace shows 0.0000 studs of base drift against 0.044 studs of head travel, fastest bone speed 0.26 studs/s, head and hip bones inside the chamber; the review now fails if the base moves more than 0.003 studs. Inspect review, native loadout regression, `verify_combat`, `verify_movement` and `verify_slugs` pass. Real-time close-up frames were reviewed: [contact sheet](../evidence/2026-11-03-inspect-fluid-wiggle.jpg). **Unresolved:** owner verdict; multi-client/latency and devices. The base check tracks the lower bone's origin, not each skinned vertex; the base rim tilts up to about 3 degrees with that bone.

## First-person mesh fix and smile, wiggle, hop (2026-11-03, current)

**Confirmed:** owner: Floppy "just stays still now in the animation". Wanted: a smile "for a split second", a smooth transition into a soft wiggle with the lower half stuck and the top half animated, antennae not "swinging around all over the place", "a small little jump back into its normal position", then a snug wiggle back into shooting position as the arm lowers.

**Root cause:** `Viewmodel` clones the tool for first person and destroyed every JointInstance, including the rig's Motor6Ds. A skinned mesh without its joint ignores its bones, so bone transforms copied correctly (logged values matched) while the visible mesh never moved. Exaggerated 35-degree transforms changed nothing until the joints were restored. This likely also explains the earlier "frozen frame" complaint. All earlier close-up reviews used the third-person model, so their motion evidence did not apply to first person. **Fix:** recreate the rig's Motor6Ds between copies. First-person idle and face motion are affected too, since they use the same bones.

**Implemented:** 3.77 s inspect. Look and smile by about 1.0; wiggle 1.4-2.8 at 1.4 beats per second (lower 2, upper 11, head 7 degrees, trailing); crouch 2.76, hop home 2.9-3.2 with a low rise; snug wiggle from 3.2 fading by 3.77; lower 3.35-3.77. Antenna swing reduced about 75%. Gun catch, tilt and hold motion unchanged; only the hold is shorter.

**Implemented/verified:** review close-up now uses the first-person copy and asserts its Motor6D exists; base drift 0.0000 studs, wiggle head travel 0.043 studs, fastest bone 1.15 studs/s. Native regression and `verify_combat`, `verify_movement`, `verify_slugs` pass. Frozen frames from all views were reviewed: [contact sheet](../evidence/2026-11-03-inspect-first-person-fix.jpg). **Unresolved:** owner verdict and smoothness at full frame rate (capture is about 6 per second); the snug wiggle is on screen only until the gun leaves view, about 0.4 s; multi-client and devices.

**Confirmed, owner, 2026-11-03:** "this work is perfect". Owner approved this inspect in Studio; multi-client, latency and non-desktop coverage remain untested.

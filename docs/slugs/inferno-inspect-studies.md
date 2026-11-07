# Inferno inspect studies — 2026-11-03

**Confirmed, owner:** preserve Floppy's existing gun inspection movement. Change only Inferno's performance in the canister: look toward the holder with an arrogant smile, blow a little fire toward them while keeping it inside the canister, smile again, then settle back with small hops before the gun lowers. The owner explicitly withdrew the initial angry/gritted-teeth idea. “Burpy” refers to Inferno here, not a new species or rename.

**Confirmed, owner follow-up:** generate several interactive artifact-style versions for review **before adding this to Roblox Studio**. That preview-first gate governed the studies below. The owner subsequently selected Playful Flame and authorized native integration (see the current decision).

## Current revision: livelier Burpy, matched Floppy, no under-eye smear (2026-11-07)

**Confirmed, owner, 2026-11-07:** Burpy's inspect "doesn't look like it's straining enough", the inhale "doesn't look like it's breathing in enough", it is not exaggerated and "doesn't look alive". Floppy looks smaller than Burpy and too small in the inspection, and when he looks up his under-eyes smear like "crying mascara", in the gun and in the HUD. In the training arena Burpy "just stays looking straight".

**Implemented, not yet seen in Studio:** same timing and flame; bigger amounts only. A gathering dip before the inhale; inhale lifts the head 0.075 and the chest 0.080 (was 0.045 each), chin 0.22 rad (was 0.14), wider O, ears perk up 0.13 (was 0.06); belly swell 1.5 times; a slow resting breath outside the big one. The blow pushes forward harder (head pitch -0.14, chest -0.09), squeezes the lids (-0.06), pins the ears back (-0.16) and shudders the head and chest. Breath hop 0.42 (was 0.32). Floppy loads 1.2 times larger, as tall as Burpy (he was 0.21 against 0.27 studs; the old fit allowed for any turn in the glass). Looking up now bends Floppy mostly from the waist (upper 14, head 6 degrees; was 6 and 22), in `FloppyIdle` and `SlugIcon`, the lobby fix of 2026-11-03. The arena failure matched the owner's log: Inferno shots ran Roblox out of EditableMesh memory (teeth on every shot), so Burpy's preparation failed; shots are now skipped (verified in the range). **Unresolved:** a Studio look at all of it, including whether the larger Floppy touches the glass.

**Owner, 2026-11-07, later:** in the game place Burpy was "a red block" in first person; inspecting from third person showed him but "stationary". The owner's log (20:35) still had the budget failure with shots skipped, so something else in the game place uses that memory; not yet found. **Implemented, not yet seen in Studio:** preparation now makes every editable mesh first (`Surface.reserve`) and changes no part until all are held. A full budget leaves Burpy whole, and it tries again every 4 s instead of giving up. Before, the mouth was already swapped when the body failed, and clean-up destroyed the meshes that part was showing. The first-person copy no longer inherits the source's mesh revision, so it always re-applies the edited meshes. The holstered hip copy no longer makes a teeth mesh.

## Current revision: original Floppy restored; Burpy approved

**Confirmed, owner, 2026-11-04:** “the burpie animation is perfect.” The subsequent Floppy under-eye repaint and antenna changes are rejected. Restore the **original design with a flat bottom**, clean original under-eye materials and an enlarged size that does not leak outside the canister. Keep the lower half planted and the original smooth upper-half wiggle.

**Implemented/verified locally:** removed the runtime under-eye repaint and restored the original accepted static face maps. Restored original antenna placement/transforms and upper-body spring strengths. Removed the changing clearance gain that made the wiggle stiff/choppy. Seat the authored flat ground plane on the cap; suppress lower-body sway/flank deformation while standing. Only evaluate the sole for support, rather than running whole-body searches every frame.

The original conservative loaded fit now has a modest **4.5% enlargement**. Larger tests clipped during the original motion and were discarded. The final native trace stays inside the real elliptical glass (radial 0.97682, axial 0.87494); base drift is 0.000003 studs, upper-body motion 0.036257 studs and flat landing error below 0.000001 studs. Native material checks confirm original colour/normal maps and no editable replacement. Burpy source/timing hashes and its gun setup block are unchanged.

**Evidence:** offline combat/creature checks and targeted native restoration checks pass. [Evidence and limits](evidence/2026-11-04-floppy-original-restored.json). Review: `build/SlugshotInspect-FloppyOriginalRestored.rbxlx`; standalone recording: `build/inferno-inspect/revision7/Floppy-original-restored.html`. **Unresolved:** owner's restored-Floppy visual/feel verdict and devices/multiplayer. Earlier Floppy repaint/size-equality claims below are superseded; Burpy remains approved.

<a id="current-revision-matched-size-planted-landing-and-longer-inhale"></a>
## Previous revision: matched size, planted landing and longer inhale

**Confirmed, owner, 2026-11-04:** Floppy looked smaller during inspection, floated after his return hop and had streaky under-eye shading. Inferno should begin acting sooner, take a longer inhale with a wider mouth and clearly expanding belly, then make a small forward-tilted hop as he starts blowing. Preserve the current flame treatment, quick gun motion and overlapping final return.

**Implemented/verified locally:** use one chamber-relative resting height for both species. Actual skin measurements are **0.26526/0.26780 studs**, ratio **0.9905**. Reserve the same clearance for both. Centre Floppy's undeformed silhouette for the current facing and support the evaluated sole through the hop, landing and idle; his upper half still moves. Fit after facial updates and include antenna/jelly deformation. The final full-motion trace stays inside the actual ellipse; landing error is **0.000009 studs**. Retry incomplete loaded skeletons rather than leaving Floppy idle-only.

Floppy's local shared material repairs the under-eye colour/normal texels into a soft tapered crescent. Build a new SurfaceAppearance through the supported runtime API and clone completed material revisions into first person; no plugin-only setters, security changes or asset uploads. Preserve original maps elsewhere and per-instance emission settings.

Inferno begins inhaling at **0.78 s**, with a **0.82 s** rise and a wider mouth transition. Flame begins at **1.90 s**, still earlier than the preceding 2.06 s. A native-skinned belly corrective expands the torso without inflating cheeks or moving the head/sole vertices; measured maximum displacement is **0.028301 studs**. A small forward-leaning hop peaks at **2.15 s** and lands by 2.40 s. The approved return/catch clocks remain 3.95/4.44 s, finishing at 4.67 s.

**Evidence:** offline combat/creature checks and native geometry, material copy, full-motion, landing, running catch, lifecycle and tooth checks pass. [Measurements and limits](evidence/2026-11-04-inhale-size-landing.json). Review place: `build/SlugshotInspect-InhaleAndLanding.rbxlx`; standalone four-tab native preview: `build/inferno-inspect/revision6/Inferno-and-Floppy-inspection.html`. Recordings have lower cadence than live play. **Unresolved:** owner art/feel verdict, devices, published API/memory constraints and multiplayer.

<a id="current-revision-embers-shorter-return-and-planted-floppy"></a>
## Previous revision: embers, shorter return and planted Floppy

**Confirmed, owner, 2026-11-04:** enlarge the flame a little more, add fading embers while blowing, disperse the ending outward and make the inhale/strain clearer without excessive cheek inflation. The hop home should overlap the gun being put down. Floppy's lower body should retain its rounded shape and stay stuck to the chamber floor while only the upper body wiggles. The owner explicitly clarified that the flat surface complaint concerns Floppy's lower body, not the canister platform. The light outline should follow the actual glass surface rather than look inset.

**Implemented:** modestly enlarge the plume again and add ten small animated 3D ember slots to the same editable surface, each born from the flow and fading as it travels. The main release expands tangentially/upward while depth remains bounded; individual ember vertices also stay inside the chamber. Increase torso/head lift and chin raise on inhale, and lid/antenna tension on exhale. No cheek inflation is added.

Inferno begins returning at 3.95 s while the gun starts its ending gesture at 4.12 s. Release/catch occur at 4.20/4.44 s and the inspect finishes at **4.67 s**, down from 6.50 s. Floppy remains 3.90 s. The low catch remains visible and releases into live carry.

Floppy now uses the coherent current main private asset bundle, including matching material maps. Keep its rounded rest mesh and pin the evaluated sole to the inner cap while standing. Lower-body sway is suppressed; upper/head articulation is limited only if needed to fit. The previous dynamic whole-body centring incorrectly moved the foot when the head leaned. Both slugs retain the same 1.10 loaded-size increase. Native body checks use the actual elliptical glass cross-section.

The light frame now follows each glass half-axis independently, with the correct quarter-ellipse Bezier tangent lengths. A small outward clearance prevents the frame appearing embedded. Collar attachment positions and restrained light treatment are retained.

**Implemented/verified locally:** offline suites pass. The geometry/lifecycle review checks all 495 referenced fire/ember vertices. Final full-motion traces fit both species, with a moving upper body and a planted Floppy foot; a targeted regression verifies late-arriving parts cannot expose the unselected species. Hotbar/tooth checks and the running low catch also pass. [Detailed evidence and limits](evidence/2026-11-04-inferno-embers-footing.json). **Unresolved:** owner visual/feel approval and device/observer/multiplayer performance.

**Current review:** `build/SlugshotInfernoInspect-EmbersAndFooting.rbxlx` and `build/inferno-inspect/revision5/Inferno-embers-and-footing-preview.html`. Normal, running, flame and Floppy views are native recordings; close-up cameras are labelled. Checkpoints and rejected material/visibility trials remain in revision5.

<a id="current-revision-breathing-effort-orange-curl-and-low-return-catch"></a>

## Previous revision: breathing effort, orange curl and low return catch

**Confirmed, owner, 2026-11-04:** chamber lights are good. The breath needs a clearer side angle, warmer orange colour, a larger readable curl, lung-led preparation and mild strain rather than whistling or puffed cheeks. The last flame should dissipate rather than drop with the mouth. Replace the slow closing lower with a flip and low catch that returns naturally into idle/running.

**Implemented:** sweep the connected flame tangentially around the inside of the chamber, with a larger upward curl. This uses available cylindrical space without squashing the plume against the nearest wall. Use orange/amber heat and moving pale hot ribbons, with irregular vertex opacity. At the end, stop following the lips; the remaining flame travels, spreads and fades upward within the glass. No sprite, texture upload or physical projectile is introduced.

The inhale lifts and holds the upper body/head before the exhale. Lids narrow and tilt, the head/chest lean gently into the breath, and the O broadens while its pucker reduces. Cheeks are not inflated. Body fit limited the strongest lean; the final forward pitch is slightly softer while retaining the visible lift and facial effort.

The shared gun now makes a second 0.24 s flip. Floppy releases at 3.43 s and catches at 3.67 s; Inferno releases at 6.03 s and catches at 6.27 s. Keep the catch visible low in the screen, contribute part of the live carry pose during the toss, then release the remaining presentation weight over 0.23 s. Total durations are 3.90/6.50 s. Opening flip, shared 10% slug increase, approved lights, teeth and spring return are preserved.

**Implemented/verified locally:** offline combat/movement/foundation and creature suites pass. Native body/flame geometry, moving orange opacity, detached rising tail, face copies, first/third-person and interruption/disposal checks pass. Final motion traces keep both complete body skins inside the chamber; the return is checked while moving at 18 studs/s, and the catch grip is on screen at normalized (0.519, 0.819). Hotbar/template isolation and both tooth ScaleTo checks pass. [Evidence and limits](evidence/2026-11-04-inferno-breath-return.json). Recordings are below live frame cadence; art/feel, devices and multiplayer remain **Unresolved**.

**Review:** `build/SlugshotInfernoInspect-FireAndCatch.rbxlx` and `build/inferno-inspect/revision4/Inferno-breath-and-catch-preview.html`. The preview has normal, running, flame detail and Floppy tabs, using actual native captures resampled by their file timestamps. Diagnostic cameras are labelled. Checkpoints and rejected trials remain in revision4.

<a id="current-revision-shared-fit-clean-lights-larger-breath-and-smile-teeth"></a>

## Previous revision: shared fit, clean lights, larger breath and smile teeth

**Confirmed, owner, later 2026-11-03:** lower/inset the inspection arm, enlarge both loaded slugs by the same amount, enlarge the breath further, and show a clean tapered tooth division in both resting Inferno smiles. The owner then rejected the blocky light outline and still-small flame, and corrected the overly close gun framing: retain enough distance to see the top of the arm. This supersedes the earlier instruction to preserve the flame's size exactly.

**Implemented:** the shared loaded-size multiplier is **1.10 for both species**. Larger Inferno candidates at 25% and 15% crossed the chamber during acting and were rejected. Centre the loaded body across the chamber and retain the evaluated sole support. First-person inspection is 0.25 studs farther inward and 0.23 down; final depth is -2.8 rather than the rejected -2.4, pulling it back 0.4 studs. Quick flip, species clocks and acting are preserved.

Replace the solid cylinder glow caps and square strips with eight smooth quarter-circle curves and two matching rails. Each has a thin pale core and a restrained broad shoulder. All attachments live in one transparent frame so cloning retains their references. The viewmodel hides the source beams locally, fades its own copy with the gun and restores the source on teardown. This changes the chamber lights, not the authored metal collars.

The same Playful Flame surface, colour flow and breath timing remain. It inherits the larger slug and an additional requested 25% nominal scale. A uniform sidewall fit still crushed that larger plume, so the curl now points diagonally into spare chamber height and curls back inward. Final native breath samples apply about **0.098 scale versus 0.045** in the rejected small-flame build; every sampled flame vertex remains inside the cylinder and end caps. The physical margin is 2% of the chamber radius. This is visibly larger, rather than a nominal multiplier hidden by the fit clamp.

The owner refined the tooth request: slightly sharper like the PNG, with small points rather than exaggerated fangs. Reshape the existing tapered tooth divider into two shallow points at 0.15 transparency for both forms, strengthening it for anger. `InfernoTeeth` evaluates its original skin weights on a rigid local surface, as the attached inspection mouth does. During the loaded O transition it disappears before the opening is fully formed and returns with the grin. The observer only edits live world models; templates and hotbar icons retain their original native meshes. Runtime resizing scales skin offsets with the model, and removed instances dispose their surfaces. No authored Blender source or uploaded asset changed.

**Observed/fixed during review:** a full-cycle trace caught Floppy's spring-driven head crossing the glass despite passing held samples. Cache his loaded body skin, then centre its deformed cross-section across the chamber after writing the spring pose; preserve its lengthwise support and all acting targets. The shared 10% scale remains identical. An early tooth attempt also altered preview templates and an imported skinned edit disappeared behind the teeth. Restrict the observer to world models, evaluate the skin explicitly and retain a small surface clearance. Rejected captures are preserved; this is why earlier trial passes are not the final handoff evidence.

**Implemented/verified locally:** combat/movement/foundation and creature suites pass. Native held-pose checks cover both complete body skins, supported sole, moving/contained flame, first/third-person light references, face copying and switch/fire/holster/death/disposal. Full-cycle native skin traces and actual whole-gun, chamber, Floppy and both-form smile captures are recorded in [evidence](evidence/2026-11-03-inferno-inspect-polish.json). Tight chamber and smile shots are diagnostic cameras; the primary preview uses normal gameplay framing. **Unresolved:** owner art/feel approval, other devices, deployed EditableMesh support and multiplayer performance. Native recordings have a lower capture cadence than live playback.

**Current handoff:** `build/SlugshotInfernoInspect-Refined.rbxlx`, with `build/inferno-inspect/revision3/Inferno-inspect-refined-preview.html`. Play, 2 for Inferno, R to inspect, V for first person, 1 for Floppy. These supersede the revision2 handoff below. Earlier checkpoints and rejected trials remain under `build/inferno-inspect/revision3`. The preview uses clean native art-review recordings; a later native pass verifies icon isolation, resizing and complete body fit. That final pass's screenshots have an escape-menu overlay and are retained as diagnostic evidence rather than used for presentation.

<a id="current-revision-integrate-the-approved-game-build-and-fix-face-attachment"></a>

## Previous revision: integrate the approved game build and fix face attachment

**Confirmed, owner, 2026-11-03:** the delivered place regressed the faster gun flip, clear canister and approved Floppy animation. Inferno's smile detaches while morphing and jumping; his return hop needs more spring. **Keep the flame as it is.** This supersedes the prior claim that preserving the old local gun sampler was the correct handoff baseline.

**Implemented:** integrated the current inspect/canister/Floppy runtime from `main` at `ecd7c73` into this isolated worktree, preserving the Inferno/transformation work. The seven source paths and source revision are in [evidence](evidence/2026-11-03-inferno-inspect-current-build.json); this is a scoped runtime integration, not a claim that all other main features were merged. It restores the clear-glass fix and viewmodel Motor6Ds that allow both slug bodies to deform. The toss is shortened again, from the newer 0.32 s flight to **0.24 s**. Floppy keeps his approved 3.77 s smile/wiggle/hop/snug act.

Inferno uses the same quick toss/catch/reveal and plain 0.42 s lower, holding longer for the approved breath. `creatureElapsed` returns real species time; the shared gun clock only extends the middle hold for Inferno. His lower begins at 5.95 s and finishes at 6.37 s. Flame flow, shape, palette, material, breath start/end and containment code are preserved exactly.

**Face fix:** the old first-person copy dropped the body's Motor6Ds while the new CPU mouth surface still followed its bones. Restoring the current rig-copy fix makes the body follow the same head motion. Mouth surfaces also get stable bounds and matching part scale, so the render origin stays fixed through narrowing, compression and turning. Native review now explicitly checks the actual first-person mesh and its rig joint, plus the mouth bounds, rather than accepting source-only close-ups.

**Spring refinement:** crouch/hold 0.28 s, fast launch and airborne turn 0.46 s, cushioned recovery 0.38 s. Compression and extension are stronger; maximum intended lift rises from about 0.0205 to 0.0337 studs, with the sole still supported outside flight.

**Implemented/verified:** combat/movement/foundation and creature checks pass; Studio CombatSelfTest and the native lifecycle/geometry review pass. Nine full-body poses stay inside the chamber (maximum radial ratio 0.9637; minimum sampled front clearance 0.05398 studs; sole error below 0.00001 studs). Flame geometry remains finite, moving and contained. Actual first-person morph, crouch/launch/landing and quarter-view face captures were reviewed, together with full motion of Inferno and the current Floppy. The glass is clear and no detached mouth appears in these reviewed views.

**Review artifacts:** `build/inferno-inspect/revision2/Inferno-inspect-current-preview.html` contains actual native recordings of the whole gun, chamber and current Floppy. It does not simulate the animation. Stills/logs and the rejected handoff checkpoint remain under `build/inferno-inspect/revision2`. **Current playable place:** `build/SlugshotInfernoInspect-Current.rbxlx` (Play, 2, R; V for first person; 1 for Floppy).

**Unresolved:** owner native feel verdict, devices, other observers and multiplayer performance. Capture is approximately 13?18 fps; the owner playtest is the full-speed judgement. Held geometry samples do not establish every intermediate pose.

## Current decision: Playful Flame becomes the native inspect

**Confirmed, owner, 2026-11-03:** "I like the playful flame a lot. ... it's perfect. Make that the animation." This selects **v3 option C** and authorizes integrating its acting, flame, face treatment and Inferno fit. Earlier variant-verdict questions below are historical. The existing 6.8-second gun choreography remains unchanged.

**Implemented:** `experiments/creatures/inferno/inspect` samples the approved performance from the shared server inspection timestamp. It drives the existing skin/lip/head/lid bones, seats the evaluated sole against the rear inner cap and uses a connected deforming EditableMesh for the little curled breath. The mouth ink has the approved thinner overhang at full O; cavity tint and expression overlap follow the browser study. The first-person gun copy receives the local mouth-mesh revision and material tint. The imported source GLB/.blend files remain preserved.

The native loaded Inferno fit is derived from chamber size to match the approved preview, rather than multiplying its different pre-existing native scale by 27%. Floppy's fit and gun movement are preserved. A general resize of every other slug remains separate work.

**Implemented/verified locally:** [native evidence](evidence/2026-11-03-inferno-inspect-native.json). `verify_combat.py` (including movement/foundation), `verify_slugs.py` and Studio CombatSelfTest pass. The native review passes first-/third-person playback, face-copy updates, a complete cycle, switch/fire/holster/death and model-disposal cleanup. All 435 referenced flame vertices are finite and contained at two developed-breath samples, with a measured shape change between them. Eight complete-body skin samples stay within the chamber: maximum radial ratio 0.9637, minimum front clearance 0.08515 studs; sole error is below 0.00001 studs. The airborne sample has 0.02046 studs clearance.

Native visual review covers the grin, mid-transition, full O before fire, two breath poses, smug recovery and spring turn. Captures and the 3 s moving record are under ignored `build/inferno-inspect/native-final`; the six-pose diagnostic sheet is `build/inferno-inspect/native-contact-sheet.png` (gun casing hidden only in those diagnostic close-ups). Earlier failed trials are preserved. The imported mouth binding initially folded under the O translation: evaluating the original skin on a rigid editable mouth surface fixes the observed corners without editing/uploading the accepted source.

Review fixture: `python tools/build_inferno_inspect_check.py`; normal range/unified builds exclude that fixture. Ready-to-play place: `build/SlugshotInfernoInspect.rbxlx` (Play, select 2, R; V for first person).

**Unresolved:** owner verdict on native feel, other observers, multiplayer scale, devices and low-memory/deployed EditableMesh support. Native vertex-colour/Neon shading approximates the browser shader. The sampled body bounds are not an exhaustive full-cycle proof. Some earlier trials had builtin Studio profiler/plugin warnings and startup stalls; an existing unrelated asset-type startup warning remains. No experience publication, new upload or security change was required.

## Current revision v3: face transitions and grounded canister fit

**Confirmed, owner:** the O shape is decent but its black outline is too heavy. Smile-to-O and O-to-smile need more expression across the face. Loaded slugs should fill more of the canister; Inferno appears to float while standing. Prioritize the face and outline. The broader desire for larger loaded slugs is confirmed; this preview continues to contain Inferno, and native changes remain behind the existing preview-first instruction.

**Implemented, browser only:**

- Preserve the O aperture and the existing flame/timing. The ink overhang is interpolated toward the matching lip surface, leaving 28% of its inferred rest overhang at full O, with a warmer brown rim. The cavity is a warmer dark red-brown rather than near-black. The accepted source GLB is not rewritten.
- Stage mouth width, height and pucker separately; release the smile corners before the O opens. Delay cavity darkening until the lips have narrowed. During recovery, close the opening, restore teeth and lift the asymmetric grin corners.
- Add anticipation in the eyelids and head, a more focused exhale, then a cheek/lid lift and tilted smug smile. These use existing skin/lip/head bones rather than a new expression decal.
- Increase Inferno's loaded preview scale by **27%** (0.18973 to 0.24096). Place the actual deformed sole on the rear inner cap every pose, not at the chamber centre. The single hop lifts along the canister's long axis and is the only time the sole leaves its support.
- Read-only review of Floppy's native fit found it already reserves a circular turn/articulation envelope and derives a separate inspect hop allowance. Do not remove those safeguards when later applying the general size request. Floppy's runtime, gun movement, final creature files and Studio place are unchanged in this pass.

**Artifact:** `build/slugs/inferno/inspect-preview/Inferno-inspect-studies-v3.html`. V2 source, artifact and sheet are preserved under `rejected-v2`; v1 remains under `rejected-v1`.

**Implemented/verified:** [V3 check record](evidence/2026-11-03-inferno-inspect-face-fit.json). Browser review samples the mouth opening, recovery, inhale/exhale/return expression, larger body fit and grounded/airborne/landing poses. It measures actual skinned body vertices: sole-to-cap gap follows the intended hop clearance, body radius remains inside the preview cylinder and the front cap retains clearance. The nine-pose review reports a maximum body radial ratio of 0.914 and at least 0.077 studs of front-cap clearance. Measured sole gap differs from the intended hop clearance by less than 1e-5 studs; stationary poses are seated on the cap. A 66-frame sampled 20 fps mouth/face GIF is retained. This is a browser body-mesh check, not native whole-asset collision evidence. **Unresolved:** owner facial/fit approval, Floppy's eventual larger native fit, and all Studio integration/device checks.

## Previous v2: continuous breath and spring return

**Confirmed, owner feedback:** the first fire felt like a PNG flashing up, and Inferno's acting was insufficiently fluid. He should already be looking at the holder as the gun rises, giving more time for the breath. The mouth must smoothly form an O, hold the breath, then return to a smug smile. Use the lobby's springy hop to return to the loaded pose; inspect Floppy's motion for smoothness.

**Implemented, preview only:**

- All candidates face the holder from time zero; there is no initial hop/turn. Mouth preparation runs about 1.48-2.03 s, after the wrist reveal is visible, and precedes the fire at 2.06 s.
- A/Rolling flame breath lasts 1.69 s, B/Slow curl 1.89 s, C/Playful flame 1.59 s, followed by a short travelling tail. These supersede the short, separate puffs below.
- Lip bones move from the authored grin to a round opening while the existing mouth surface darkens into a cavity, then restore the smile. No angry/gritted face or flat mouth overlay.
- Fire is a connected volumetric swept surface. Its centreline, radius and tip deform with travelling waves; procedural warm colour bands flow along it. The front grows outward from the mouth, and the last flow runs out after exhalation. It is not the prior scaled extruded silhouette.
- Floppy's inspect supplies the coordinated head/upper-body counter-motion approach. The latest grove spring hop in `slugshot-slide-shot` supplies the 0.30 s wind-up, 0.10 s hold, 0.58 s airborne stretch/turn and 0.38 s cushioned landing. One hop begins at 4.50 s and settles by 5.86 s, before the unchanged gun lowering. Compression is distributed across existing body/head bones; antennae trail the pose.
- The shared gun sampler is byte-identical to the v1 browser preview. No runtime gun/slug source is edited. The browser still approximates the native first-person composition without arms.

**Artifact:** `build/slugs/inferno/inspect-preview/Inferno-inspect-studies-v2.html` (standalone/offline). The rejected v1 source, artifact, captures and report are preserved under `rejected-v1`; source timing/deformation is in `preview.js` and `flow.js`. Fire view now plays the flowing breath by default.

**Implemented/verified:** [v2 check record](evidence/2026-11-03-inferno-inspect-fluidity.json). Browser QA checks that the fire geometry changes between two fully developed breath moments (not simply its scale), mouth opening height changes, all actors are already facing the holder during the raise, the gun sampler remains unchanged, and the full pose cycle remains finite. Eight-pose contact-sheet review covers raise, mouth, two breath moments, grin, wind-up, airborne turn and landing. A 66-frame sampled 20 fps mouth/breath GIF is included; this is not a live performance benchmark. Browser checks pass without exceptions. **Unresolved:** owner visual/feel acceptance and all native Roblox implementation/export/device checks. The procedural browser shader is not a drop-in Roblox material or an exported animation.

## Historical v1 variants (rejected)

| Variant | Breath | Acting |
| --- | --- | --- |
| A — Cheeky puff | One compact rounded curl, about 0.46 s | Knowing look, a small head tilt/recoil, smile, two settling hops |
| B — Lazy curl | A taller, narrower upward curl, about 0.80 s | Longer sideways look and smaller settling hops |
| C — Double tease | Two small breaths, about 0.28/0.26 s | Opposite head tilt, second breath smaller, pleased settling hops |

The 6.8-second gun timing is shared across every candidate, using the existing `SlugInspect` scalar timing and basis as the browser reference. The browser is a performance/shape study using existing GLBs, not a captured Roblox first-person animation: it has no hand/arm/viewmodel solution, and its assembly-space presentation approximates the game composition. Choosing a variant does not approve a change to the gun animation. Native fit, materials and first-/third-person playback must be checked during the later implementation.

## Artifact and source

- Authoring: `tools/slugs/inspect-preview/{index.html,style.css,preview.js,flow.js}`.
- Build: `python tools/slugs/build_inspect_preview.py`.
- User-facing standalone artifact: ignored `build/slugs/inferno/inspect-preview/Inferno-inspect-studies.html`. Opens directly in a desktop browser, with embedded models/library and no network/server dependency.
- Controls: synchronized comparison, focus A/B/C, play/pause/replay, timeline/beat seeking, playback speed, orbit/zoom, canister/whole-gun/fire-only views. Reduced-motion preference starts playback paused.
- Art: existing original Inferno base GLB and blaster long-bevel GLB, plus current authored blaster colours exported without IDs. Source SHA-256 values are recorded in generated `provenance.json`. The accepted `.blend` files and Roblox models are untouched.
- Fire: dynamic connected swept surfaces with travelling deformation and procedural colour flow (v2); the original extruded contours were rejected. The plume follows the animated mouth and is scaled against the actual preview chamber cylinder. No detached fireballs, image rectangles or reference-image textures are used.
- References: owner-supplied `Screenshot 2026-11-03 164011.png` and `Screenshot 2026-11-03 164026.png`, inspected as fire-shape references only. No licence is inferred for those images; neither is redistributed or used as a texture.
- Library: official Three.js **r159**, MIT (licence embedded in the standalone artifact and retained beside the preview). GLTFLoader/BufferGeometryUtils source and imports were inspected; pinned hashes are in the build script. Local cache `.tools/three-r159` contains only those reviewed files from `https://raw.githubusercontent.com/mrdoob/three.js/r159/`.

## Verification and limits

**Implemented/verified:** browser QA loads all three actual GLB actors, samples the entire 6.8-second cycle at 30 Hz, checks finite poses and plume scale limits, verifies focus/compare and beat controls, and checks 390 px mobile width. Frame/contact-sheet visual review covers look, breath, smile and settle in all three versions, plus whole-gun and fire views. See generated `qa-offline/report.json`, images and `contact-sheet.png` under the preview output. This checks the local browser artifact, not Roblox.

**Unresolved:** owner variant/acting/fire-size preference; glass readability and flame stylization; native canister fit and clipping (the browser bound is not a Roblox skinned-vertex proof), interruptions, first-/third-person playback and device performance. Those limits describe the original preview gate; the selected native integration and its current limits are recorded above. No new assets were uploaded or experience published for the integration.

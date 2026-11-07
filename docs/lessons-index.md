# Lesson index

Look here before trying something similar, then open only the linked section. The full stories stay in the [creature lessons](slugs/blender-lessons.md), [art lessons](art/lessons.md) and [design language](slugs/owner-design-language.md). Search by the symptom or the owner's word.

**Scope:** `Principle` applies to any slug or asset. `Slug` applies to that slug, so copy the idea and not the numbers. **Status:** `Owner` means the owner accepted it, `Verified` means it was tested but has no owner verdict on record, `Rule` means a process rule from a failure.

Add a row when a fix would save the next attempt. Keep each row to one line and link the detail.

## Motion and acting

| Symptom or owner's word | Cause | What worked | What failed | Scope | Status | Detail |
| --- | --- | --- | --- | --- | --- | --- |
| "stiff", wiggle moves as one piece | Whole model swivels, or body bends as a unit | Fixed base, bend travels up the spine, each part trailing the one below | Whole-model yaw | Principle | Owner | [Language](slugs/owner-design-language.md#inspect-flip-and-creature-acting-2026-11-02) |
| Foot slides while the head moves | Whole-body re-centring each frame to stay in the canister | Anchor the evaluated sole; limit upper and head motion only when needed | Moving the whole creature to counter the head | Principle | Owner | [Lessons](slugs/blender-lessons.md#2026-11-04---fixed-sole-coherent-assets-and-real-glass-dimensions) |
| "stiff and choppy" after fitting a larger slug | Per-frame clearance gain cut the spine motion | Keep enlargement subordinate to containment; restore the accepted look | Altering face or antennae to fit | Slug: Floppy | Owner | [Lessons](slugs/blender-lessons.md#rejected-floppy-overcorrection-and-restoration-2026-11-04) |
| "frozen frame", "animated, but not really" | Motion in source units shrinks with the model; too regular | Slow, loose, non-repeating motion sized to read at loaded scale | Ground-size amounts at 0.076 scale | Principle | Verified | [Lessons](slugs/blender-lessons.md#loaded-slug-looked-frozen-and-a-black-wall-behind-the-glass-2026-11-02) |
| "just stays still" though bones change | Clone lost its Motor6D, so skin does not deform | Recreate rig Motor6Ds on the clone; review the instance the player sees | Trusting numeric bone checks | Principle | Verified | [Lessons](slugs/blender-lessons.md#skinned-mesh-ignored-its-bones-in-the-first-person-copy-2026-11-03) |
| "spring up", hop has no life | Two rigid translation pulses | Compress, short hold, fast stretch, turn in the air, cushioned landing | Rigid hops | Principle | Owner | [Language](slugs/owner-design-language.md#exhibition-hopping-and-size-2026-11-03) |
| "splat", landing does not read | Landing press smaller than take-off | Bigger landing press with recovery: body deforms, nothing on the floor | Wet or slime effects | Principle | Owner | [Lessons](slugs/blender-lessons.md#2026-11-03---flat-floppy-sole-and-readable-landing-compression) |
| "low frame rate" with a good FPS | Timer discarded accumulated time and skipped drawn frames | Pose every render frame; throttle only decisions | Motion on a 30 Hz gate | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03--grove-runtime-cadence-and-ground-support) |
| Elaborate act is "horrible" | Ambition too large for a tiny slug in a chamber | Reuse the approved motion the owner pointed at; a small readable gesture | Inventing a bigger performance | Principle | Owner | [Language](slugs/owner-design-language.md#inspect-flip-and-creature-acting-2026-11-02) |
| "like a PNG", effect just appears | A static shape scaled and faded | Shape evolves through travelling waves and flowing colour | Extruding one contour | Principle | Owner | [Lessons](slugs/blender-lessons.md#2026-11-03-inspect-preview-looked-like-a-static-png) |
| Face seems to do nothing during a mouth change | Mouth animates alone with eyes and head fixed | Overlap lids, head and corners; check both mid-transition directions | Checking only end poses | Principle | Owner | [Lessons](slugs/blender-lessons.md#2026-11-03-o-mouth-ink-expression-overlap-and-canister-grounding) |
| Inhale does not read | Torso lift alone | Belly silhouette expands, mouth widens, small forward hop at the blow | Cheek balloon | Slug: Inferno | Owner | [Language](slugs/owner-design-language.md#visible-inhale-and-comparable-loaded-size-2026-11-04) |
| Spin vanishes in a blend | CFrame blend between poses a full turn apart | Sample an unwrapped angle, apply the turn after the held pose | CFrame or quaternion blending | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-02---whole-turn-inspect-flourishes) |
| Sad or angry face from a "tired" pose | Rim slope and lowered mouth corner | Render the actual bone pose and compare angles; restrained upward corners | Judging from parameter names | Slug: Floppy | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03---content-sleepy-eyes-and-stable-smile) |
| Passes a look check but does not read | Threshold on an intent flag or a tiny tilt | Measure the actual head vector; use a look big enough to see | Checking a state flag | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03---verify-actual-head-direction-not-an-intent-flag) |
| Fast transformation looks fine slowed down, unclear in play | Beats shorter than the player's view allows | Judge 1× from the shooter first; keep glow, twirl and reveal | Rings, explosions and more detail | Principle | Owner | [Transformation](slugs/transformation-system.md#current-owner-direction-shared-twirl-and-diffuse-glow-2026-11-03) |
| Motion is fine standing, hidden while running | Run swing or camera blocks it | Review from the gameplay camera while moving | Standing-only review | Principle | Verified | [Language](slugs/owner-design-language.md#animation-and-roblox-runtime-lessons-drawholster-2026-10-31) |

## Rig and runtime

| Symptom | Cause | What worked | What failed | Scope | Status | Detail |
| --- | --- | --- | --- | --- | --- | --- |
| Random arm angle or stuck pose after fast input | Two writers, or a live joint read as rest | One owner per joint property; capture rest once | Re-reading a live value | Principle | Verified | [Language](slugs/owner-design-language.md#animation-and-roblox-runtime-lessons-drawholster-2026-10-31) |
| Pose resets, copy reads a reset frame | Unordered RenderStepped, native animation resets bones | Idle at Character +2, face +3, viewmodel +10 | Sampling during Heartbeat | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-02---runtime-inspect-composition) |
| Slug silently never animates in a place | Model arrives before skeleton or weld; `WaitForChild` on a missing module | Retry until complete; check every project file when a script gains a wait | Registering a partial rig | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03-merging-creature-scripts-into-main) |
| Fixed in source, still old in Studio | The open place or private model is stale | Rebuild the exact place, refresh model, maps and materials together | Trusting dates or updating files only | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03---a-correct-export-does-not-update-an-already-open-lobby) |
| Black patches after a model update | New model with old SurfaceAppearance maps | Refresh model, maps and materials as a bundle | Partial asset sync | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-04---fixed-sole-coherent-assets-and-real-glass-dimensions) |
| Loaded slug far smaller than planned | `GetBoundingBox` inflated on skinned models | Measure from bones | Bounding box | Principle | Verified | [Lessons](slugs/blender-lessons.md#artistic-and-visual-lessons) |
| Mouth folds in an imported mesh at large moves | Engine binding; exact cause unresolved | Rigid local EditableMesh evaluated with the original weights | Ink edits alone | Slug: Inferno | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03---port-the-approved-inspect-into-the-native-canister) |
| Held poses pass, continuous motion crosses the glass | Checked poses, not the path | Trace whole-cycle body bounds | Sampled holds | Principle | Verified | [Lessons](slugs/blender-lessons.md#later-native-polish-fit-clamps-tooth-scope-and-dynamic-bounds) |
| Captures show nothing changing | Play never started: identical Edit-mode frames | Compare frame sizes before diagnosing | Debugging the model | Principle | Rule | [Lessons](slugs/blender-lessons.md#2026-11-02-inferno-dragon-frayed-inner-eye-corners) |
| Headless Edge survives its launcher and locks files | Launcher exits early; children keep running | Stop them by private profile folder, then exit explicitly (`capture_motion.mjs`) | `browser.kill`, `taskkill /T` | Principle | Verified | [Tool](../tools/slugs/capture_motion.mjs) |
| Soft glow becomes a hard disc in a capture | Transparent canvas PNG with alpha dropped | Composite over the stage colour before stitching | `convert("RGB")` | Principle | Verified | [Tool](../tools/slugs/review_motion.py) |
| Clip renamed after reimport | FBX export included other objects | Limit to armature and mesh; assert clip names, then Studio | All-actions baking | Principle | Verified | [Lessons](slugs/blender-lessons.md#technical-lessons) |
| Self-test stand-in "never affected" by an area check | A Humanoid with no Head dies, so health checks skip it | Give test stand-ins a Head like a real character | Blaming the area query | Principle | Verified | [Ability specs](slugs/ability-specs.md#built-so-far---2026-11-06) |
| Slug shows as a ball in the HUD; "models unavailable: Argument 1 missing or nil" | Ignored `private-assets` are per worktree; a newer upload's keys never reached this one | Compare key names (not IDs) across worktrees and copy the complete file after checking shared values match | Hunting in the code | Principle | Verified | [Inspect note](loadout-controls.md#current-first-person-inspect-view-2026-11-07) |
| A held movement (wall run) slowly sinks | Velocity set before the physics step; gravity then acts through the step | Add gravity's half-frame share and steer back to a held height | Setting vertical speed to 0 alone | Principle | Verified | [Movement](movement.md#what-changed-in-v741-wall-runs-hold-their-height) |
| "Failed to create EditableMesh ... memory budget", then an unrelated mesh feature breaks | A per-model mesh script also ran on every short-lived shot | Skip transient copies (shots) in the watcher | Cleaning up after each one | Principle | Verified | [Inferno teeth](../experiments/creatures/inferno/client/InfernoTeeth.client.luau) |
| A rig prepared with editable meshes shows a block or never acts | It ran out of mesh memory halfway, after changing some parts; or a clone copied the "already applied" marker without the mesh | Make every mesh before changing any part; retry later; clear the marker on copies | Destroying meshes a part still shows | Principle | Implemented | [Inferno inspect](../experiments/creatures/inferno/inspect/init.client.luau) |
| Shots "feel inaccurate" though they land on the crosshair | A slow, heavy slug lobs high over the line; out of reach it lobs to maximum range | Flatter flight (faster, lighter) so the path hugs the line | Tuning correction shares | Slug: Floppy | Verified | [Combat](combat.md#flatter-floppy-and-a-farther-empty-space-aim-2026-11-07-current) |
| Bringing a held item nearer pushes the part you want off screen | Scaling about the camera keeps the grip in place, not the offset part | Scale about the part to show (the canister) | Scaling the hold position | Principle | Verified | [Inspect note](loadout-controls.md#current-first-person-inspect-view-2026-11-07) |

## Modelling, face and effects

| Symptom or owner's word | Cause | What worked | What failed | Scope | Status | Detail |
| --- | --- | --- | --- | --- | --- | --- |
| "just looks horrible" after many scripted passes | Method, not parameters | Agree a live 3D concept, then rebuild from the same maths | More cosmetic passes on a lofted profile | Principle | Owner | [Lessons](slugs/blender-lessons.md#artistic-and-visual-lessons) |
| "stuck on", "glued on" | Flat discs on a curved surface | Recessed sockets, lids that sink in, roots from inside | Stickers | Principle | Owner | [Language](slugs/owner-design-language.md#what-phrases-have-meant) |
| "too hard", "not squishy" | Shape, not shader | Belly sag, neck roll, soft ground contact; motion big enough to read | 2-3% motion, sheen | Principle | Owner | [Language](slugs/owner-design-language.md#what-phrases-have-meant) |
| Too many black lines, lines morph with the angle | Inverted hull inside hollows | Paint fixed lines; `Highlight` for the outline | Trimming or tucking the hull | Principle | Verified | [Lessons](slugs/blender-lessons.md#black-lines-and-double-lids-on-slug-faces-2026-11-02) |
| Black wall behind the glass | Inside faces of a hull seen through glass | No hull on the transparent part | Tinting | Principle | Verified | [Lessons](slugs/blender-lessons.md#loaded-slug-looked-frozen-and-a-black-wall-behind-the-glass-2026-11-02) |
| Colour missed repeatedly | Guessing | Sample the owner's reference in neutral light | Guessed colours | Principle | Owner | [Language](slugs/owner-design-language.md#what-phrases-have-meant) |
| Round parts turn oval when resizing | Global non-uniform scale | Height map on the torso; move the rest rigidly | Scale | Principle | Verified | [Lessons](slugs/blender-lessons.md#technical-lessons) |
| Painted texture does not reach the game | Packed image kept old pixels | Pack a fresh image; diff the exported bake | Trusting the file on disk | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-01---a-packed-image-kept-its-old-pixels) |
| "individual fireballs" | Many separate flames or puffs | One designed shape; fire in the body mesh or a shaped mesh | Particles, twice over | Principle | Owner | [Lessons](slugs/blender-lessons.md#2026-11-02-inferno-tail-fire-from-particles-to-mesh) |
| White box or strip on first load | Beam image not preloaded as a Beam | Preload the Beam; `TextureSpeed` 0 | Preloading as anything else | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03-inferno-flight-fire-from-particles-to-wing-geometry) |
| Square glow near a floor | Depth-clipped billboard | No depth clip, with a separate wall raycast; gate on asset fetch status | `IsLoaded` on a disabled board | Principle | Verified | [Lessons](slugs/blender-lessons.md#2026-11-03-reset-the-transformation-around-the-accepted-beats) |

## Environment and art

| Symptom or owner's word | Cause | What worked | What failed | Scope | Status | Detail |
| --- | --- | --- | --- | --- | --- | --- |
| Rework got worse than an earlier version | Building on the disliked state | Roll back to the liked version and add the listed items | Iterating on the worst | Principle | Owner | [Art lessons](art/lessons.md#workflow-that-worked) |
| Blurry large pieces, thin detail collapses | Roblox caps maps at 1024 | Spend texels where seen; repeating maps | 2048 maps on huge pieces | Principle | Verified | [Art lessons](art/lessons.md#2026-11-04---roblox-caps-every-map-at-1024-huge-pieces-blur-thin-detail-collapses) |
| Lava close-up is jagged | Reduced an atlas with tight UV islands | Keep the authored material | 256-square swap | Principle | Owner | [Art lessons](art/lessons.md#2026-11-03---reject-texture-quality-and-performance-regressions) |
| Lava not visibly flowing | Sparse highlight texture | Fuller streak pattern, tinted, slow | Moving glints | Principle | Verified | [Art lessons](art/lessons.md#2026-11-03---a-moving-glint-is-not-a-flowing-liquid-surface) |
| Spires "too spirally" | Patterns that wrap as a helix | Straight ridges, offset rows | Twisted ridges | Principle | Verified | [Art lessons](art/lessons.md#2026-11-04---faceting-round-a-column-reads-as-a-spiral) |
| Walls read as pillows or crumpled paper | Scaled small rocks; facets on shallow relief | Solid pieces, strong relief, two sizes | Scaling up | Principle | Verified | [Art lessons](art/lessons.md#2026-11-04---faceting-round-a-column-reads-as-a-spiral) |

## Working with the owner

| Situation | Do | Avoid | Status | Detail |
| --- | --- | --- | --- | --- |
| "Perfect" | Stop and preserve it; apply any "only thing is" tweak only | Polishing further | Owner | [Language](slugs/owner-design-language.md#how-the-owner-works) |
| A correction of an approved thing | One change, say the number | Reinterpreting it as a redesign | Owner | [Language](slugs/owner-design-language.md#original-floppy-means-restoration-2026-11-04) |
| A new design or performance | Show several real candidates and recommend one | Repeated single guesses | Owner | [Motion library](slugs/motion-library.md#decisions) |
| A handoff | Rebuild, then one clean Studio window | Stale places, many windows | Owner | [Language](slugs/owner-design-language.md#how-the-owner-works) |
| Any passing check | Say what it covers, then look at it | Treating a check as approval | Rule | [Motion review](slugs/motion-review.md) |

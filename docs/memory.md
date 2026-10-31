# Project memory

## 2026-10-30 - Rocklock cavern art pass

## 2026-10-31 ? Slower movement pace (v7.39)

- **Confirmed:** owner asked for run 18, sprint/wall run 24, slide cap 26, slower locomotion and camera bounce, slightly slower flips and shorter jump reach at the existing heights.
- **Implemented:** speed/cadence/camera/horizontal launch retune in the existing movement worktree; v7.38 source checkpoint retained under ignored `build/checkpoints/`. Baseline remains a stock-speed comparison. No private animation source edits or uploads.
- **Implemented/verified offline:** full movement verifier and private build pass. Compared all profile jump power/gravity and action vertical launches plus slide decay/timing to the checkpoint; unchanged. New Studio process launched on the private v7.39 build, preserving other windows.
- **Unresolved:** live gameplay and multiplayer checks, feet/limb cadence and flip/landing timing, camera comfort and owner verdict. [Details](movement-verification.md#v739-slower-movement-pace-2026-10-31).

## 2026-10-31 ? Wall-run terrain continuation

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

## 2026-10-28 ? Foundation setup

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

## 2026-10-30 ? Rocklock spacious cavern greybox

- **Confirmed:** the pasted owner request authorized the isolated playable map, original procedural Blender geometry, source/exports/previews and Studio tests; no controller/camera rebalance, main merge, publication or private-asset redistribution. Work is on `experiment/rocklock-greybox`.
- **Confirmed correction:** the owner saw the first map and found it crowded. They want wide Slugterra-like caverns for gunplay and larger transformed slugs, not many closely packed structures. v2 expands 100 ? 90 to 160 ? 140, removes crowns, tower stairs, shoulder blocks and training stones, and uses broad ordinary ramps. Keep that spaciousness preference in later iterations.
- **Implemented/verified:** shared layout ? headless Blender ? native, noncolliding faceted art plus 35 simple collision pieces; editable `.blend`, FBX roundtrip, eight previews, structured coordinates and disabled interaction metadata. Separate Rojo projects preserve the lab/foundation. A generated server copy adapts only initial placement through stable opposite spawn slots before validation history initializes; controller and camera sources are untouched. [ADR 0010](decisions/0010-rocklock-map.md).
- **Implemented/verified:** full offline checks passed. Two Studio clients completed flank ramp/crossing, wall-run/kick, underpass, first jump, flip, slide/slide-jump, peer action observation and stable opposite respawn; each had 6 accepted actions, 0 rejected requests, 0 corrections. Two first-jump samples: about 16.46 travel and 10.87?10.88 rise. 108 enclosure rays hit boundary collision. [Results and limits](rocklock-verification.md).
- **Unresolved:** subjective feel/scale, gunfight timing/balance, actual larger-form dimensions, exhaustive camera/escape/stuck tests, devices/controlled FPS/network impairments. One test client averaged ~68 ms/frame, the other ~16.85 ms; window focus/throttling was not controlled. A first harness failed because plugin-only settings() was called inside a game Script; it was corrected and rerun.
- **Workflow lesson:** a fresh Studio file can show a Lighting Technology Migration dialog if the generated place defaults to Compatibility. Rocklock explicitly uses Voxel. Close the generated test window and discard temporary QA edits before rebuilding; preserve unrelated unsaved windows. Never save a stale open place over the rebuild.
- **Implemented/verified final handoff:** the public original-clip build passed a spawn/flip/slide smoke (0 rejections/corrections). The final private map was rebuilt and reopened; W/Space reached the north cover with 0 rejections/corrections, then play stopped. Two noncolliding fill-light hosts improve the expanded floor visibility; final count 4,854 Parts / 35 solid pieces. QA fixtures are absent.

## 2026-10-30 ? Rocklock v3 size change

- **Confirmed:** the owner said v2 was too small and requested about 33% more size as the first change. **Implemented:** v3 scales both horizontal dimensions and the existing geometry/coordinates by 1.33, from 160 ? 140 to 212.8 ? 186.2 studs; floor area rises about 76.9%. Traversal heights, movement and camera stay unchanged.
- **Implemented:** separate `-v3` public/private build outputs leave the owner?s already-playing v2 place and its unsaved session alone. Existing Blender source and export matched their recorded hashes before regeneration.
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

## 2026-10-31 ? Review and backup of all local work

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

## 2026-10-31 ? Solid muzzle private mesh update

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

# Project memory

## 2026-10-31 — First slug and permanent design catalogue

- **Confirmed:** owner supplied two Flopper images and a description, requesting a distinct original soft, expressive, non-transforming slug and reusable notes for every future species. Slippery patch, smoke and tripwire are gameplay ideas rather than approved implemented rules.
- **Implemented/verified:** [first design record](slugs/catalog/flopper-inspired.md), [catalogue/template](slugs/catalog/index.md), original editable Blender draft, rig and five animation slots. Headless Blender renders and FBX reimports passed, as did project checks; see that record for exact hashes, measurements and limits. The named Sketchfab collection was inaccessible; only the supplied screenshots and a search-indexed community wiki entry were reviewed.
- **Unresolved:** owner visual feedback, Studio native/import runtime and animation-scale behavior, 21-mesh device performance, final name and any gameplay design. No assets uploaded or published, and unrelated work was not touched.

## 2026-10-31 — Isolated slug asset tooling

- **Confirmed:** the owner's attached request authorizes universal creature tooling and original temporary placeholders, while Claude owns concurrent Rocklock/map/destruction work. No final creatures, full combat, merge into main or asset publication authorized.
- **Implemented:** separate worktree `C:/Users/runni/slugshot-slug-pipeline`, branch `feature/slug-asset-pipeline` at baseline `913f9e6`; versioned JSON custom rigs/species and generated strict Luau; native Blender 4.5.14 LTS generation/actions/export/previews; independent-rig, flight-time-aware visual interfaces and isolated lab. See [ADR 0011](decisions/0011-slug-asset-pipeline.md).
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

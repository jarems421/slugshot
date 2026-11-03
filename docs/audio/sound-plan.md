# Slugshot sound event audit and first style test

**Confirmed, 2026-11-02:** owner requested a whole-game event inventory, prioritized shooting/damage/movement before menus, a proposed style, and about five test sounds. Stop for approval before making the remaining library. **Considering:** every audio treatment, hearing policy and mix target below. None is approved final art or new gameplay.

**Audit baseline:** integrated code `9e7a41c` plus settings persistence `c919351`, in isolated branch `design/sound-direction`. Read-only comparison against lobby branch `7bda6a0` found newer mobile/detail work; no concurrent files were changed. This inventory covers implemented combat, movement, Floppy, Rocklock destruction, lobby ambience and interfaces. Unimplemented systems are explicitly deferred. `src/` remains the foundation.

## Listen first

**Implemented, 2026-11-02:** owner requested easier playback and organized provenance/rationale. Open the private [Sound Library](https://slugshot-sound-library.jarems421.chatgpt.site): Play All/Next/Stop, individual players, search/category filters, explanations for each original preview, 65 unfinished event groups and a separate source list. Five originals, zero internet-sourced selections; the two existing Roblox built-in placeholder sources are identified but not redistributed. No further sounds were generated.

[Open the five-sound listening page](style-test-v1.html), or [play the single review reel](../../assets/source/audio/style-test-v1/00-review-reel.wav).

| Sketch | Intended character | File | Length / reel start |
| --- | --- | --- | --- |
| 1. Blaster shot | A firm pressure snap and chunky body, with a small crystal-metal tail | [WAV](../../assets/source/audio/style-test-v1/01-blaster-shot.wav) | 0.62 s / 0.40 s |
| 2. Charge | Air/motor texture, three tactile catches, then a brief full hold | [WAV](../../assets/source/audio/style-test-v1/02-charge-three-stages.wav) | 1.65 s / 1.72 s |
| 3. Taking damage | A dense, short body/cloth impact | [WAV](../../assets/source/audio/style-test-v1/03-taking-damage.wav) | 0.43 s / 4.07 s |
| 4. Stone footstep | Boot contact, a little grit and cloth friction | [WAV](../../assets/source/audio/style-test-v1/04-stone-footstep.wav) | 0.40 s / 5.20 s |
| 5. Menu click | A tactile ceramic/wood tick with a faint crystal overtone | [WAV](../../assets/source/audio/style-test-v1/05-menu-click.wav) | 0.24 s / 6.30 s |

Exactly five unique sounds; the reel concatenates them with silence. The charge file is an audition phrase with deliberately spaced stages at 0.32/0.64/0.96 s, **not** a game-ready loop or a timing change to the current charge. A single footstep demonstrates material/weight, not a finished variation set.

**Implemented/verified offline:** original deterministic synthesis, mono PCM16 WAV, 48 kHz; finite samples, no sample clipping, zero endpoints; per-file peak/RMS, lengths and hashes in [manifest](../../assets/source/audio/style-test-v1/manifest.json). Peak levels preserve the hierarchy: shot -3.10, damage -5.17, charge -5.35, footstep -8.18, click -14.97 dBFS. Peak values are technical measurements, not perceived-loudness matching or true-peak certification.

**Provenance:** authored with [build_style_test.py](../../tools/audio/build_style_test.py), seed 20261102 and the existing NumPy installation. No recordings, downloaded samples, franchise sounds, external generation service, purchases, uploads or asset IDs. The source and WAVs are retained for iteration. **Unresolved:** listening judgement, phone/headphone readability, compressed/transcoded playback, Roblox spatial mix and runtime tests. No claim of an auditory review from numeric checks. No runtime audio has been wired or replaced.

## Proposed style: tactile cavern fantasy

Translate [Living Comic-Book Fantasy](../art/style-guide.md), especially calm bases/selective accents and the life-pass sound direction, into a clear sonic hierarchy:

- **The bold ink edge becomes the attack:** quick, legible contact at the exact action moment. Blaster shots get a dry pressure snap, rounded low-mid weight and a short mechanical catch.
- **The painted depth becomes the body:** boot leather/cloth/stone, ceramic-like fittings, restrained metal resonance. Creature impacts are soft and damp; Floppy gets sleepy, airy little burbles and body friction.
- **The magical accent is small:** a short, inharmonic crystal resonance on charge milestones, readiness and important interactions. Keep that colour recognizably related across blaster and UI without putting a chime on every action.
- **The cavern stays calm:** low air, far water, sparse drips, subtle glowing machinery/portal hums, local creature life. Wet surfaces and water sound different from dry stone. Ambience leaves space for enemy steps and shots.
- **Motion is physical:** cloth/air on flips, material friction on slides and walls, clear weight on landings. Ground jumps stay lighter than hard landings. Damage is a distinct body impact, while the shooter's hit-confirmation is a short private tick.
- **Menus are tactile and quiet:** muted clicks, even softer hover, small open/close gestures. The goo and crystals inform the materials; flowing decorative animation stays mostly silent.

This is a proposal derived from the project's art direction, not an imitation of franchise audio. No voice acting, speech or music is generated in this batch. Musical direction can be discussed later if requested.

## How to read the inventory

**World** = nearby players should hear a positional sound, including the owner; not a map-wide announcement. **Private** = only the relevant player. **Hybrid** = a private close layer plus one nearby world layer, with duplicate suppression. **Optional** = restraint decision to approve; silence is often preferable. Trigger names below refer to real code **hook locations**, not existing audio unless marked **placeholder exists**. The hearing policy is proposed; it does not imply networking already exists.

Source key (paths and line numbers at the audited baseline):

| Key | File / useful entry point |
| --- | --- |
| C | [CombatClient](../../experiments/combat/client/CombatClient.client.luau:162): `fire`, `beginCharge`, server replies, canister readiness |
| CS | [CombatServer](../../experiments/combat/server/CombatServer.server.luau:209): authoritative `Shot` and `Impact` messages |
| R | [BlasterRecoil](../../experiments/movement/client/BlasterRecoil.luau:68): `onClunk`, `setCharging`, stage |
| M | [Movement client](../../experiments/movement/client/init.client.luau:126): attach, action starts/ends, jump input, sprint |
| MS | [Movement server](../../experiments/movement/server/init.server.luau:413): replicated `MovementAction` / `MovementActionTime` |
| P | [Presentation](../../experiments/movement/client/Presentation.luau:420): locomotion phase, `watchMoves`, ground transitions |
| A | [BlasterAnimator](../../experiments/movement/client/BlasterAnimator.luau:247): `begin`, `equip`, `holster`, stow/catch timing |
| V | [SlugVisuals](../../experiments/combat/client/SlugVisuals.luau:181): `launch`, collision sweep, canister pop |
| F | [FloppyRecovery](../../experiments/combat/client/FloppyRecovery.luau:71): `phase`, `land`, recovery states |
| H | [PvpHud](../../experiments/combat/client/PvpHud.luau:115): health changes and `Hud.step` cooldown/readiness edge |
| S | [Settings](../../experiments/combat/client/Settings.client.luau:426): tabs, controls, sliders, bind prompts, hex field, reset, opening |
| UI | [PvpFx](../../experiments/combat/client/PvpFx.luau:66): `sound` and shared chunky controls |
| D | [Rocklock client](../../experiments/rocklock-v2/client/init.client.luau:140): `DestructionFx.OnClientEvent` and its kinds |
| DS | [Destruction](../../experiments/rocklock-v2/server/Destruction.luau:237): authoritative break, warning, impact, dig, raise |
| L | [HubMotion](../../experiments/lobby/hub/client/HubMotion.client.luau:32): movers, bridges, lightning, eruption |

## P0 — shooting and damage, first

| ID / event | Existing trigger location / proposed hook | Who should hear it; sound behaviour |
| --- | --- | --- |
| C01 Charge start | C `beginCharge` (262), only its successful branch | Hybrid: latch/air onset. World charge requires a new validated start/stop protocol; no such broadcast exists now. |
| C02 Charging bed | C charging branch in `RenderStepped`; R `setCharging` | Hybrid: rise/hold continuously, no retrigger every frame. Owner prediction first; world state remains a proposed hook. |
| C03 Charge steps 1/2/3 | R `onClunk` (68), already consumed by C for controller rumble | Private initially; World if charge replication is approved. Three progressively firmer catches; final one doubles as full-charge cue, avoiding another stacked sound. |
| C04 Charge end/cancel | C `releaseCharge` / `fire`, and the per-frame `charging = false` safety path when menu, tool or character disallows it | Private release/vent, stop all sustained layers on every exit. A shot already supplies the main release sound. No fake fire sound on cancellation. |
| C05 Tap / partial / full shot | C `fire`; CS `Shot`; observers enter C `OnClientEvent` | Hybrid, muzzle-positioned World. Same identity with charge-weighted body. Owner hears one predicted attack; server acknowledgement must not replay it. **Sketch 1.** |
| C06 Flight / near pass | V `launch` and per-frame flight position/velocity | World near the moving slug. Subtle air tumble; optional listener-relative near-pass once per projectile, not once per frame. A near-pass hook does not yet exist. |
| C07 World impact by material | CS `impact` (220), broadcast `Impact`; V independently predicts a sweep hit | World at authoritative contact. Stone/metal/wood/earth/water branches where present. Prefer server result as shared source; dedupe local predicted contact and avoid two impacts. |
| C08 Slug hitting a body | CS `impact`, `victim` and positive `damage` | World: damp squash/thud at the victim, distinct from stone. Shares one impact event, not a second full-volume hit on top of C07. |
| C09 Successful hit confirmation | C `Impact` branch with `data.shooter == player` and `data.damage > 0` (341) | Private shooter tick, only on confirmed damage. Damage popup itself stays silent. |
| C10 Taking damage | P `watchMoves` (613), health delta and `HitReaction.hit` (630); H health update is an alternate observation point | Hybrid: body/cloth hit for nearby players and a short close victim layer. Scale gently with confirmed damage; choose one health observation source to avoid double playback. **Sketch 3.** |
| C11 Death | MS `spawnCharacter`, `humanoid.Died:Once` (131); observe the replicated humanoid on clients | World short body fall; private restrained death cue. Stop charge, foot/wall/slide loops. No kill reward or victory sound inferred from death. |
| C12 Recovery / reloaded readiness | C `setCanister`, `returned = visible and shown[tool] == false` (389); H `remaining <= 0 and wasCooling` | Hybrid soft canister catch + private ready accent. Use one readiness edge, not both hooks; cooldown readiness is separate from the slug burrowing. |
| C13 Draw / equip | A `equip` (256), `begin("draw")`, motion time / grip catch | World short cloth/metal draw; optional closer owner layer. Use one flourish driver, not both tool parenting and motion callbacks. |
| C14 Holster / stow | A `holster` (285), `Motion.stowAt` and `BlasterFlourish = "stow"` | World short socket catch for Hip; Vanish should not imply a physical hip catch. |
| C15 Flip-and-catch gun flourish | A active motion time; R `toss` / recoil style `Flip` | World light air movement and a single grip catch. Reuse draw/catch family rather than a new loud event. Timed contact markers are needed. |
| C16 ADS enter / leave | [Ads.set](../../experiments/movement/client/Ads.luau:12), called from C `aimPressed` | Private tiny mechanical/cloth raise/lower; no new enemy detection cue for camera zoom. |
| C17 Unavailable / rejected shot | C `beginCharge` fails or `Rejected` reply (346) | Private optional soft dry feedback for a deliberate blocked input. Network validation rejects stay primarily diagnostic; avoid error spam or an audible bogus shot. |

## P1 — movement, immediately after combat

| ID / event | Existing trigger location / proposed hook | Who should hear it; sound behaviour |
| --- | --- | --- |
| M01 Walk/run/sprint footsteps | P `locomotion`, `rig.phase` advances (506); ground probe in `evaluate` (892) | World boot contacts, optionally closer owner layer. Add two contact crossings per stride; gate on grounded motion. Sample material under the relevant foot. Walking/sprinting change cadence and weight, not separate overlapping loops. **Sketch 4: stone only.** |
| M02 Strafe / reverse footsteps | Same P normalized locomotion phase shared by direction clips | World, same material family, synchronized to the selected stride; no extra sounds on directional blend changes. |
| M03 Movement start / hard stop / turn scuff | P flat velocity/grounded state and locomotion blend | World subtle sole friction on real acceleration/braking/turn contact; new threshold/cooldown edges required. Not every key press. |
| M04 Ground jump / coyote jump | M `onJumpPress` standing/coyote branch (846); `attach` `StateChanged` (163); P real ground-to-air transition | World boot push/cloth. Require genuine takeoff to avoid sounding on failed/buffered requests or playing again for an air jump. |
| M05 Double jump / directional flip | M `startFlip` (294), `announce("Flip", variant, ...)`; MS action attributes | World short push/cloth/air turn. Variant accents follow the chosen motion; no weapon-like magical blast. One per action timestamp. |
| M06 Falling wind | P ground-to-air / descending velocity; M camera fall logic | Private optional low air proportional to sustained fall. Stop at ground, spawn, death or mantle; do not mask near-pass/footstep information. |
| M07 Soft / normal / hard landing | P grounded edge and `impact = -rig.lastVy` (909); existing light/hard/heavy landing thresholds | World weight/material contact; small owner body layer. One landing with scaled layers, not all three categories at once. Camera dip is not a second trigger. |
| M08 Slide entry | M `startSlide` (365), accepted `announce("Slide")` | World strong boot/cloth drop and short friction onset. |
| M09 Slide sustain | M `acro.kind == "Slide"` in simulation; P action variant | World material scrape modulated by actual speed/contact. Stop if airborne or interrupted; footstep layer is suppressed. |
| M10 Slide end / jump cancel | M `endSlide` (396) and action replacement paths | World soft stop scuff where contacting ground; stop friction on any cancellation. Jump cancel uses jump cue rather than an additional heavy stop. |
| M11 Wall catch / attachment | M successful `tryWallRun` (729), `announce("WallRun")` | World single hand/boot grab on the contacted surface. |
| M12 Wall run / climb contacts | M current wall-run speed/side; P `wallPose` and `locomotion` used for wall-running | World rhythmic surface contacts; new contact timing needed. Do not also play floor steps. |
| M13 Wall cling / downward slide | M wall-run no-input drag state; P `rig.cling` blend and wall contact | World quiet palm/sole scrape only while moving; a stationary hold is mostly silent. Distinguish from active wall-run contact rhythm. |
| M14 Wall jump / kick / hop | M `kickOff` (594), `kickLaunch`, `announce("WallHop")`; `endWallRun(jump=true)` | World short surface push and cloth kick. Deduplicate nested helper calls by one committed action timestamp. |
| M15 Wall release / lost contact | M `endWallRun` (805); P grounded/lost-wall finish | World optional tiny release; stop wall layers on loss/interruption. No heavy impact on simply dropping away. |
| M16 Mantle / vault grip | M accepted `startMantle` (437), `announce("Mantle", variant)` | World hands contacting ledge; only once the action really starts, never on ledge probes. |
| M17 Mantle pull / step / vault push / top-out | M active mantle variant and `finishMantle` (574); P action playback | World timed cloth and one or two contact accents. New per-variant timing markers needed; cancelled mantle does not play a completed top-out. |
| M18 Sprint engage / disengage | M `SprintActive` edge (1219), server movement state where needed | Private optional brief exertion/cloth shift. Sprint footsteps already signal speed; no continuous alarm or toggle chime. |
| M19 Idle fidget | P `watchMoves`, fidget clip start (659) | World very subtle cloth/stretch; long cooldown and proximity culling. Not a cue on every breathing sway. |
| M20 Spawn / respawn | MS `spawnCharacter` (24); M `attach` (126) | Private soft arrival; World optional small spawn accent. Clear all old-character emitters. |
| M21 Lobby abyss plunge / fade | [FallFade.RenderStepped](../../experiments/lobby/scale/client/FallFade.client.luau:27), depth band; MS fall-respawn check (667) | Private wind swell/fade then arrival, independent of death (the lobby fall can respawn without a damage/death event). |
| M22 First person / shift-lock switch | [FirstPerson.setActive](../../experiments/movement/client/FirstPerson.luau:60); M `setShiftLock` (994) | Private optional tiny toggle; default recommendation is silence during normal zoom, only a deliberate mode switch could tick. |

Ground materials to provision **after approval**: dry stone first; gravel/earth, constructed metal, wood/bridge, grass/moss and shallow water where actual contact materials support them. Stone sample is one test, not six newly generated families. Default Roblox character sounds may still run through injected character scripts; runtime inspection is required before replacing them to prevent duplicate steps/jumps/death. No character audio mute has been applied.

## P2 — slug life and the world

| ID / event | Existing trigger location / proposed hook | Who should hear it; sound behaviour |
| --- | --- | --- |
| F01 Floppy initial impact | V first sweep hit creates F `Recovery.new` and `phase("impact")` | World body splat folded into C07/C08, not an additional full-volume duplicate. |
| F02 Floppy ground contact / skid | F `land` (393), `phase("land")`, skid update | World soft belly flop then brief grit/skin friction; material-dependent. Wall hit then floor contact can legitimately create two separate contacts. |
| F03 Floppy wriggle / roll | F phase transition to `"wriggle"` (507), state pose | World sparse damp body/cloth-like movement; not a vocal on every animation update. |
| F04 Floppy crouch / takeoff hop | F transitions `"crouch"` / `"hop"` (528/537) | World small compress/release and air puff; mostly soft. |
| F05 Floppy burrow / earth settle | F transition `"burrow"` (550), `dirt`, `gather`, `settleDirt` | World short earth crumble and muffled body disappearance; stop if removed/unsupported. No travelling return whistle: recovery stays local. |
| F06 Floppy idle vocal / breathing | [FloppyIdle.setup](../../experiments/creatures/floppy/client/FloppyIdle.client.luau:25), [FloppyFace.step](../../experiments/creatures/floppy/client/FloppyFace.client.luau:161) | World optional sleepy airy burble with randomized sparse scheduling. Actual voice scheduler is new; procedural face motion is not a vocal event. Blinks/glowing antennae stay silent. |
| F07 Slug UI departure / return / hover hop | [SlugIcon.leave/back/hop](../../experiments/combat/client/SlugIcon.luau:398); H cooldown edge | Private optional very soft movement. Reuse C12 ready cue; random viewport performances stay silent. |
| W01 Rock chip hit | DS `damage` / `send("Hit")`; D `kind == "Hit"` | World sharp material knock. **Placeholder exists:** `collide.wav`, pitched high. Coordinate with C07 to avoid two sounds for one projectile contact. |
| W02 Structure chunk break | DS `breakChunk` / `send("Break")`; D `"Break"` | World crack + rubble, scale to chunk. **Placeholder exists.** Limit simultaneous debris voices; do not put a sound on every chip part. |
| W03 Collapse warning | DS `collapse` / `send("Warn")`; D `warn` (110) | World readable low creak/rumble preceding the fall. **Placeholder exists:** three pitched collisions. Must remain distinguishable from a completed collapse. |
| W04 Falling structure impact | DS collapse landing callback / `send("Impact")`; D `"Impact"` | World weighty rock crash with short tail. **Placeholder exists.** Count one structure impact rather than every physics contact. |
| W05 Earth excavation | DS `excavate` / `send("Dig")`; D `"Dig"` | World earth scoop/crumble. **Placeholder exists.** |
| W06 Raising slab / expiry | DS `raise` / `send("Raise")`, lifetime expiry then `breakChunk` | World emerging rock grind; reuse break family on expiry. **Raise placeholder exists.** Do not invent a new spell mechanic. |
| W07 Terrain reset | DS `reset` / `send("Reset")`; client currently has no audible Reset branch | Private tester confirmation only; this is a Studio testing control, not a production round-end announcement. |
| W08 Cavern bed / sparse drips / crystal hum | [LookZones.RenderStepped](../../experiments/lobby/client/LookZones.client.luau:16) supplies zone weights; [LookFx](../../experiments/lobby/client/LookFx.client.luau) supplies visual ambience | Listener-local zone bed plus sparse positional emitters. New audio layer required; do not sound every glowing mote or light pulse. |
| W09 Sky Well / Maelstrom / waterfalls / pond / lava | [HubArt.buildSkyWell/buildMaelstrom/buildFall](../../experiments/lobby/hub/server/HubArt.server.luau:620), [Arena.buildPond/buildRavine](../../experiments/lobby/scale/server/Arena.luau:638), L movers | World positional water/wind/low geothermal beds with overlapping sources limited. Built visual source locations exist; audio emitters do not. |
| W10 Bridge weight / creak | L `findRiders` (158) and `updateBridge` (184) | World short creaks only on meaningful load or flex changes. New edge thresholds; keep every-frame bridge motion silent. Footsteps use the bridge surface separately. |
| W11 Lightning / eruption | L `flash` (233), `startEruption` (356) / `volley`, `eruptionStep` | World distant restrained crack/rumble for lightning and geothermal eruptions. Current visual scheduling is client-local, so shared audible timing needs coordinated events before integration. |
| W12 Portal idle / zone approach | [HubArt.buildPortals](../../experiments/lobby/hub/server/HubArt.server.luau:873), LookZones weight changes | World quiet portal hum; listener-local gentle ambience crossfade. Actual teleport/enter confirmation has no gameplay trigger yet; defer it. |

## P3 — interface, after gameplay readability

| ID / event | Existing trigger location / proposed hook | Who should hear it; sound behaviour |
| --- | --- | --- |
| U01 Hover | UI `Fx.chunky` `MouseEnter` (196); S cog/tab/slider hover; [Inventory close](../../experiments/combat/client/Inventory.client.luau:85) | Private very quiet tactile brush. **Placeholder exists:** `volume_slider.ogg` sped up. Global short cooldown; one hover per entered control, no hover on touch. |
| U02 Click / press | UI `Fx.chunky` button input (211); S opener/close; Inventory close | Private dry tactile click. **Placeholder exists. Sketch 5.** Shared control and individual handler must not both fire the same click. |
| U03 Menu open / close | S `refreshOpen` (1554); [Inventory.refreshOpen](../../experiments/combat/client/Inventory.client.luau:194); [Theme.setMenu](../../experiments/combat/client/PvpTheme.luau:111) | Private compact cloth/wood slide in/out, works for keyboard/controller too. Current opening uses placeholder `select`; clicks and opening should form one small gesture, not three stacked ticks. |
| U04 Tab / option / toggle / crosshair tile / colour swatch | S tab `Activated` (609), `choice` (664), SprintDoubleTap (1010), crosshair tile/swatch (1430/1455) | Private short confirmation only on value change. Existing `select` placeholders on most paths; double-tap toggle needs a semantic hook. |
| U05 Slider grab / movement / release | S `slider` (761), drag state, `endDrag` (906) | Private one grab/release, optional throttled sparse increments. No sound per render frame or per incoming loaded attribute. Existing slider hover is only a hover tick. |
| U06 Keybind capture starts / accepts / clears | S `beginCapture` (1123), `Keybinds.capture` callback | Private quiet prompt tick, clear success tick. Acceptance currently uses placeholder `select`; clearing needs a subdued distinct cadence, not an error. |
| U07 Keybind conflict / timeout / cancel | S displaced-binding message and `endPrompt` (1099), `CAPTURE_WAIT` timer; Roblox menu cancels capture | Private optional restrained warning for displacement; cancel/timeout soft dismiss. Never an error beep on every key. No current dedicated sound hooks. |
| U08 Custom colour accepted / invalid | S `hex.FocusLost` (1491), validated branch / `hexNote` | Private optional success tick or low soft invalid tap, once per submitted value. Typing individual hex digits stays silent. |
| U09 Reset settings | S reset `Activated` (1540) | Private single heavier confirm. Existing select placeholder; suppress dozens of individual attribute-change ticks. |
| U10 Save unavailable / recovery | S `refreshSaveStatus` (321); [SettingsSync.OnClientEvent](../../experiments/combat/client/SettingsSync.luau) | Private optional one soft failure cue per failure episode, no periodic retry noise. Successful background autosaves and initial hydration remain silent. |
| U11 Inventory slot focus / actual slug selection | Inventory panel and H slot display; [KeybindDefinitions](../../experiments/movement/shared/KeybindDefinitions.luau) declares five slot actions | Private focus tick only if selection exists. Current playable slot is 1, which draws/holsters; loadout rearrangement and selecting a second slug are deferred. Do not generate five selection families now. |
| U12 Inspector / tuning / terrain tester controls | [TuningPanel](../../experiments/combat/client/TuningPanel.client.luau), D tester controls, L detail toggle | Private reuse normal UI ticks only if useful during development. No separate production sound set for debug tools. |

## Deferred systems and intentional silence

Match start/countdown/end, matchmaking, score rewards, kills/assists, upgrades, purchases, progression, workshop interactions, quest/bounty completion, portal travel, exploration encounters, additional slug species/abilities and transformations do not have approved working gameplay triggers in this audited runtime. They belong in a later inventory when implemented. These are coverage reminders, not authorized features or sounds to generate now. Native humanoid swimming/climbing and tools from unrelated places likewise need a real enabled mechanic before adding bespoke cues; the current wall-climb is covered above. Removed crouch/ground-roll mechanics get no sounds.

Healing/low-health loops are not implemented game systems here: H can observe health changes, but a future healing sound should fire only for an actual heal action. Prefer a one-time low-health alert if later approved, not a permanent heartbeat covering footsteps. Crosshair updates, damage numbers, goo ripples/drips, twinkles, eye blinks, particles, light pulses and network correction/rejection diagnostics stay silent unless an intentional gameplay event above owns the cue.

## Mix and networking proposal to approve with the list

1. Shots, confirmed impacts and dangerous enemy movement take precedence. Keep the victim's damage accent short enough that an enemy's next footstep is still readable. UI and ambient layers sit below gameplay. No loudness contest between slots.
2. Use contact positions for impacts/steps and muzzle position for shots. Private cues never reveal an opponent's menu, camera mode, hitmarker, saved setting or inventory contents. Near players hear world events with distance falloff, not full-volume global effects. Exact distances need map/Studio testing rather than being chosen from this document.
3. Predict the local shot once, use `(shooter, shotId)` to deduplicate acknowledgement; send others only authoritative shot/impact results. Movement actions already replicate via server-approved attributes; foot contacts need client presentation contact edges. Charge currently lacks remote state: do not pretend other players hear it until a bounded validated protocol exists. No per-frame audio remotes.
4. Pause/fade sustained sounds on state exits, character destruction, death, unequip, menu interruption, scene change and emitter removal. Temporary world emitters must live long enough for short impact tails after a projectile is destroyed. Limit overlapping voices by emitter/category and skip far inaudible decoration.
5. After style approval, create a small nonrepeating contact set for frequently repeated sounds, with restrained pitch variation; no random pitch on staged charge/readiness information. Runtime charge needs separate onset/stages/sustain/stop components, all following the existing clunk timing.
6. Propose independent gameplay, UI and ambience controls plus a master control in a later implementation. They do not exist yet and were not added by this task. Choose the modern audio graph or the existing Sound/SoundGroup path after a minimal compatibility/spatial test; no audio architecture rewrite in this review phase. [Roblox audio overview](https://create.roblox.com/docs/audio), [Sound placement and mixing](https://create.roblox.com/docs/sound), [modern audio objects](https://create.roblox.com/docs/audio/objects).
7. Upload only after approval of the actual assets and their intended experience use. Local mono PCM16/48 kHz WAV is a review/delivery format supported by Roblox's documented importer; actual upload/transcoding/moderation/permissions and in-game playback remain untested. [Roblox audio assets](https://create.roblox.com/docs/audio/assets).

## Approval checkpoint — stop here

Owner review requested for **(a)** the event coverage/priorities and who hears each sound, **(b)** tactile cavern fantasy as the proposed style, and **(c)** which of the five sketches to keep or revise. Suggested listening criteria: does the blaster feel chunky enough; is charge clear without becoming musical; does damage feel distinct; is the footstep grounded; is the click quiet but satisfying?

No rest-of-library generation, variants, gameplay wiring, purchases, uploads, publishing or main merge until this checkpoint is resolved. **Unresolved:** owner approval. The full list is a planning artifact; only the five named sketches have been made.

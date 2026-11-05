# Slug motion library

Reusable motion for the 14-slug roster. **Take the principle and the technique, not the numbers:** the numbers carry a slug's personality. Almost all approved slug motion is procedural Luau, so that is what this library holds. The maths is in [`MotionKit`](../../experiments/creatures/shared/MotionKit.luau) and its [browser twin](../../tools/slugs/motion-preview/motion-kit.js).

Status: **in game** means the code ships in the merged game; it does not mean the owner approved those numbers. **Approved** quotes the owner.

## Components

| Component | Use it for | How | Where it's proven | Make it distinct by changing |
| --- | --- | --- | --- | --- |
| Body compression | Hop, impact, charging | Spring on a squash channel. Upper body moves down into the base; the face keeps its shape; flanks spread | Floppy `SQUASH_UPPER` 0.38, `SQUASH_HEAD` 0.03. Inferno `crouch` | Depth, spring speed, how much reaches the head |
| Elastic extension | Leaving the floor, lunge, reveal | `MotionKit.hop` press goes negative in the air; stretch peaks early, then eases | Grove and inspect hops | Stretch, air time, damping |
| Head anticipation | Turn, inspect, targeting | Head leads with a look spring, or trails the body in a chain. Pitch down before going up | Inferno `lookYaw`, Floppy `pitch` | Lead or lag; a cocky slug looks first, a drowsy one follows |
| Soft landing | Hop, recovery | Ground squash on contact: kick the squash spring, with a bigger landing press than take-off. Recover over about 0.4 s | Grove: 0.36 take-off, 0.10 s hold, 0.50 landing, 0.38 s recovery | Press, recovery time, wobble |
| Eye and mouth expressions | Inspect, idle, reactions | Lip and lid bones travel by mood spring, so one mouth morphs and nothing is swapped. O shape leads the flame | Inferno `stepFace`, `Flow`. Floppy `FloppyFace` | Which expressions exist at all: Inferno never blinks, Floppy blinks slowly |
| Follow-through | Antennae, tails, wings | `stepChain`: each joint chases the one before. Whip is driven by the speed of the body, not by time | Inferno `antennae`, tail chain. Floppy `lag`, `tip` | Damping: 0.35 whips, 0.5 flops |
| Grounded wiggle | Grounded acting | Sole fixed; lower body barely turns; bend rises up the spine with each part behind the last | Floppy `BEND_LOWER` 2°, `BEND_UPPER` 11°, `BEND_HEAD` 7° | Amplitude and rate |

## Tunes

From the running code. Hz is the kit's `freq`; Inferno's code gives stiffness in 1/s, which is the same as Hz × 2π. All names exist in `MotionKit.Tunes`.

| Tune | Hz | Damping | Feel | Source |
| --- | --- | --- | --- | --- |
| `floppySquash` | 5.00 | 0.26 | Jelly wobble | FloppyIdle, SlugIcon-derived |
| `floppySway` | 3.40 | 0.42 | Loose sway | FloppyIdle |
| `floppyLag` | 2.60 | 0.34 | Trailing head | FloppyIdle |
| `floppyTip` | 2.20 | 0.40 | Trailing tip | FloppyIdle |
| `floppyPitch` | 1.80 | 0.80 | Slow nod | FloppyIdle |
| `floppyFlop` | 2.40 | 0.50 | Antenna flop | FloppyIdle |
| `floppyStand` | 2.20 | 0.80 | Rising to stand | FloppyIdle |
| `infernoLook` | 0.95 | 0.80 | Watching you | InfernoMotion |
| `infernoRise` | 3.18 | 0.80 | Quick lift | InfernoMotion |
| `infernoCrouch` | 2.86 | 0.60 | Snappy crouch | InfernoMotion |
| `infernoFlip` | 4.14 | 0.90 | Fast, firm turn | InfernoMotion |
| `infernoChin` | 1.91 | 0.60 | Chin up | InfernoMotion |
| `infernoWhip` | 1.43 | 0.35 | Antenna whip | InfernoMotion |
| `infernoWhipTip` | 1.11 | 0.40 | Whip tip | InfernoMotion |
| `infernoMood` | 0.88 | 1.00 | Mood, no overshoot | InfernoMotion |

**Unresolved:** the two scripts integrate differently (Inferno substeps at 240 Hz, the kit and Floppy step at 120 Hz). At these stiffnesses the difference should be small, but it has not been measured on a rig, so re-judge a tune after moving it.

## Rig coverage

From the exported models. A recipe needs these bones or an equivalent; check before reusing it. Future slugs should keep these names where the anatomy allows.

| Bones | Floppy | Inferno base | Inferno dragon |
| --- | --- | --- | --- |
| `root`, `head`, `antenna_L/R`, `lid_L/R` | Yes | Yes | Yes |
| `body_lower`, `body_upper` | Yes | Yes | No |
| `antenna_tip_L/R` | No | Yes | Yes |
| Mouth | `mouth_L/R`, `mouth_low` | `mouth_t0-8`, `mouth_b0-8`, `mouth_tail_L/R` | Same as base |
| `eye_L/R`, `gaze_L/R` | Yes | No | No |
| `jelly_L/R/F/B` | Yes | No | No |
| `wing_L/R`, `wing_tip_L/R`, `tail_1-3`, `flame_*` | No | No | Yes |

## Motion each new slug needs

Use this as the checklist when a slug enters production. A row only needs a director round if it is a new performance.

| Motion | Shared part | Species part | Judge from |
| --- | --- | --- | --- |
| Idle | None | Everything; it is the personality | Hotbar, chamber, grove |
| Loaded idle | Sized for the chamber | Small readable motion | First person |
| Inspect | Gun toss, catch and timing in `SlugInspect` | The slug's act | First person |
| Shot and flight | Flight curve | Pose in flight | Shooter's view |
| Transformation | Twirl, glow and reveal in `TransformationStyles` | Colours, form size, the form's own motion | Shooter's view at real range |
| Landing and recovery | Ground check and lifecycle | The act | Third person |
| Reactions | Notice logic in the grove | Greeting | Third person |
| Ability acting | To be designed | To be designed | Both |

Floppy never transforms.

## Decisions

Newest first. Only what changes what we would do next; full stories are linked.

| Date | Motion | Outcome | Why, in the owner's words where recorded | Carry forward |
| --- | --- | --- | --- | --- |
| 2026-11-04 | Floppy under-eyes and antennae | Rejected, restored | "original design with the flat bottom" | A local defect does not license a redesign of accepted features |
| 2026-11-04 | Floppy loaded wiggle | Accepted direction | Lower body stuck to the cap, upper half wiggling | Do not shift the whole creature to counter the head |
| 2026-11-04 | Inferno breath effort | Direction | Lungs and torso prepare; belly silhouette must expand | A torso lift alone does not read as an inhale |
| 2026-11-04 | Inferno inspect | **Approved** | Notes record the owner explicitly approving Burpy's (Inferno's) animation | Leave it alone |
| 2026-11-03 | Inferno inspect concepts | **Approved C of three** | "I like the playful flame a lot ... it's perfect" | The director process came from this: the owner chose from three real previews |
| 2026-11-03 | First flame | Rejected | "just like a PNG" | A shape needs to evolve; two rigid hops are not a spring hop |
| 2026-11-03 | Transformation explosion | Rejected | "I like the initial glowing"; dislikes the explosion | Keep the gradual glow, the horizontal twirl and the reveal. Shared base with small species changes. Owner's verdict on the current version is pending |
| 2026-11-03 | Grove hop | Direction | "spring up" means compression, hold, stretch, cushioned landing; "splat" is body deformation | No wet effects on the floor |
| 2026-11-02 | Floppy elaborate hop and bum shake | Rejected | "horrible"; "It already does it in the HUD" | Reuse an approved motion when pointed at it. A small readable gesture beats an ambition in a chamber |
| 2026-11-02 | SlugIcon performances | Liked | "transitional, alive, emotional and smooth"; not "choppy animations cutting to each other" | Springs, no clips |

Sources: [Inferno inspect studies](inferno-inspect-studies.md), [transformation](transformation-system.md), [inspect revisions](inspect-revision.md), [design language](owner-design-language.md).

## Blender poses

**Considering.** Blender pose assets are not built yet, because the accepted motion is Luau and there are no accepted Blender poses to extract apart from Floppy's generated idle. Start a pose library once a slug has accepted authored clips, and tag each pose with its rig ID in [the rig contract](rig-specification.md).

# Slug design record: Aquabeek

**Confirmed, 2026-11-05:** water clears fire, so Crashwave and Mistbank put out Fire Curtain and burns. Electricity amplifies water effects.

## Implemented - three visual prototypes, awaiting owner review, 2026-11-10

**Owner request:** "a unique design that still resembles the original thing and has a build similar to Inferno", applying the Inferno and Floppy lessons; three different prototypes to compare. The owner supplied screenshots of the franchise slug's base and transformed forms as study material; they are not stored here and have no reuse rights.

All three use Inferno's accepted body plan (upright, slight forward lean, no arms or feet, pooled base, short tail) as signed-distance concept pages, built from one template by [`build_aquabeek_concepts.py`](../../../tools/slugs/build_aquabeek_concepts.py). Pages and turntable frames are under [evidence/aquabeek](evidence/aquabeek/).

| Prototype | Base form | Transformed |
| --- | --- | --- |
| A Crestfin | Webbed two-point fin-ears (Inferno's ear sweep), dorsal fin, wave-edged belly, round eyes, two-tooth open smile, droplet freckles | Marlin-dragon: bill, pectoral fins, sail, crescent tail |
| B Gillbeak | 8% wider; three gill frills a side, back fin nubs and ripple rings, side-eye with one heavier lid, single tooth | Eel-dragon: short flat bill, ribbon fin, paddle tail |
| C Breaker | Slimmer, more lean; forward-curling wave crest, glowing aqua irises, fangs at the corners, narrow belly | Manta-swordfish: broad flapping wings, long bill, the crest carried over |

**Kept familiar:** blue/teal two-tone, pale belly, head fins, big round eyes, toothy open grin. **Avoided:** the reference's upright notched fins, straight belly panel, buck-tooth gap and arm-like side fins. **Unresolved:** owner choice; B's back rings may read as a target from directly behind; name/IP check; Blender build and Roblox look.

## Implemented - B base form reworked on Inferno's body, awaiting owner review, 2026-11-12

**Owner picked B (Gillbeak)** and supplied a reference to make it "more feminine, unique, and cool"; the face (slanted almond eyes, eyeliner flick, sly smile, forehead drop) followed the reference and is kept. **Current base form:** Inferno's body plan with a forward lean and lobed pooled base; short, broad, smooth top fins and three small side fins, all sweeping back (the owner rejected webbed fans, then the tall horn-like top fins, on 2026-11-12), on a domed head on a teal hood that blends into the face; a low belly with a wave-crest top blended the same all round, and a bold outlined drop-and-ripples emblem with splash droplets; a shortened tail; a face sculpted like Floppy's (eye openings under heavy rolled lids with real eyeballs, a muzzle, a carved smile; since 2026-11-12 a centred sweet smile with tinted blue-violet lips, a cupid's bow and a glossy lower lip) after the owner said the eyes looked painted on; a belly that curves with the body; a low dorsal fin and a short tail with a fluke. **Current eyes, 2026-11-12:** matched to the owner's reference after three options (Cat-eye, Sultry, Fierce) read as too alike: wide open almonds with a lifted outer tip, a big teal iris, a bold liner wing, under a heart-shaped hood. Later the same day: a living iris (fibres, collarette, breathing round pupil, highlight overlapping it) and blended violet-to-teal eyeshadow in place of the lid band. **Unresolved:** the transformed form still has the old round eyes and dolphin-like head; owner review of the reworked base. Evidence: [B page](evidence/aquabeek/b/aquabeek-b.html) and frames.

## Confirmed - final ability choices, 2026-11-04

**Owner:** "that's final" and "Make those final", referring to **Crashwave** as the main and **Mistbank** as the passive (spoken as "Crushwave" / "Miss Bank"). These are final ability selections, not merely preferred prototype candidates.

- **Player-hit main - Crashwave:** the directly hit opponent takes damage, then a compact wave continues along the shot line and damages opponents in its path. It works independently; later targets can avoid the advancing crest.
- **Surface-hit passive - Mistbank:** a floor, wall or ceiling impact places a short-lived water-mist cloud that obscures both teams. It supplies sight control without another slug and does not block shots or deal damage in the selected concept.

Keep these cores. Exact damage, travel speed/range, cloud size/lifetime, tuning, production effects, final creature designs and native implementation remain open. That distinction does not reopen the owner's ability selection. The current viewer exposes only these two Aquabeek choices; unselected options remain historical. The next creature study is [Arachnet](arachnet.md).

## Confirmed - owner direction, 2026-11-04

Aquabeek is one of the [14 intended slugs](../ability-planning.md). The owner requested multiple ability ideas, using a blank small slug and blank transformed form because neither visual design exists yet. The placeholders demonstrate shot timing, scale and effects; they are not a proposed final creature design or a Blender/Roblox asset.

Develop versatile player-hit and passive effects that can interact with the roster, including Inferno's confirmed Backdraft. The earlier water-orb, puddle/electricity and multi-target-gathering examples remain inspiration. Offer alternatives and select the strongest fit rather than assuming an earlier example must be implemented.

**Owner clarification, 2026-11-04:** distinguish a player-hit effect from a **passive ability triggered by hitting floors, walls or ceilings**. Main and passive effects have separate comparison tabs; all three surface orientations can be reviewed. Aquabeek's two cores are now selected above; numerical balance and implementation remain open. [Shared rule](../ability-planning.md#confirmed---player-hit-effect-and-passive-surface-ability).

## Confirmed - replace the main concepts and explore passive options

**Owner feedback, 2026-11-04:** none of Undertide, Spillover and Waterline is satisfactory as the main ability. Spillover is too complex; Waterline is disliked as a weak/uninteresting ability; Undertide has a promising idea but depends too much on another slug instead of being useful alone. The owner corrected their initial general complexity concern: do not summarize this as simply rejecting all complexity. Presentation also needs to communicate what an ability does more clearly.

The owner requested modelling Inferno's confirmed floor/wall/ceiling fire in the artifact, replacing Aquabeek's main ideas and introducing separate passive alternatives. Main candidates must provide an immediate useful solo outcome. Chaining should add value rather than supply the entire payoff. The owner subsequently selected Crashwave and Mistbank as recorded above.

## Historical - player-hit comparison leading to the final choice

| Main ability | Standalone result | Proposed response |
| --- | --- | --- |
| Pressure Orb | Direct impact plus a brief slowing water orb that deals pressure damage itself. | Shoot the membrane or have a teammate break it early; the target retains actions and the orb expires. |
| Crashwave | The directly struck opponent takes damage; a compact wave continues down the shot line and damages others in its path. | Later targets can sidestep or jump the visible crest. It does not track opponents. |
| Geyser Strike | Direct damage plus a short upward water eruption that interrupts the struck opponent's route. | Air-steer after the initial hit to vary the landing and avoid predictable follow-up aim. |

Crashwave was selected; Pressure Orb and Geyser Strike were not. Numerical balance, break/crowd-control rules for unselected concepts and partner effects were not fixed by this comparison. Preview health bars show relative scripted outcomes, not chosen game damage values.

## Historical - passive comparison leading to the final choice

| Passive ability | Floor | Wall | Ceiling | Independent use / answer |
| --- | --- | --- | --- | --- |
| Rainwell | Shallow soaking/slow patch. | A short pouring sheet with a local wet zone. | A downward pouring zone. | Slow a crossing without a partner; players can take a dry edge or leave. No gathering/pull. |
| Pressure Vent | A marked upward water pulse. | A pulse outward from the surface. | A downward pulse. | Surface orientation controls displacement; a visible charge gives time to avoid it. Ally mobility and exact strengths remain proposals. |
| Mistbank | A low mist bank. | Mist at the wall impact. | A hanging mist bank below impact. | Obscure a sightline for both teams; players can flank or fire through. No automatic damage or shot blocking. |

Mistbank was selected; Rainwell and Pressure Vent were not. Optional elemental/team combinations remain proposals. No partner is needed for Mistbank's sight-control result.

## Confirmed - feedback and next exploration, 2026-11-04

The owner liked the initial Undertow and Breakwater concepts but questioned their fit for Aquabeek. Gathering opponents could fit a tornado/wind slug such as Tormato, and a defensive screen felt too basic and potentially better suited to another slug. **This does not assign Undertow to Tormato or select any other slug's kit.** The owner then requested exploring Undertide, Spillover and Waterline: water attaching, transferring and flowing with terrain. This authorizes concept comparison, not a final ability choice.

## Historical - water-identity main concepts not selected

| Study | Candidate core | Tactical choice and answer | Potential chains, still proposals |
| --- | --- | --- | --- |
| Undertide | An impact drench rides on the target until their next jump/dash sheds it at departure, leaving water on the ground. Ordinary movement carries it; there is no pull or movement lock. | Threaten a follow-up and anticipate the water drop. The opponent can first walk to a safer location, then shed it away from a useful route, or let the mantle expire. | An electric shot might exploit the mantle or patch; ice might freeze the patch; Backdraft could reposition its carrier. |
| Spillover | A later impact knocks a finite share of the target's water along the new strike direction, coating a nearby opponent or landing beyond on the ground. Water is redistributed, not generated by every hit. | Line opponents up and choose the follow-up angle. The second target can sidestep; the splash has short reach and no tracking. | Backdraft could combine displacement with directional transfer. A later electric/ice effect might exploit the new wet location. |
| Waterline | Terrain impact releases a finite downhill surge that follows connected ground and collects in a low spot. | Aim above a useful low route. Opponents can use the dry high bank, leave the basin or stand on a disconnected surface. No suction or homing. | Electricity might follow connected wet ground; ice might trace the same route. Neither implies a final Tazerling/Frostcrawler kit. |

These three have been removed from the active viewer following the owner's feedback above. Retain them as history, not recommended current main kits. Their earlier terrain paths and volume shares were authored illustrations, not a physics/fluid solver or native gameplay.

**Historical assistant evaluation, superseded by owner feedback:** Spillover was recommended for aim-dependent setup, with Undertide's dependence and Waterline's geometry constraints noted. The owner did not accept that recommendation; do not carry it forward as the current choice.

## Considering - historical first four studies

| Study | Candidate core | Tactical use and counterplay | Possible partners, not selected interactions |
| --- | --- | --- | --- |
| Undertow | An impact basin briefly draws grounded opponents inward, then settles into a wet area. | Spoil spacing or prepare an area attack. Jump/dash out during the short pulse; no continuous prison. | Backdraft pushes into the basin; Tazerling might conduct across connected water; Frostcrawler might freeze it. |
| Slipstream | Impact lays a short directional water current usable by both teams. | Open a route or carry a crossing opponent away from cover. Players can leave through the sides or exploit the current themselves. | Backdraft pushes along the current; freezing it into an ice lane is a possible Frostcrawler interaction. |
| Breakwater | Impact raises a curved water screen that slows crossing projectiles from either side while players pass freely. | Cover a crossing and change a lane's timing. Flank, walk through or wait; the owner's own shots slow too. | Frostcrawler might turn the screen into temporary breakable cover. |
| Washout | A compact impact surge extinguishes burns and clears compatible loose clouds, leaving water. | Clean a teammate or route. Poor placement can also cleanse an enemy and remove your existing fire pressure. No healing or universal cleanse implied. | A clear lane may support a Boon Doc recovery play; remaining water could support Tazerling. |

These first four are retained as historical alternatives. They are not the active viewer options and none was selected. Undertow and Breakwater feedback is recorded above; Slipstream and Washout were not selected either. None is a fusion shot or an implementation of another slug's final ability.

## Implemented - local concept presentation only

Local viewer: `build/slugs/inferno/ability-concepts-20261104/Slugshot-ability-lab.html`. The previous `Inferno-five-abilities.html` path opens the same updated viewer. Aquabeek now has only **Crashwave** in its main tab and **Mistbank** in its passive tab, both marked confirmed, using neutral small/large forms. Inferno's confirmed pair is preserved. [Arachnet proposals](arachnet.md) are the new exploration. Passive mode includes floor/wall/ceiling selection and counterplay. The earlier six-option comparison is checkpointed under `checkpoints/aquabeek-final-selection`; the selected effects' rendering source is preserved unchanged.

No Aquabeek model, rig, export, private upload or native gameplay code has been authored in this pass. Browser evidence is distinct from Studio behaviour and owner art/ability selection.

**Current local verification, 2026-11-04:** `check-arachnet.mjs` passed 480 finite samples across the updated viewer, selected-pair visibility and controls, Crashwave direct/secondary damage and secondary evasion, Mistbank obscuring/clearing, and a 390-pixel layout. Report/captures are in `qa-arachnet/`. Selected water-effect rendering source matches the pre-change checkpoint byte-for-byte. Browser evidence does not establish native gameplay or final balance.

**Historical verification:** the first four-study viewer passed 120 finite samples and controls/mobile checks (`qa/`). Water-identity evidence is in `qa-water-identity/`; the six-option main/passive comparison is in `qa-direct-passive/`. Old reports do not verify new viewer routing.

**Historical implementation/verification, 2026-11-04:** the water-identity version passed 96 finite samples, controls/mobile checks and its scripted shedding/transfer/runoff assertions. Report and captures remain in `qa-water-identity/`, with four 48-frame sequences under `motion/`. Those concepts are now superseded; the evidence remains valid for that historical version only.

**Implemented/verified locally, 2026-11-04 - main/passive replacement:** `check-impact.mjs` passes 384 finite geometry/pose samples across player-hit and floor/wall/ceiling scenarios, both outcomes, main/passive/species/surface controls, playback/beat/speed/camera controls and a 390-pixel page layout without horizontal overflow. Scripted checks verify each main has solo damage, breaking the orb reduces its later damage, wave secondary damage can be evaded, the geyser lifts, Inferno fire burns exposed targets on all three surfaces, and the new passives independently slow, displace or obscure. Report and review captures are retained in `qa-direct-passive/`. These are local concept checks, not selected balance, production art approval, physical simulation or Studio evidence.

## Reference context

Water-species identity follows the prior Slugterra shortlist: [Aquabeek reference](https://slugterra.fandom.com/wiki/AquaBeek). No franchise mesh, texture or character image is used for the neutral placeholders. Future final art follows the [style guide](../../art/style-guide.md) and [creature procedure](../../../.agents/skills/slugshot-creature-production/SKILL.md).

## Unresolved

Final small/transformed designs and name; numerical timing and balance; production VFX; detailed roster interaction rules; implementation and Studio/multiplayer/device evidence. Crashwave and Mistbank are selected.

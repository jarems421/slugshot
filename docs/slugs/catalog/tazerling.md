# Slug design record: Tazerling

## Confirmed - Chain Lightning and Livewire, 2026-11-05

**Owner:** first asked for a Chain Lightning and Static Mark combo, then withdrew it: "Let's just do chain lightning. And live wire." **Chain Lightning is the selected main** with no reveal, and **Livewire the selected passive**, because it "could be used to like electrify water". The owner accepts that Livewire resembles Inferno's surface fire because they plan to change Inferno's passive. Static Mark, Surge, Charge Pad and Arc Sensor are no longer active options.

**Confirmed, 2026-11-05:** arcs need a visible target, so they cannot find someone hidden in Mistbank. Electricity amplifies water effects.

**Unresolved:** exactly how Livewire electrifies water and which water effects count, numbers, production effects, final forms and native implementation.

## History - six proposals, 2026-11-04

The owner asked for the next slug after finalizing Frostcrawler; the assistant picked Tazerling. Visual design is open. All avoid another movement bind, per the [roster rule](../ability-planning.md#who-already-does-what). Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Chain Lightning | Main | Hit deals damage, then arcs to nearby opponents for reduced damage | Spread out or use cover; a lone target gives no jump |
| Surge | Main | Hit deals damage and briefly boosts the shooter's speed | Hold the angle or break sight; target keeps moving and firing |
| Static Mark | Main | Hit deals damage and briefly reveals the target through cover to the team | Keep moving or wait it out |
| Livewire | Passive | Surface hit leaves a small patch that damages opponents who touch it | Go round |
| Charge Pad | Passive | Surface hit leaves a pad; touching it gives one short speed boost, then it is spent. Either team can use it | Avoid it, or take it yourself |
| Arc Sensor | Passive | Surface hit plants a sensor that briefly reveals an opponent entering a small radius | Break it or go round |

## Assistant's view before the choice, 2026-11-05

Opinion from the lab and the roster, not a playtest or an owner decision. The owner chose differently on the passive.

- **Recommended pair:** Chain Lightning + Charge Pad.
- **Chain Lightning overlap:** it would be the third group-hitter after Crashwave and Iceburst. What separates it is that it travels between people. Suggested change: arcs need clear line of sight, not visibility, so a shot can find someone hidden in Mistbank.
- **Surge:** the only main that rewards the shooter's movement, but it has no visible effect on the target and doubles up with Charge Pad.
- **Static Mark and Arc Sensor:** reveal is unused so far, but seems to belong to Phosphoro.
- **Livewire:** repeats Inferno's surface fire.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` passed 952 finite samples across every slug, Tazerling mechanics and counterplay, floor, wall and ceiling contact, and a 390-pixel layout. Captures: ignored `build/slugs/ability-lab/qa/`. Browser demonstrations with placeholder players are not physics, balance or Studio evidence. No native combat or model is changed.


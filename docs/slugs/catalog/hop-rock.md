# Slug design record: Hop Rock

Explosive reference.

## Confirmed - Sticky Bomb main + Mine passive, 2026-11-05

**Owner, 2026-11-05:** "Okay, I like the mine and sticky bomb. And then I like terrify and decoy."

| Ability | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Sticky Bomb | Main | The slug sticks to the target and explodes a moment later, hurting anyone close | Run away from your teammates |
| Mine | Passive | A mine on the surface explodes when an enemy comes close | Walk around it, or shoot it |

The owner chose Sticky Bomb over the recommended Fuse, knowingly adding a fourth group-hitter. The proposals below are history.

## History - proposals, 2026-11-05

The first round. Visual design is open. Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Fuse | Main | The hit lights a fuse on the target; hit them again before it burns out and it explodes for big damage | Break line of sight or dodge until it burns out |
| Sticky Bomb | Main | The slug sticks to the target and explodes a moment later, hurting anyone close | Run away from your teammates |
| Mine | Passive | A mine on the surface explodes when an enemy comes close | Walk around it, or shoot it |
| Blast Hop | Passive | A small blast launches anyone standing close, for blast-jumping | Shoot the player in the air |

## Assistant's reasoning

Recommended pair: **Fuse + Mine**.

- **Fuse** rewards landing two hits in a row, which nobody else does, and only your own second hit sets it off.
- **Mine** is the familiar trap; nobody lays traps yet. It answers a route the way Stink Cloud answers healing.
- **Sticky Bomb** is familiar but repeats group-hitting (Crashwave, Iceburst, Chain Lightning). **Blast Hop** is the movement option, close to Gas Jet.
- **Element rule, Considering:** explosions break cover (Ice Wall, rock cover) and set off gas.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers these options and their answers. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

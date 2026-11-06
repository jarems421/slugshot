# Slug design record: Phosphoro

Light reference.

**Confirmed, 2026-11-05:** light is immune to elements; the counter to Flash and Lantern is playing smart, such as turning away. Owner: "light shouldn't really have a counter. Is counter would just be like turning around to not look at the flash or not look at the light bulb thing, whatever. Similar with like ... freight. I mean, so yeah, light and freight shouldn't really have a counter. They're their own kind of category. Where your counter is you playing smart."

## Confirmed - Flash main, 2026-11-05

**Owner, 2026-11-05:** "For Vine draw let's do tangle and bramble. Tangle and bramble seems good. or phosphorus, I like the flash but I don't like any of the passives, to be honest. For the stinky guy, I like the passive one where it's like a gas stink cloud, but I don't like any of the mains. Because they're too similar to the stink cloud."

**Flash:** the hit bursts into a bright flash that blinds the target for a moment. Answer: dodge it, or back off until you can see. The owner rejected Beacon and Lightstep, so the passive is open.

## Confirmed - Lantern passive, owner's idea, 2026-11-05

**Owner:** "maybe for phosphorus. The passive could be shoot up into the air. Or shoot into the ground, or shoot to the wall. And anyone, and it reveals like a light. And anyone that looks at it then gets revealed. Behind walls like their outline. Or anyone hiding, like anyone that looks at it just gets revealed to the opposite team."

**Lantern** (working name): hitting a surface leaves a light; any enemy who looks at it has their outline shown to Phosphoro's team, even through walls. Answer: look away, or shoot it out. Confirmed after the owner clarified "into the air" as the ceiling.

**Confirmed, 2026-11-05:** "shoot into the air" meant hitting the ceiling; Lantern works on floors, walls and ceilings like any passive.

## History - second-round passives, rejected 2026-11-05

**Owner, 2026-11-05:** "I don't like any of the new ideas you gave for either one." The round below is rejected and kept as history.

| Option | What it does | Answer |
| --- | --- | --- |
| Mirror | The hit spot becomes a mirror; any slug that hits it bounces off | Stay out of its angles; enemies can use it too |
| Glare | A bright light blinds anyone who looks straight at it | Look away, take another route, or shoot it out |
| Tripwire | A beam of light across the surface flashes the first enemy to cross | Spot it and shoot its end, or go another way |

Recommended: **Mirror**. Trick shots around cover are pure skill, nobody else bends shots, and it is a different thing from Flash. Glare and Tripwire are area versions of Flash, which may feel too similar, as Flatulorhinkus's stink mains did.

## History - first-round proposals, 2026-11-05

Flash was picked from these. Visual design is open. Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Flare Mark | Main | The target glows, and your team sees them through walls for a while | Dodge it; once lit, fight where being seen does not matter |
| Flash | Main | A bright flash blinds the target for a moment | Dodge it, or back off until you can see |
| Beacon | Passive | A glowing light reveals enemies near it through walls | Shoot it out, or stay out of its light |
| Lightstep | Passive | You flash to where the slug landed | Aim at the landing spot before they arrive |

## Assistant's reasoning

Recommended pair: **Flare Mark + Lightstep**.

- **Flare Mark** takes the open reveal job, which suits light. **Beacon** is its area version, if the owner prefers reveal on both.
- **Lightstep** is a movement passive, and instant, unlike Silkline, Updraft or Bloom Pad.
- **Flash** is familiar from hero shooters but blinding can feel frustrating to play against.
- **Element rule, Considering:** light dispels illusions, which would link to Frightgeist; a lit target cannot hide in Mistbank.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers these options and their answers. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

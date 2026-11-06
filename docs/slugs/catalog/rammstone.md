# Slug design record: Rammstone

**Confirmed, 2026-11-06:** full spec in [ability specs](../ability-specs.md#rammstone---confirmed-spec-2026-11-06). Shove Punch's knockback grows with charge; rock cover is 8 wide, takes 8 hits, is immune to fire, one at a time.

## Confirmed - owner's direction, 2026-11-05

**Owner:** a basic, strong punching slug. On a player "it would just more so punch you. Like that would literally just be it." Its usefulness comes from the passive:

- **Shoot the ground** to punch a rock wall up as cover, as the ice slug can.
- **Punch out parts of the map:** shoot an arch above and rock falls to cover a pathway; shoot a spire on top and it comes down and damages an opponent.

Maps will be modelled around this rather than the ability fitting an existing map.

**Confirmed main, 2026-11-05: Shove Punch**, a strong punch with a short knockback. Plain Punch was the alternative the assistant had recommended; the owner chose the shove. The passive's working name is Rockbreak, which is the assistant's name and not yet approved.

**Confirmed plain surfaces, 2026-11-05:** a hit on a plain wall or ceiling "should probably just shoot down or like release a bit of rubble. That does a slight little bit of damage. To anyone below it." Someone wall-running on the struck wall gets "knocked off". This makes every shot useful and rewards hitting wall-runners.

## Unresolved

The passive's name; how rock wall differs from Ice Wall beyond being stone. Numbers and balance come later.

## History

**Rejected, 2026-11-05:** Battering Ram, Momentum, Breakthrough, Rockfall, Upheaval and Stonestep ("I don't really mess with any"). Source: `tools/slugs/ability-lab/history/before-rockbreak`.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers the punch, dodge, cover and flank, arch block and beating it, and spire hit and dodge. See `build/slugs/ability-lab/qa/`. Browser demonstrations with placeholder players are not physics, balance or Studio evidence. In the lab, the Wall button stands for an arch and the Ceiling button for a spire.

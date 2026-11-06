# Slug design record: Vinedrill

Plant and vine reference.

## Confirmed - Tangle main + Bramble passive, 2026-11-05

**Owner, 2026-11-05:** "For Vine draw let's do tangle and bramble. Tangle and bramble seems good. or phosphorus, I like the flash but I don't like any of the passives, to be honest. For the stinky guy, I like the passive one where it's like a gas stink cloud, but I don't like any of the mains. Because they're too similar to the stink cloud."

| Ability | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Tangle | Main | Vines wrap the target, so their next slug comes out small and slow and cannot transform | Wait for the vines to drop before shooting back |
| Bramble | Passive | A thorny patch slows anyone walking through, without damage | Walk around, jump over, or burn it |

The owner chose these over the recommended Drill Through + Bloom Pad. The proposals below are history.

## History - proposals, 2026-11-05

The first round. Visual design is open. Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Drill Through | Main | The slug drills through one piece of cover and still hits the player behind it | Two layers of cover, or keep moving |
| Tangle | Main | Vines wrap the target, so their next slug comes out small and slow and cannot transform | Wait for the vines to drop before shooting back |
| Bloom Pad | Passive | A springy flower launches anyone who steps on it forward; from a wall or ceiling it grows on the floor below | Shoot the player in the air, or use it yourself |
| Bramble | Passive | A thorny patch slows anyone walking through, without damage | Walk around, jump over, or burn it |

## Assistant's reasoning

Recommended pair: **Drill Through + Bloom Pad**.

- **Drill Through** answers cover, the most crowded job (Ice Wall, rock cover), and suits a drill. It is a plain hit plus one thing.
- **Bloom Pad** is the open ground-boost job, a movement passive the owner tends to prefer. Updraft goes up, Silkline pulls to anchors, Bloom Pad launches forward.
- **Tangle** weakens an enemy's attack, a new job, but it is close to the Windbreak rule. **Bramble** is a slow without damage.
- **Element rules, Considering:** fire burns plants (Inferno clears Bramble and Bloom Pad); water grows plants.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers these options and their answers. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

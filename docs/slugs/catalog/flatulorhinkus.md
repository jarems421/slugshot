# Slug design record: Flatulorhinkus

The stinky gas slug.

## Confirmed - Stink Cloud passive, 2026-11-05

**Owner, 2026-11-05:** "For Vine draw let's do tangle and bramble. Tangle and bramble seems good. or phosphorus, I like the flash but I don't like any of the passives, to be honest. For the stinky guy, I like the passive one where it's like a gas stink cloud, but I don't like any of the mains. Because they're too similar to the stink cloud."

**Stink Cloud:** hitting a surface leaves a stinking cloud where nobody can heal; from a wall or ceiling it sinks to the floor below. Answer: fight outside it, or heal elsewhere. Reek and Nauseate were rejected as too similar to the cloud, so the main is open.

## Confirmed - Nausea main, owner's idea, 2026-11-05

**Owner:** "His main could be when you shoot it. Leaves like a sick nauseating effect on you. That makes it so the next slug you shoot doesn't transform. And so it shoots really slow and does less damage. And so it's either you firm that shot or you wait for the effect to run out."

**Nausea** (working name): the hit leaves the target sick, so their next slug cannot transform, flies slowly and does less damage. Answer: wait for it to wear off. Shown in the lab.

**Owner, 2026-11-05:** "I don't care if the idea is the same for the nausea and tangle. We'll make it different." Both keep it; the [detailed pass](../ability-specs.md) will separate them.

## History - second-round mains, rejected 2026-11-05

**Owner, 2026-11-05:** "I don't like any of the new ideas you gave for either one." The round below is rejected and kept as history.

None of these makes a cloud.

| Option | What it does | Answer |
| --- | --- | --- |
| Rebound | Landing a hit blasts you backwards on a burst of gas, away from the target | Don't chase into the open, or dodge so they get no escape |
| Horn Charge | Landing a hit sends you charging at the target, like a rhino | Back off, or punish the charge |
| Gross Out | For a while, the target's shots do nothing on surfaces, switching off their passive | Wait it out, or use direct hits |

Recommended: **Gross Out**. It is a new job (switching off passives), it is not a cloud, and it suits being disgusted. Rebound and Horn Charge are movement on the hit; Horn Charge suits the rhino in the name. An earlier illustrative chain (gas, then Inferno knockback) is not a selected ability.

## History - first-round proposals, 2026-11-05

Stink Cloud was picked from these. Visual design is open. Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Reek | Main | The target stinks, and their teammates near them cough and slow down | Spread out from the stinking player |
| Nauseate | Main | The target's aim sways for a moment | Wait before shooting back, or close in |
| Stink Cloud | Passive | A cloud where nobody can heal; from a wall or ceiling it sinks to the floor below | Fight outside it, or heal elsewhere |
| Gas Jet | Passive | A burst of gas pushes away anyone close to where it lands | Keep away from the landing spot, or use the push yourself |

## Assistant's reasoning

Recommended pair: **Reek + Stink Cloud**.

- **Reek** punishes grouping, the opposite of Tornado, and makes the hit player a problem for their own team. It suits a stinky slug.
- **Stink Cloud** is anti-heal, a familiar hero-shooter tool and the answer to Boon Doc, which nothing else is.
- **Nauseate** overlaps Tangle (both weaken the reply), so only one of the two should be picked. **Gas Jet** is movement, but launch passives are getting crowded (Updraft, Bloom Pad).
- **Element rules, Considering:** fire ignites gas into a burst; wind blows gas away.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers these options and their answers. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

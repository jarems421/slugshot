# Slug design record: Boon Doc

## Confirmed - Mending Shot and Healing Spring, 2026-11-05

**Owner:** "you can shoot your teammate to heal them, or you can shoot at an opponent to heal yourself", combining two proposals into one main. The passive stays healing-based: "I prefer the healing spring just because it's it's a bit more different since it's a spring rather than a individual-based thing", with "the healing capabilities of the passive version lower".

- **Main - Mending Shot:** hit a teammate to heal them; hit an enemy to heal yourself. Like every main it also damages an enemy it hits; that part is the assistant's assumption, carried from Leech.
- **Passive - Healing Spring:** a pool on or below the surface hit. You and your teammates heal while standing in it, less strongly than the main.

Mending Shot and Healing Spring are the assistant's names, kept unless the owner changes them.

**Confirmed, 2026-11-05:** Mending Shot clears burns and binds, so it answers Snapbind, Dragon's Breath and Fire Curtain.

**Unresolved:** numbers; final forms; native implementation.

## History

**Not selected, 2026-11-05:** Leech as a separate main (merged in) and Health Pod. Proposed from the [ability playbook](../ability-playbook.md); kept in `tools/slugs/ability-lab/boon-studies.js`.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers the teammate heal, the self-heal from an enemy hit, cover and dodging, and the spring on floor, wall and ceiling. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

# Ability lab

Animated comparisons of slug abilities: a slug's main (hits a player) and passive (hits a floor, wall or ceiling), each with its tactical use and how to answer it. The current slug being rated is what it opens on.

```powershell
python tools/slugs/ability-lab/build.py   # one offline HTML file: build/slugs/ability-lab/Slugshot-ability-lab.html
node tools/slugs/ability-lab/check.mjs    # checks it and captures options to build/slugs/ability-lab/qa
```

Each slug has its own studies file (`impact-studies.js` holds Inferno and Aquabeek), registered in `preview.js`. A new slug's check belongs in `check.mjs`. Models and Three.js r159 come from `build/slugs` and `.tools/three-r159`, then `../slugshot-slug-pipeline`, or `SLUGSHOT_ASSET_ROOT`; Three's files are checked against pinned hashes.

Before proposing, read the [ability playbook](../../../docs/slugs/ability-playbook.md) and [who already does what](../../../docs/slugs/ability-planning.md#who-already-does-what). Selected abilities and owner feedback live in the [catalogue](../../../docs/slugs/catalog/index.md).

`history/` holds earlier versions and rejected studies as text. They are not built. QA evidence from before the move stays in ignored `build/slugs/inferno/ability-concepts-20261104/`, which is also where notes before 2026-11-05 point.

These are browser demonstrations with placeholder players: they show an idea, not physics, balance or anything in Roblox.

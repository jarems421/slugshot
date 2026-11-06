# Slug design record: Tormato

**Confirmed, owner, 2026-11-06 - Updraft launches away from the surface:** "if u shoot on as wall it laubnches u sideways, if u shoot on floor it launches u up, if u shoot on ceiling it lasunhes u down, if u shoot on diagonal surface is launches u diagonally up". Its gust also pushes Mistbank the same way, and Tornado pulls Mistbank in, "good for [both] counter and amplification".

## Confirmed - owner's direction, 2026-11-05

**Owner:** "It should just be like a tornado main ... more like utility-based, like you can use it to kind of if you shoot it in front of you, then it might slow down slugs so they can't transform or something ... Just make it smart. And make a good passive."

## Confirmed - Tornado main + Updraft passive, 2026-11-05

**Owner:** "I think I like updraft more. But Tornado is good. Yeah, so Tornado and updraft. Because updraft provides a bit more movement. Which I like."

| Ability | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Tornado | Main | The hit leaves a tornado that drags nearby opponents in. They can still walk, aim and fire | Move straight away at the edge, or wait behind cover |
| Updraft | Passive | A rising column of wind on the surface hit lifts anyone who steps in, on either team | Walk around it, use it yourself, or shoot the rider |

- **Job:** Tornado gathers enemies without hitting a group itself, and the drag is not a bind because the target keeps moving, aiming and firing. Updraft is vertical movement, unlike Silkline's anchors and swings.
- **Techs:** drag a group for Chain Lightning, Iceburst or Crashwave; ride Updraft to a high angle; a rider rising in a straight line is an easy shot for anyone.
- **Element rule, Considering:** wind carries things, so a tornado could pick up fire, mist or sparks it passes through.

## History - not selected

The assistant recommended **Windbreak** as the passive: a wall of wind on the surface hit that slowed enemy slugs in flight and stopped them transforming, built from the owner's "shoot it in front of you" idea, because a shot in front of you lands on a surface. The owner preferred Updraft's movement.

**Owner's rule for Windbreak, 2026-11-05**, kept in case it returns: a slug already transformed still goes through the wind, but its first hit does less damage; its ability damage is unchanged. A slug not yet transformed does not transform going through, so its ability does not activate.

## Unresolved

Visual design; how high and how long Updraft lifts; how strong the drag is; whether the wind-carries rule is confirmed.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers Tornado's drag and escape and Updraft on floors, walls and ceilings. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

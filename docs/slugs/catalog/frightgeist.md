# Slug design record: Frightgeist

Fear and illusion reference, normalised from the owner's spoken "Frightfest"; 

## Confirmed - Jump Scare replaces Terrify, 2026-11-05

**Owner:** "let's do a quick change to [Frightgeist]. It's main on impact. It should just do a jump scare. So like it's kind of like a flash, but it's a jump scare."

**Jump Scare:** the hit pops a ghostly face in front of the target, scaring them for a moment, like a flash. No element counters it; the counter is playing smart ("light shouldn't really have a counter. Is counter would just be like turning around to not look at the flash or not look at the light bulb thing, whatever. Similar with like ... freight. I mean, so yeah, light and freight shouldn't really have a counter. They're their own kind of category. Where your counter is you playing smart.").

## History - Terrify main + Decoy passive, 2026-11-05

**Owner, 2026-11-05:** "Okay, I like the mine and sticky bomb. And then I like terrify and decoy."

| Ability | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Terrify | Main | The target runs away from you for a moment | Dodge; once scared, steer toward cover |
| Decoy | Passive | A ghostly copy of you appears on the surface and walks slowly to draw fire | It never shoots; find the real player |

The recommended pair. The proposals below are history.

## History - proposals, 2026-11-05

The first round. Visual design is open. Studies run in the [ability lab](../../../tools/slugs/ability-lab/README.md).

| Option | Kind | What it does | Answer |
| --- | --- | --- | --- |
| Terrify | Main | The target runs away from you for a moment | Dodge; once scared, steer toward cover |
| Phantom Shot | Main | The slug turns invisible halfway through its flight | Keep moving; it flies straight |
| Haunt | Main | Fake ghost players appear around the target, seen only by them | The fakes never shoot; answer whoever does |
| Decoy | Passive | A ghostly copy of you appears on the surface and walks slowly to draw fire | It never shoots; find the real player |
| Vanish | Passive | You turn invisible for a moment, until you shoot | Shoot where they vanished, or use Lantern |

## Assistant's reasoning

Recommended pair: **Terrify + Decoy**.

- **Terrify** is the familiar fear effect, a disruption the owner tends to pick. It takes control away rather than pushing physically like Shove Punch and Tornado.
- **Decoy** is the familiar illusion trick, and it suits the slug. Main and passive do different things.
- **Haunt** is the most original but harder to build (fakes shown to one player only). **Phantom Shot** is simple. **Vanish** is the movement and stealth option.
- **Element rule, Considering:** light dispels illusions, so Lantern and Flash expose Decoy, Haunt's fakes and Vanish.

## Implemented/verified locally, 2026-11-05

`tools/slugs/ability-lab/check.mjs` covers these options and their answers. Browser demonstrations with placeholder players are not physics, balance or Studio evidence.

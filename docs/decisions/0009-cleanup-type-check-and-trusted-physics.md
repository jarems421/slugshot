# ADR 0009: Movement cleanup, full type check and trusted client physics

Date: 2026-10-30
Status: Accepted for the experiment only
Approval evidence: owner, 2026-10-30, after a whole-system review: "do the cleanup pass … with the roll … remove that. We're not going to use the roll on the floor anymore. Remove the dead references, fix outdated notes. Add the full type check … fix the rest of the problems you found from 1 to 10"
Builds on: [ADR 0008](0008-r6-rig.md)

## Context

The review of v7.7 found:

- the ground roll still in the code but unreachable (no key since v5.8);
- references to clips that no longer exist anywhere (start, stop and turn transitions, diagonal sprints, a jog, the hanging climb);
- private clips that were converted but never played;
- notes describing old controls;
- a type check covering one 17-line file of about 6,000 strict lines;
- single-ray ledge detection;
- per-frame waste;
- client-trusted physics with no evidence of how often it would matter.

## Decision

- **No ground roll.** The roll is removed from the client, config, server validation, presentation, original clips and private manifest. The double jump is the only flip.
- **Only reachable code and clips.** Moves, clip names, the flip trail, `OriginalClips.replaces` and manifest entries with no way to play are removed. The private module is regenerated from the trimmed manifest. Aiming stays behind `Config.Lab.Aim` (owner, 2026-10-29: off until aiming is in scope).
- **Full strict type check.** `tools/verify_movement.py` runs luau-lsp over every movement script with a Rojo sourcemap and Roblox definitions. The definitions are pinned to the luau-lsp release in `rokit.toml` (1.70.1, `globalTypes.None.d.luau`, MIT). They are downloaded on demand into ignored `.tools/luau/` and checked against a SHA-256, so CI and local runs use the same file. It is data for the checker; nothing from it executes.
- **Ledge detection** tries forward rays at four heights and three lanes, lowest height first and nearest ray first. It probes the top at 1.2 studs in, then 0.7 for thin tops. The original knee-height centre ray is still tried first.
- **Client physics stays trusted for now.** The server keeps its request checks and horizontal speed cap. It now also counts upward boosts while airborne that no accepted action explains (`SuspectAirBoosts`), without correcting them. Whether the server should own more of movement is left for an explicit decision before PvP.
- **Pose tools in the repo.** `tools/r6pose/` renders literal key tables straight from `OriginalClips.luau`, so the Luau stays the only copy of the poses.

## Consequences

- The public lab has every move with original clips. The private lab adds 21 clips.
- Type errors now fail CI. The first run found 26, all typing gaps; none changed behaviour.
- Detection without correction cannot hurt honest players, but it does not stop cheating either. Its counts from real two-client play are the evidence for the server-authority decision.
- More rays per ledge check: up to 12 forward rays plus top probes per 0.055 s while Jump is held, on the jumping client only.
- Not yet run in Studio: the Studio MCP was not connected in the session that made these changes.

## Addendum (v7.9, 2026-10-30): the light option

The owner chose the light option over server-run movement for now. Clients still own their physics. The server now corrects what nothing explains:

- an airborne upward boost with no accepted action within 0.6 s;
- a path between samples that crosses a solid part, with no mantle or vault around it;
- upward speed over 75.

Corrections snap the character back to the position before the suspect motion. The horizontal speed cap stays. Each correction is counted and can be switched off (`Config.Validation.Corrections`). A client that ignores server teleports is not stopped, which is why the strong option stays open for competitive play.

# ADR 0011: Rocklock V2 redesign and hybrid server-authoritative destruction

Date: 2026-10-31. Status: **Confirmed implementation approach** under the owner's Rocklock V2 brief and addendum; the layout, numbers and art are experimental and await owner playtests.

## Context

The owner asked for a fundamentally better 1v1 cavern (three tiers, meaningful routes, a Slugterra-inspired geological identity) and a destruction foundation that can grow towards "every geological surface can be damaged", while preserving competitive play, performance and the existing map. Every attack must be able to damage every ordinary destructible, via structural health and multipliers rather than permissions. Codex is concurrently iterating the existing Rocklock map.

## Decision

- **Separate, parallel implementation.** New `tools/rocklock_v2`, `experiments/rocklock-v2`, `rocklock-v2*.project.json` (port 34875), outputs `build/SlugshotRocklockV2[Private].rbxlx`. The existing map, its tools and projects are untouched and remain the baseline. The movement server copy changes only the same spawn expression as the existing map.
- **One layout source** (`layout.py`) drives Blender skins, the place, diagrams, previews and verification, including a route graph with `requires`/`opens` links to destructibles.
- **Hybrid destruction.** Native anchored chunks (visible shape = collision) for structures. Blender skins over essential box collision for rock masses (reliable wall-running and mantling). Runtime Terrain in bounded zones over bedrock for craters and tunnels. EditableMesh is rejected: clients refuse it in unpublished places, and it has client memory budgets. Runtime CSG and per-triangle destruction are rejected for cost and networking.
- **Server authority.** The server raycasts from the requesting character's head; clients send only direction, tier and archetype; only registered chunks and zone Terrain change. Rate limits apply per player and to digging globally. Clients render cosmetic debris and warnings only.
- **Round model.** No mid-round regeneration; large rubble is anchored until reset; `Destruction.reset()` restores a pristine clone and Terrain deterministically.
- **Verification** without driving Studio: an offline verifier covers types, routes (intact and fully destroyed), movement limits, data, geometry and isolation; a Studio-only in-game self-test runs on demand.

## Consequences

The map is upload-free, buildable and checkable offline. Terrain is only visible in Play (filled at run time). Native chunks keep destruction exact but make the greybox look blocky until an art pass replaces chunk visuals (for example, Blender-fractured pieces) while keeping simple collision. Runtime behaviour, two-client sync, performance and the acceptance tests are unverified until the owner runs them. Merging, publishing and real slug abilities remain out of scope.

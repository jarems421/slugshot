# ADR 0018: Local slug recovery independent of firing cooldown

Date: 2026-11-01

Status: **Accepted design by the owner; Floppy implemented with offline and limited native Studio verification, 2026-11-01. Owner animation approval pending.**

## Context

The temporary combat implementation has slugs hop back and puff away when the firing cooldown expires. The owner rejected that disappearance. Returning to the blaster also becomes ambiguous when switching slugs; belt capsules may be hidden. Physically completing a distant return within a fixed cooldown would require excessive speed and create distracting traffic with many simultaneous shooters.

## Decision

Recover at the landing site: general slugs land, shake off and burrow. Floppy lands on its belly, wriggles and rolls onto its back (owner follow-up), then makes a small hop and burrows into the ground. The burrow represents returning to inventory.

Firing availability remains governed by the existing cooldown, independently of the cosmetic recovery scene. Recovery can finish naturally instead of being rushed or abruptly removed at readiness. Implement this as a local visual lifecycle, without adding a required visible capsule or changing Terrain.

## Consequences

No map-spanning return route or high-speed recall streak is needed. Switching selected slugs does not redirect a returning creature. Species can express personality in a small recovery animation at the impact site.

The game intentionally abstracts the journey into inventory: cooldown readiness is not proof that the visible creature has physically reached the player. Floppy now falls off character/target impacts before local floor recovery. Exact animation approval and broader surface handling remain unresolved. [Recovery specification and actual evidence](../slugs/recovery.md).

## Addendum, 2026-11-01

The owner set the whole animation, including a new belly skid, to fit a 1.5-second window. Because flight time varies, this is implemented as impact to gone, with an allowed overrun for long falls. Firing availability is still independent and the scene never reads it.

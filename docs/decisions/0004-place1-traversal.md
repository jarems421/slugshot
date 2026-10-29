# ADR 0004: Adapt Place1 traversal detection for mantle and wall hop

Date: 2026-10-29
Status: Accepted for the experiment only; reconsider after owner playtest
Builds on: [ADR 0003](0003-clip-presentation.md)

## Context

The owner asked why the lab was not building on established free movement systems, then chose to adapt parts of the [Place1 movement system](https://github.com/alexkkork/place1-movement-system) (MIT) alongside a later Mixamo upgrade. Of Place1's third-person-compatible features (slide, mantle, wall hop, bunny-hop momentum), the owner selected **mantle/ledge climb** and **wall hop**. Place1 as a whole forces first person, changes gravity, adds stamina and drives the root without server checks, so it was not adopted wholesale.

## Decision

- Port Place1's `ParkourTraversalController` detection at `87da75e2f2528291ebf65c4cbc52d1ce83c2f527` into `experiments/movement/client/Traversal.luau`: the ledge ray layout, clearance box, wall-surface search and `NoParkour`/`NoClimb`/`NoMantle`/`NoWallHop` opt-outs. The MIT copyright and permission notice is kept in that file, so it ships in every build.
- Keep this lab's own architecture: actions are announced through the existing replicated attributes and validated by the server, and presentation stays clip-driven.
- Mantle: Space into a ledge 0.7–5.7 studs above the feet. The root closes to the wall, then follows the clip's `climb` curves (over/up progress), so original or Mixamo clips decide the motion's timing. `MantleLow` (one-hand step vault) is used below 3.2 studs and `MantleHigh` (two-hand climb) above that.
- Wall hop: Space in the air beside a wall kicks away from it, keeping part of the along-wall speed and turning to face the new direction. Up to 2 hops per airtime; each hop restores the flip, so hop → backflip works. An early press is buffered for 0.15 s.
- Server: each traversal request names a world point (stand point or wall contact). The server checks that point against its own geometry and against server-observed positions, polling for up to 0.35 s for replication. It applies the cooldown, hop-count and airborne rules, and validates one action at a time per player, in arrival order.
- Place1's slide, first-person camera, stamina, gravity changes and bunny-hop values are not used.

## Alternatives

Installing the Place1 package would install six controllers, a first-person camera and a gravity change that compete with this lab. Writing detection from scratch would duplicate a reviewed MIT implementation. Roblox's Character Controller Library still requires a beta opt-in that has not been authorized.

## Consequences

Mantle and wall hop parameters live in `Config.Traversal` and are experimental. Mantle hand contact is tuned for typical heights without arm IK, so hands can sit slightly above very low or very high edges. Mixamo climb clips can replace `MantleLow`/`MantleHigh` through the converter's `traversal` mode (verified on synthetic data only). Evidence: [results](../movement-verification.md#v3-traversal-2026-10-29).

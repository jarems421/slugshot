# ADR 0019: One-handed, first-person ADS

Date: 2026-11-01

Status: **Implemented for owner testing. Experimental; feel verdict pending.**

## Context

The owner asked for lightweight, quick Valorant-style aiming with a small clear glass pane showing their chosen crosshair, and asked whether it should be one- or two-handed and how third person should work. The owner earlier rejected a two-handed hold for this pistol as inconsistent.

## Decision

Hold right mouse (or L2) with the blaster out. Aim is **one-handed**. A pod on top of the blaster opens (doors, emitter, prongs) and projects a client-only black frame, with no glass, in the exact shape of the owner's Valorant screenshot: four brackets with gaps at the top, bottom and sides. The normal HUD crosshair stays at screen centre, so the pane frames it instead of adding a second aim point. The mechanism has its own eased clock (0.42 s open, 0.3 s close), and the frame blooms out of the pod while drawing and fading in, so aiming is not held up.

- **First person:** the gun moves to centre below the pane, with a 1.25x zoom matching Valorant's rifles and mouse sensitivity scaled to match.
- **Third person:** no ADS. An over-the-shoulder version was built and the owner rejected it as buggy, so right mouse keeps its normal camera use there.
- **Shots:** ADS changes presentation only. Shots use the same crosshair ray, and there is no spread, damage or movement-speed change.
- **Recoil:** gun recoil is reduced to 30% through the sight. The camera never moves.
- **Actions:** ADS fades out during flips, wall runs and mantles, and holds through slides.

## Consequences

Movement stays frictionless because aiming has no speed penalty, unlike Valorant. That is open to revisit for balance. `experiments/movement/client/Ads.luau` holds the shared state and `Tuning.luau` holds the values. Evidence and limits: [face and ADS](../evidence/2026-11-01-face-and-ads.json).

## Visual mounting correction (2026-11-02)

Owner requested a forward, flat, seated mount and an opening that stays clear of the frame. The revised pod has saddle feet; covers fold down, the hologram draws after clearance, current weld transforms synchronize the visual copy, and the lowering frame fades at the crosshair rather than following the falling gun. A small ADS-only gun drop clears the orange hood; shot aiming and first-person-only policy stay intact. [Evidence and limits](../combat.md#ads-mount-and-clean-frame-opening-2026-11-02). Owner final appearance/feel approval remains unresolved.

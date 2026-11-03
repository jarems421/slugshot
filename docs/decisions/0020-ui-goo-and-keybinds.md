# ADR 0020: UI liquid by texture resampling, and one keybind module

Status: accepted, 2026-11-02. Owner requested the outcomes; the methods are engineering choices.

## Context

The owner wants fluid slime in the UI and complete key and mouse rebinding. Roblox UI has no shaders and snaps to whole pixels. `Position` and `Size` animation of slow liquid stepped visibly, and rotated tiles in a `CanvasGroup` looked "completely corrupted" to the owner. Input was bound in many scripts.

## Decision

- Animate slow UI liquid through `ImageRectOffset` (`Goo`), in thin columns over a ripple simulation, with drips as a rendered flipbook.
- Route rebindable actions through `Keybinds`. Touch and gamepad keep their own bindings, and default movement keys pass through to Roblox's controls until a player moves one.

## Consequences

Hundreds of property writes per frame while visible, so hidden liquid does not run. The textures are private uploads, so each private project needs `private-assets/ui/GooArt.luau`. `EditableImage` could render true per-pixel liquid but needs an experience setting and could not be tested on an unpublished place; revisit if the columns ever show limits. See [PvP UI](../pvp-ui.md).

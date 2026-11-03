# 0021 — Loadout selection and cosmetic inspect

Date: 2026-11-02. Status: Confirmed owner controls; implemented experimental protocol.

## Context

The five-slot HUD and keybind settings existed, but firing, HUD cooldown and slug selection were hardcoded to slot 1. Wheel input entered first person. The owner requested numeric and wheel selection, V for camera mode and species-specific inspect gestures before persistence work.

## Decision

Keep the current carried loadout as the server's allowed set. Add validated `Select` events, retain per-slot cooldowns and require a firing request to match the selected slot. Clients predict cooldown and selection without granting creatures or deciding ownership. Rejection reconciliation addresses the original shot's slot, so a late rejection does not erase another slot's cooldown.

Add `Inspect` and `CancelInspect` cosmetic events. The server sets `SlugInspectAt` in server time on the current character. Each client's existing pose/bone drivers sample it; first-person presentation composes through the viewmodel. This avoids streaming bone frames or altering gameplay physics. A local cancellation hides the gesture immediately, then clears the server timestamp for observers. Respawn receives a fresh character without an inspect timestamp.

All inputs use the existing rebind system. Pin third-person zoom independently of wheel bindings and explicitly toggle first person. Preserve standalone movement labs' key-1 holster action while combat HUDs own slot selection.

## Consequences and limits

No persistence or per-player acquisition service is introduced. A future inventory service must provide the server's carried-slot mapping; the UI and protocol must never treat a client-supplied species as owned. Species models, facial rigs and animations must be integrated separately. Current native tests exercise multiple slots with Floppy copies, not multiple production species. Owner art approval and multi-client testing remain separate gates.

Evidence and reproduction: [loadout controls](../loadout-controls.md).

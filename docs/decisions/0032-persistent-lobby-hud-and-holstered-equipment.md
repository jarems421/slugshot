# ADR 0032: Persistent lobby HUD and holstered equipment

Date: 2026-11-13
Status: Accepted
Approval evidence: owner requested the normal health/canister UI in the lobby and a gun carried on the hip, automatically unequipped and impossible to equip or shoot there. PvP's later team loadout window is separate.

## Context

The training portal disabled CombatHUD in the lobby, hiding its child inventory. The arena deleted blasters outside training, preventing the existing draw/holster animator from showing a gun at spawn. That equipment logic also waited for arena art loading. Number-key slug selection normally equips a carried blaster.

## Options

- Keep deleting the gun and introduce an independent lobby-only prop: duplicates the authored hip presentation and separates it from the carried equipment.
- Retain the carried tool, gate weapon use on the server, and reuse the current hip animator: preserves the equipment identity and approved presentation.

## Decision

Keep the HUD enabled in both zones and retain inventory's existing anchor. A dedicated game-place Equipment script owns carrying, disabling, forced-unequipping and automatic training draw. Arena scripts only own arena travel and respawn placement. The built-in SlugshotLobbyTraining flag restricts weapon use even before arena startup; server-owned InTraining plus the current character's TrainingArrived flag permit it after arena placement. This also keeps a new training character holstered until its respawn warp finishes. Combat and client input use the same predicate, with a second server check after any shot-validation yield. Leaving training clears armed abilities.

The animator uses the replicated StarterPack blaster template to make the initial lobby hip copy for every character, without first drawing the real tool. Lobby visibility overrides the cosmetic Vanish preference while preserving the saved setting. Equipment setup waits for character parenting on respawn. Loaded Floppy's asynchronous sole-fit setup checks that a preview still exists after mesh loading, and its callback cleans up if the preview is destroyed; authored motion stays unchanged. Existing combat-only test places keep their weapon behaviour. Manual holstering for Veylume, ownership/progression, editable loadouts and the PvP draft remain future work.

## Consequences and validation

One equipment owner avoids portal/equip races. Hip copies remain client cosmetics with no collision or gameplay authority. They now resolve the stored template's authored weld frames and show only the character's server-authored SelectedSlugId. Internal skin Motor6Ds are retained; the old character's visual is removed immediately on respawn. This supersedes the initial default-slug-only, raw-CFrame copy rejected in the owner's screenshot. Check lobby spawn and respawn, native F and number keys, browse details, reject forged shots and forced equips, then training draw and lobby return. Offline checks cannot establish runtime behaviour or visual acceptance; current evidence belongs in the UI record.

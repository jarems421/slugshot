# ADR 0001: Minimal source-first foundation

Date: 2026-10-28
Status: Accepted for this foundation milestone
Approval evidence: user's pasted foundation-only request explicitly chooses Roblox Studio, Luau, VS Code, Git/GitHub and Rojo.

## Context
Start from an empty workspace without deciding gameplay mechanics. Existing local tools can be reused without installing dependencies.

## Decision
Use Rojo client/server/shared directories, pinned Rokit tools, a dependency-free verification command, isolated Studio smoke test, GitHub Actions configuration, Markdown memory and project-local agent procedures. Git is local until the owner approves remote setup. Leave account/MCP activation and external installations pending approval.

## Alternatives
Native Script Sync is supported by Roblox but is not the selected foundation. A framework, Wally packages and gameplay libraries would introduce commitments with no current implementation need. A full test framework can be selected later if test complexity warrants it.

## Consequences
Minimal lock-in and no gameplay modules. Full engine type analysis and Studio runtime execution require separate setup/evidence. Tool versions and CI action pins need deliberate maintenance. No decision is made about movement, camera, combat or networking architecture.

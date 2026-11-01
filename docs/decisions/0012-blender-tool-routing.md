# ADR 0012: Versioned Blender skill and backend routing

Date: 2026-10-31
Status: Accepted tooling scope by the owner's Blender ecosystem installation request. Creature art remains unapproved.

## Context

The existing headless Blender 4.5 creature pipeline passes technical checks, but the owner reports weak silhouette, cylindrical form, attached-looking features and limited expression. Two requested skill libraries overlap in names and require different Blender versions. Two requested live MCPs can edit the same scene and run powerful code. Rocklock and movement work must remain isolated.

## Decision

Keep Blender 4.5.14 as the existing creature/movement default. Install Blender 5.2.3 portable beside it for EL4CTEO workflows. Pin and vendor 28 EL4CTEO and 30 RobLe3 skill definitions, install namespaced copies for both agents, and add a Slugshot-specific router. Register BlendRelay and MCP for Blender for both agents; select one live backend for an editing operation, with a saved scene checkpoint and a disposable validation when a workflow is new. Continue using headless scripts for reproducible builds. The [routing guide](../slugs/skill-routing.md) specifies problem-based selection and the [audit](../slugs/install-audit.md) records actual compatibility.

Keep the first creature's `.blend` and accepted renders as the baseline. Technical QA and owner visual approval are separate gates. Do not automatically convert the first creature to a different modelling method or replace the existing asset pipeline.

## Consequences and validation

Namespaced skill copies avoid overwriting duplicate animation/rendering skills but require a managed update script. Global agent registrations make the tools available outside this worktree; project use is governed by the Slugshot router. Blender MCP Python execution is confined by the agent's actual request and localhost connection; optional external generators remain off. The audit records the 67 EL tests, 12 RobLe3 export tests, both hosts' representative discovery/invocation and disposable 4.5/5.2 MCP edits. Full per-skill invocation, Roblox import and artistic acceptance remain unresolved.

"""Build a compact, source-backed inventory of the installed Blender skills."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "el4cteo": ("EL", "fb92cfb4cc5a238c22113a6a230b09f535bd0656", "5.2+", "headless / live MCP"),
    "roble3": ("RL", "a2634b588e80265e796aa53f8ab178d75105c2af", "5.1.1 tested; 4.x uncertain", "Blender MCP"),
}
CORE = {
    "blender-core", "blender-sculpting", "blender-retopology-uv", "blender-character-rigging",
    "blender-facial-shapekeys", "blender-animation", "blender-rendering", "blender-lighting-lookdev",
    "blender-geometry-nodes", "blender-pipeline-automation", "blender-asset-qa",
    "blender-export-pipelines", "text-to-blender", "blender-pro-workflow", "blender-modeling",
    "blender-materials", "blender-lighting", "blender-cameras", "blender-export",
}
VISUAL = {
    "quality-refinement-autoloop", "reference-to-3d", "reference-analysis-validator", "contour-to-mesh",
    "orthographic-registration", "multiview-fit-loop", "fit-repair-optimizer", "reference-look-calibration",
    "multiview-constraint-solver", "landmark-fit-repair", "animation-quality-gate", "blender-stylized-npr",
    "blender-skill-harmonizer", "blender-game-optimization", "blender-texturing", "blender-uv-texturing",
}
LOW = {"blender-environment-kits", "blender-video-editing", "blender-time-of-day", "blender-weather-fx", "blender-clothing", "blender-hair-grooming", "orbital-hud-motion", "mascot-logo-reconstruction"}


def task_data(name: str) -> tuple[str, str, str, str]:
    if "animation" in name or name in {"orbital-hud-motion", "texture-state-animation"}:
        return "rig + timing brief", "clip / motion review", "contact sheet, loops, Studio playback", "other animation skill"
    if "rig" in name or "shapekey" in name:
        return "mesh + deformation brief", "rig / weights / expressions", "deformation views, export roundtrip", "other rig/facial skill"
    if "export" in name or "optimization" in name or "baking" in name:
        return "approved source + target limits", "game asset / bake / report", "FBX reimport, budget, Studio import", "other export/QA skill"
    if "render" in name or "lighting" in name or "cameras" in name or "look" in name:
        return "scene + visual brief", "repeatable review views", "front/side/back/three-quarter comparison", "other lookdev skill"
    if "reference" in name or "fit" in name or "contour" in name or "orthographic" in name or "landmark" in name:
        return "approved original references + mesh", "alignment / repair plan", "multi-view overlays and owner review", "other reference/repair skill"
    if "texture" in name or "uv" in name or "materials" in name:
        return "mesh + palette / maps", "UV / material / marks", "all-angle coverage, export material check", "other texture/material skill"
    if "qa" in name or "quality" in name or "harmonizer" in name or "workflow" in name or "core" in name or "pipeline" in name or name == "text-to-blender":
        return "brief + scene + evidence", "task plan / diagnostics", "technical gate plus owner visual decision", "project orchestration"
    return "original brief + source scene", "revised geometry / scene", "multi-view form and topology review", "other modelling skill"


def main() -> None:
    rows = []
    for source, (code, sha, compat, backend) in SOURCES.items():
        root = ROOT / "vendor" / "blender-skills" / source / "skills"
        for skill in sorted(root.iterdir()):
            path = skill / "SKILL.md"
            if not path.is_file():
                continue
            raw = path.read_text(encoding="utf-8-sig")
            match = re.search(r"^description:\s*(.*)$", raw, re.M)
            if not match:
                raise ValueError(f"Missing description: {path}")
            description = match.group(1).replace("|", "/").strip().strip('"')
            # The upstream frontmatter states concrete scenarios and the failure it addresses.
            if len(description) > 145:
                description = description[:142].rsplit(" ", 1)[0] + "…"
            inputs, outputs, validation, alternative = task_data(skill.name)
            priority = "Core" if skill.name in CORE else "Visual" if skill.name in VISUAL else "Low" if skill.name in LOW else "Occasional"
            evidence = "I, S" if source == "el4cteo" else "I, M"
            if skill.name in {"blender-core", "text-to-blender"}:
                evidence += ", D"
            if source == "roble3" and skill.name == "blender-export":
                evidence += ", E"
            rows.append(
                f"| `{source}-{skill.name}` | {code} `{sha[:8]}` | C / Cl | {compat} | {backend} | {description} | "
                f"{inputs} → {outputs} | {validation} | {priority} | {alternative} | {evidence} |"
            )
    if len(rows) != 58:
        raise ValueError(f"Expected 58 skills, got {len(rows)}")
    out = ROOT / "docs" / "slugs" / "skill-routing.md"
    out.write_text(
        """# Blender skill routing for Slugshot

**Implemented, 2026-10-31.** This is an inventory and selection guide, not proof of Blender 4.5 execution for every skill. Source definitions are pinned under `vendor/blender-skills/`; the namespaced copies are installed in `~/.agents/skills/` (Codex) and `~/.claude/skills/` (Claude Code). `C / Cl` means installed for both agents. Discovery and invocation must still be checked in a fresh host session. Read only the selected skill and its required references.

Sources: **EL** = [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) at `fb92cfb4cc5a238c22113a6a230b09f535bd0656` (MIT; 28 skills); **RL** = [RobLe3/cc-blender-skill](https://github.com/RobLe3/cc-blender-skill) at `a2634b588e80265e796aa53f8ab178d75105c2af` (MIT; 30 skills, v1.4.0). Installed names carry `el4cteo-` or `roble3-` prefixes; this keeps both upstream versions of `blender-animation` and `blender-rendering`. Their copies and cross-skill prose references are namespaced. Original scripts and local asset filenames remain intact. The alternatives column names a relevant family; consult the specific skill before use.

Blender 4.5.14 remains the existing creature/movement production executable. A separate, checksum-verified portable Blender 5.2.3 is installed for EL workflows; its 67 upstream headless tests passed. **RL was live-tested upstream on 5.1.1; its 12 export regressions passed locally on 5.2.3, but its full stack on 4.x remains uncertain.** Use the current headless project pipeline for reproducible creature builds. Use [installation audit](install-audit.md) for current backend test status.

## Selection and quality rules

1. Read the [species brief](catalog/index.md), [Blender lessons](blender-lessons.md), latest source `.blend`, and the owner’s latest feedback. Original references only; franchise material may inform broad traits but must not become reconstruction targets.
2. Name the actual failure before selecting tools. Use the smallest relevant skill set. A valid script or FBX does not establish good silhouette, expression, softness or owner approval.
3. For fused-sphere or cylindrical bodies: geometry and organic sculpting first (`roble3-blender-modeling`, `el4cteo-blender-sculpting` on 5.2), then topology. For detached eyes or appendages: inspect local mesh/weights and landmarks; edit the specific part, then compare all views. For flat spiral eyes: eye relief, UV/material and expression review. For deformations: rig, weights and contact sheets. For import failures: export contract and Studio check.
4. When results are technically valid but artistically rejected, preserve the current source and renders, use `roble3-quality-refinement-autoloop` for diagnosis, and make a targeted correction. Repeated silhouette or cohesion failures suggest a modelling-method weakness; record this in [lessons](blender-lessons.md), but do not rebuild the pipeline without the owner’s direction.
5. Do not run reconstruction skills against protected character designs. Do not load environment, weather, clothing, hair, HUD or video skills for a slug unless the species task actually needs them.

## Backend policy

| Backend | Use | Preconditions and checks |
| --- | --- | --- |
| Existing headless Blender scripts | Deterministic generation, batch QA, renders and export | Keep current 4.5.14 production selection; preserve authored source; `python tools/verify_slugs.py --blender`. |
| EL headless 5.2 skills | Blender 5.2-specific sculpting, QA, rigging, export and recipes | Select side-by-side portable 5.2.3 explicitly; upstream 67-test suite passes. Check each selected workflow on a disposable source before creature edits. |
| BlendRelay | Selected object/vertex and reference-guided local edits | Add-ons tested on 4.5 and 5.2; save source checkpoint; local token; avoid simultaneous edits by another backend. |
| MCP for Blender (`blender`) | General live scene inspection/Python and RobLe3 tool interface | Add-ons tested on 4.5 and 5.2, localhost socket 9876, telemetry disabled in MCP environment; optional asset/generator toggles off. Save source checkpoint. |

Choose one live backend for an operation; close or disconnect it before using another on the same scene. Neither live backend should edit the accepted first-creature source during integration tests. Any Blender Python tool can execute arbitrary code; inspect code and source before running it. The MCP registration names are `blendrelay` and `blender`, so the RobLe3 core `mcp__blender__execute_blender_code` call resolves after fresh discovery. Several older RobLe3 tool names are absent from current MCP for Blender; see the audit before using those recipes.

## Standard creature cycle

Read brief and approved original references → inspect source → choose task and minimal skill(s) → choose backend and checkpoint → make a local edit or controlled variant → render front, side, back and three-quarter → run geometry, rig, material, animation and export QA as applicable → compare against the brief and prior renders → diagnose and repair → record verified lessons → request owner visual approval → export an approved or explicitly designated test version. Keep reusable source, settings and successful geometry. A new method can be compared on a separate variant without overwriting the baseline.

## Invoke from Codex or Claude

Open the slug worktree, then request `$slugshot-blender-orchestrator` with the concrete creature change and latest owner feedback. That literal prompt was tested in fresh Codex and Claude Code CLI sessions. Let the router choose a small source skill set; you can explicitly request `$el4cteo-blender-sculpting` or `$roble3-blender-modeling` when the task calls for it. Installed names are prefixed, so the unprefixed upstream names are ambiguous. If a fresh host does not list the skills, run `python tools/slugs/install_blender_skills.py --check` and restart that host. To update from the pinned vendor copy, review source changes, then run the installer without `--check`.

For live editing, open a **disposable** or checkpointed `.blend` in Blender 4.5/5.2, enable the relevant add-on, and connect in its sidebar. Codex and Claude both have MCP registrations named `blendrelay` and `blender`; choose one for the current scene operation. Close the disposable scene after testing. For EL 5.2 headless scripts, select `C:/Users/runni/slugshot/.tools/blender-5.2.3-windows-x64/blender.exe` explicitly. The existing slug verification command continues to select 4.5.14.

## Individual skill inventory

The “Use / failure” text is a condensed upstream description. “Input → output” is the expected Slugshot handoff. Validation is the minimum relevant check, not evidence that the skill has already run here. **Status codes:** I = installed/metadata checked on both hosts; S = EL source suite (67 tests) passed, not every agent invocation; M = RobLe3 source contract tests passed; D = representative native Codex/Claude discovery only; E = RobLe3 export regression subset passed on Blender 5.2.3. Blank D/E means not tested at that level. The project router itself was explicitly invoked in both hosts. See the [audit](install-audit.md) for exact evidence and limits.

| Installed name | Source/revision | Agents | Blender | Backend | Use / failure addressed | Input → output | Validation needed | Priority | Alternative | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
""" + "\n".join(rows) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {out} with {len(rows)} skills")


if __name__ == "__main__":
    main()

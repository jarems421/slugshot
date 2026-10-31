"""Check that the hand-audited routing guide covers the pinned installed skills."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUIDE = ROOT / "docs/slugs/skill-routing.md"
SOURCES = {"el4cteo": 28, "roble3": 30}


def main() -> None:
    guide = GUIDE.read_text(encoding="utf-8")
    problems: list[str] = []
    for source, expected_count in SOURCES.items():
        source_dir = ROOT / "vendor/blender-skills" / source / "skills"
        names = {f"{source}-{p.parent.name}" for p in source_dir.glob("*/SKILL.md")}
        if len(names) != expected_count:
            problems.append(f"{source}: source has {len(names)} skills, expected {expected_count}")
        rows = re.findall(rf"^\| `({source}-[^`]+)` \|", guide, re.M)
        missing = sorted(names - set(rows))
        extra = sorted(set(rows) - names)
        duplicates = sorted({name for name in rows if rows.count(name) != 1})
        if missing or extra or duplicates:
            problems.append(f"{source}: missing={missing}, extra={extra}, duplicates={duplicates}")
    project = "slugshot-blender-orchestrator"
    project_skill = ROOT / ".agents/skills" / project / "SKILL.md"
    claude_skill = ROOT / ".claude/skills" / project / "SKILL.md"
    if not project_skill.is_file() or not claude_skill.is_file():
        problems.append("project router skill missing from Codex or Claude")
    elif project_skill.read_bytes() != claude_skill.read_bytes():
        problems.append("project router skill copies differ")
    if len(re.findall(rf"^\| `{project}` \|", guide, re.M)) != 1:
        problems.append("project router is not documented exactly once")
    if problems:
        raise SystemExit("\n".join(problems))
    print("Routing inventory: 28 EL4CTEO + 30 RobLe3 + 1 project skill documented; project copies match")


if __name__ == "__main__":
    main()

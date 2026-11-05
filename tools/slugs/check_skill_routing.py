"""Check instruction upkeep: skill inventory, routing coverage, skill descriptions, doc links and current-state records."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "docs/slugs/skill-audit.md"
ROUTING = ROOT / "docs/slugs/skill-routing.md"
ROUTER = ROOT / "docs/index.md"
STATUS = ROOT / "docs/status.md"
SOURCES = {"el4cteo": 28, "roble3": 30}
PROJECT_SKILLS = (
    "slugshot-blender-orchestrator",
    "slugshot-creature-production",
    "slugshot-animation-director",
    "slugshot-procedural-animation",
)
# Read at the start of tasks, so these stay short and their links must work. History may keep old links.
ACTIVE_DOCS = [
    ROOT / "AGENTS.md", ROOT / "CLAUDE.md", ROUTER, STATUS, ROUTING,
    ROOT / "docs/lessons-index.md", ROOT / "docs/slugs/motion-library.md", ROOT / "docs/slugs/motion-review.md",
]
SIZE_LIMITS = {ROOT / "AGENTS.md": 6000, ROOT / "CLAUDE.md": 1000, STATUS: 6000, ROUTING: 6000}
# Anything that had to read a whole history or audit before working was the problem these docs replaced.
MUST_NOT_REQUIRE = re.compile(r"read (?:this |the )?(?:\[?status history|\[?memory|\[?skill audit)", re.I)
STALE = re.compile(r"first creature|isolated (?:slug|creature) worktree|until the first creature", re.I)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
ROUTED_WORK = ("New motion concept", "Blender keyframes", "Procedural Luau", "Motion looks wrong", "Export or Roblox", "Environment", "New slug concept")


def anchors(path: Path) -> set[str]:
    found = set()
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("#"):
            text = line.lstrip("#").strip().lower()
            text = re.sub(r"[^\w\- ]", "", text)
            found.add(text.replace(" ", "-"))
    return found


def check_links(path: Path, problems: list[str]) -> None:
    for target in LINK.findall(path.read_text(encoding="utf-8-sig")):
        if re.match(r"[a-z]+:", target):
            continue
        file_part, _, anchor = target.partition("#")
        resolved = (path.parent / file_part).resolve() if file_part else path
        name = path.relative_to(ROOT)
        if not resolved.exists():
            problems.append(f"{name}: broken link {target}")
        elif anchor and resolved.suffix == ".md" and anchor not in anchors(resolved):
            problems.append(f"{name}: no heading for {target}")


def check_skill_header(skill: Path, problems: list[str]) -> None:
    header = skill.read_text(encoding="utf-8").split("---", 2)
    fields = dict(line.split(": ", 1) for line in header[1].strip().splitlines())
    description = fields.get("description", "")
    name = skill.parent.name
    if not 80 <= len(description) <= 600:
        problems.append(f"{name}: description should be 80-600 characters, is {len(description)}")
    if "Use " not in description:
        problems.append(f"{name}: description should say when to use the skill")


def main() -> None:
    audit = AUDIT.read_text(encoding="utf-8")
    routing = ROUTING.read_text(encoding="utf-8")
    problems: list[str] = []
    installed: set[str] = set()
    for source, expected_count in SOURCES.items():
        source_dir = ROOT / "vendor/blender-skills" / source / "skills"
        names = {f"{source}-{p.parent.name}" for p in source_dir.glob("*/SKILL.md")}
        installed |= names
        if len(names) != expected_count:
            problems.append(f"{source}: source has {len(names)} skills, expected {expected_count}")
        rows = re.findall(rf"^\| `({source}-[^`]+)` \|", audit, re.M)
        missing = sorted(names - set(rows))
        extra = sorted(set(rows) - names)
        duplicates = sorted({name for name in rows if rows.count(name) != 1})
        if missing or extra or duplicates:
            problems.append(f"{source}: missing={missing}, extra={extra}, duplicates={duplicates}")
    for project in PROJECT_SKILLS:
        project_skill = ROOT / ".agents/skills" / project / "SKILL.md"
        claude_skill = ROOT / ".claude/skills" / project / "SKILL.md"
        if not project_skill.is_file() or not claude_skill.is_file():
            problems.append(f"{project} missing from Codex or Claude")
            continue
        if project_skill.read_bytes() != claude_skill.read_bytes():
            problems.append(f"{project} copies differ")
        check_skill_header(claude_skill, problems)
        if len(re.findall(rf"^\| `{project}` \|", audit, re.M)) != 1:
            problems.append(f"{project} is not documented exactly once in the audit")
        check_links(claude_skill, problems)
    # Every skill the routing page names must exist, and every kind of work must have a row.
    for name in set(re.findall(r"`((?:el4cteo|roble3|slugshot)-[a-z0-9-]+)`", routing)):
        if name not in installed and name not in PROJECT_SKILLS:
            problems.append(f"routing names unknown skill {name}")
    for work in ROUTED_WORK:
        if work not in routing:
            problems.append(f"routing has no row for: {work}")
    for path in ACTIVE_DOCS:
        if not path.is_file():
            problems.append(f"missing current-state record {path.relative_to(ROOT)}")
            continue
        check_links(path, problems)
        text = path.read_text(encoding="utf-8-sig")
        limit = SIZE_LIMITS.get(path)
        if limit and len(text.encode("utf-8")) > limit:
            problems.append(f"{path.relative_to(ROOT)} is over {limit} bytes: move detail to history")
        if MUST_NOT_REQUIRE.search(text):
            problems.append(f"{path.relative_to(ROOT)} requires reading history")
    for path in [ROOT / "AGENTS.md", ROOT / "CLAUDE.md", ROUTING, *(ROOT / ".claude/skills").glob("slugshot-*/SKILL.md")]:
        if STALE.search(path.read_text(encoding="utf-8-sig")):
            problems.append(f"{path.relative_to(ROOT)} has outdated first-creature or isolated-worktree wording")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"Routing: 28 EL4CTEO + 30 RobLe3 + {len(PROJECT_SKILLS)} project skills documented; copies match; active doc links, sizes and descriptions pass")


if __name__ == "__main__":
    main()

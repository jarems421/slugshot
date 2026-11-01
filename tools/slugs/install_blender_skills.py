"""Install the pinned, namespaced Blender skill libraries for both local agents.

Run from the repository root. Vendor sources are immutable; this copies only skill
directories and refuses to replace any unowned destination.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VENDOR = ROOT / "vendor" / "blender-skills"
SOURCES = {"el4cteo": 28, "roble3": 30}
MARKER = ".slugshot-source.json"


def source_digest(directory: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(p for p in directory.rglob("*") if p.is_file() and p.name != MARKER):
        digest.update(item.relative_to(directory).as_posix().encode("utf-8"))
        digest.update(item.read_bytes())
    return digest.hexdigest()


def install(check: bool = False) -> None:
    homes = [Path.home() / ".agents" / "skills", Path.home() / ".claude" / "skills"]
    for source, expected in SOURCES.items():
        source_root = VENDOR / source / "skills"
        skill_dirs = sorted(p for p in source_root.iterdir() if (p / "SKILL.md").is_file())
        if len(skill_dirs) != expected:
            raise RuntimeError(f"{source}: expected {expected} skills, found {len(skill_dirs)}")
        names = [p.name for p in skill_dirs]
        for skill_dir in skill_dirs:
            installed_name = f"{source}-{skill_dir.name}"
            identity = {
                "source": source,
                "upstream_name": skill_dir.name,
                "source_sha256": source_digest(skill_dir),
            }
            for home in homes:
                target = home / installed_name
                marker = target / MARKER
                if target.exists() and not marker.is_file():
                    raise RuntimeError(f"Refusing to replace unmanaged skill: {target}")
                metadata = json.loads(marker.read_text(encoding="utf-8")) if marker.is_file() else None
                if metadata and (metadata.get("source"), metadata.get("upstream_name")) != (source, skill_dir.name):
                    raise RuntimeError(f"Wrong source: {target}")
                if metadata and metadata.get("installed_sha256") and metadata["installed_sha256"] != source_digest(target):
                    raise RuntimeError(f"Preserve manually changed skill: {target}")
                if check:
                    if not marker.is_file():
                        raise RuntimeError(f"Missing skill: {target}")
                    if any(metadata.get(key) != value for key, value in identity.items()):
                        raise RuntimeError(f"Wrong source: {target}")
                    if metadata.get("installed_sha256") != source_digest(target):
                        raise RuntimeError(f"Skill content changed: {target}")
                    front = (target / "SKILL.md").read_text(encoding="utf-8-sig")
                    if not front.startswith(f"---\nname: {installed_name}\n"):
                        raise RuntimeError(f"Invalid skill name: {target}")
                    continue
                if target.exists():
                    shutil.rmtree(target)
                home.mkdir(parents=True, exist_ok=True)
                shutil.copytree(skill_dir, target)
                for doc in target.rglob("*.md"):
                    content = doc.read_text(encoding="utf-8-sig")
                    if source == "roble3":
                        # Upstream's bundled v0.4 README links outside plugin/skills.
                        content = content.replace(
                            "../../../../../IMPLEMENTATION_LOG.md",
                            "https://github.com/RobLe3/cc-blender-skill/blob/a2634b588e80265e796aa53f8ab178d75105c2af/docs/process/IMPLEMENTATION_LOG.md",
                        )
                    # Resolve upstream cross-skill references within the same source.
                    # Local file paths, scripts and bundled assets keep their names.
                    for name in sorted(names, key=len, reverse=True):
                        content = content.replace(f"../{name}/", f"../{source}-{name}/")
                        content = re.sub(
                            rf"(?<![\w/.-]){re.escape(name)}(?![\w-])",
                            f"{source}-{name}",
                            content,
                        )
                    doc.write_text(content, encoding="utf-8")
                front = target / "SKILL.md"
                content = front.read_text(encoding="utf-8")
                if not content.startswith(f"---\nname: {installed_name}\n"):
                    raise RuntimeError(f"Could not namespace frontmatter: {front}")
                identity["installed_sha256"] = source_digest(target)
                marker.write_text(
                    json.dumps(identity, sort_keys=True) + "\n",
                    encoding="utf-8",
                )
    print(f"{'Verified' if check else 'Installed'} 58 skills for Codex and Claude Code")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    install(parser.parse_args().check)

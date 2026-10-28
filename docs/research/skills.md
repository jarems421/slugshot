# Specialist skill evaluation

Reviewed 2026-10-28. Skill files are instructions, not guarantees of correct code or permission to implement gameplay. No third-party skill installer was run and no remote skill bundle was installed. The three local skills are original, narrowly scoped procedures derived from the user request and official tool documentation; they contain no copied third-party code.

## Installed project procedures

| Skill | Coverage | Review and limits |
| --- | --- | --- |
| `roblox-foundation` | Rojo packaging, source ownership, MCP verification | Checked against official Rojo/Studio/Codex/Claude docs; local checks exercised |
| `roblox-multiplayer-validation` | Multi-client, networking and physics experiment protocol | Official Studio test/network modes; no controller or protocol design prescribed; runtime evaluation pending |
| `roblox-asset-pipeline` | Blender, rigs, animation, VFX, environments and provenance | Review/roundtrip procedure only; no asset creation or Blender execution performed |

Canonical files are in `.agents/skills/`; identical Claude copies in `.claude/skills/`. Codex's current documented path is `.agents/skills`, not a guessed `.codex/skills`. New-session automatic discovery and behavioral effectiveness are not established by filesystem validation alone.

## Existing candidates evaluated

| Candidate | Findings | Decision |
| --- | --- | --- |
| [nonlooped/roblox-suite](https://github.com/nonlooped/roblox-suite) | MIT, not archived; API last push 2026-10-22. README and Roblox MCP skill inspected; official source links are useful, but the suite spans gameplay/persistence beyond this milestone and contains linked examples | Do not install the bundle. Re-review a pinned specialist and all its referenced executable resources only when needed |
| [ProkStudio Blender rigging/animation](https://github.com/ProkStudio/skills/blob/main/skills/blender/blender-rigging-and-animation/SKILL.md) | Entrypoint inspected; detailed workflow, numerous companion references and generic game export assumptions. Root license covers scaffolding only and explicitly excludes skills, whose upstream licenses must be checked; referenced resources were not fully audited | No installation or copying. Roblox-specific constraints must be checked; generic influence/rig advice cannot establish our engine requirements |
| [arjun988/blender-skills](https://github.com/arjun988/blender-skills/blob/main/.claude/skills/animation/SKILL.md) | Search candidate declares MIT and assumes an MCP-oriented animation pipeline. Full dependency/reference audit not completed | Deferred; metadata alone is insufficient trust verification |

No independently audited animation/physics/networking skill package was necessary to build the foundation. Small original project procedures avoid importing broad gameplay instructions. A later install review must inspect author, commit SHA, license, references/scripts, tool permissions and commands, then test in a disposable workspace. Popularity is not a trust signal by itself.

Sources: [Codex skills](https://developers.openai.com/codex/skills/), [Claude skills](https://code.claude.com/docs/en/skills), [Studio MCP](https://create.roblox.com/docs/studio/mcp), [Studio tests](https://create.roblox.com/docs/studio/testing-modes), [Rojo installation](https://rojo.space/docs/v7/getting-started/installation/), [Roblox animation](https://create.roblox.com/docs/animation/editor).

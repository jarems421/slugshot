# Main delivery review - 2026-11-02

**Confirmed authorization:** owner requested committing and pushing the ADS fix and the other assets created in this conversation onto `main`, noting that Claude had already used the volcano.

**Implemented integration:** latest remote main baseline `48453bd`; tested gameplay branch `ec34137` (includes `79ca98c` responsive wall jumps and `1c1631a` sustained climbing/taps); committed lobby branch `c62124e` with the newer volcano implementation; original concept/source checkpoint `fc8b14a` with volcano, shop, fern and three cave flowers. The complete local concept viewer, GLBs, licences and no-WebGL renders are preserved under [environment-preview](../art/environment-preview/README.md).

**Verified conflict resolution:** older lobby controller files conflicted with current first-person/movement changes. The tested gameplay source was retained; `experiments/movement`, `experiments/combat` and `experiments/creatures` are byte-identical to `ec34137`. Lobby implementation remains byte-identical to its committed source. Both streams of status/memory notes are preserved. These merges do not designate unfinished concepts as final art.

**Verified local checks:**

- `python tools/verify_combat.py`: foundation/movement/combat format, lint, strict types and public/private builds pass.
- `python tools/lobby/build_hub.py --check`: normal lobby hub and check place build.
- `BLENDER=<existing audited 4.5.14> python tools/verify_slugs.py --blender`: contract tests, generated-data parity, strict Luau, source/export/reimport checks, malformed-asset checks and Flopper motion/geometry pass.
- Browser scene/shop/fern/flower JS syntax checks pass; all 168 snapshot hashes and portable binaries match the manifest using its text-normalization policy.
- Intended-path, file-size and credential-pattern checks pass. No hard-coded numeric Roblox asset-ID literals were found in changed text files. Restricted private assets, generated game builds and Site credentials stay excluded.

**Preserved active work:** Claude's uncommitted PvP UI/inventory/charge edits in its worktree remain untouched and outside this delivery. The separately opened ADS review range had a temporary snapshot of those files, but this does not authorize taking over the concurrent source work.

**Limits:** this is a Git integration/backup, not a Roblox experience publication or a fresh combined Studio playtest. Existing native evidence and owner-review limits remain in the asset/movement/ADS notes. The unchanged kong-vault end-pose assertion remains recorded separately. Remote CI is the repository's foundation/movement workflow; broader checks above were run locally.

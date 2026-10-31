# Assets
This public directory contains no third-party movement clips. The experiment uses original code-generated poses/fixtures; downloaded candidates and their conversions/previews stay under ignored `private-assets/`. See [movement provenance](../docs/movement-assets.md).

Future source files belong in `assets/source/`; reviewed export files in `assets/exports/`.
Create these subdirectories only when needed. Nothing in this directory syncs to Studio by default.
Record provenance in [the asset register](../docs/assets.md) before importing.
Large binary assets need an explicit storage decision; Git LFS is not installed by this project.

Rocklock adds original procedural cavern source and exports under `source/environment/rocklock` and `exports/environment/rocklock`. These contain no third-party reference art or private animation data. Small original binaries use ordinary Git; see [ADR 0010](../docs/decisions/0010-rocklock-map.md) and [provenance](../docs/rocklock.md#references-and-provenance).

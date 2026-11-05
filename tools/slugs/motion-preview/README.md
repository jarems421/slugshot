# Motion preview

Compares three motion concepts on a real slug model: one clock, camera and light, at 0.25×, 0.5×, 1× and 2×, from Gameplay, Side, Front or Orbit. It always opens at 1× from the gameplay camera, because that is how a motion should first be judged. This is the concept stage of the [animation director](../../../.claude/skills/slugshot-animation-director/SKILL.md).

```powershell
python tools/slugs/build_motion_preview.py <study>   # one offline HTML file
python tools/slugs/build_motion_preview.py <study> --cdn   # the same, for a published Artifact
python tools/slugs/review_motion.py <study>   # video at real and quarter speed, contact sheet, technical report
```

Output goes to ignored `build/slugs/motion-preview/<study>/`. Models and Three.js r159 come from this worktree's `build/slugs` and `.tools/three-r159`, then from `../slugshot-slug-pipeline`, or from `SLUGSHOT_ASSET_ROOT`. Three's files are checked against pinned hashes. The videos need Blender 5.2; capture needs Edge.

## Writing a study

Add `studies/<id>.js` with a default export. A study gives its `forms`, `duration`, `beats`, cameras and three `concepts`. Each concept has:

- `springs`: channel names and tunes.
- `step(t, s, first)`: runs at 120 Hz before the page opens and sets targets or kicks. Scrubbing replays the result, so any moment is exact.
- `pose(rig, t, c)`: reads channels and calls `rig.show`, `rig.place`, `rig.drive` and `rig.glow`.

`rig.drive(form, bone, offset, pitch, yaw, roll)` matches InfernoMotion's `drive`, in concept axes and concept units, and `kit` matches [`MotionKit`](../../../experiments/creatures/shared/MotionKit.luau). A chosen concept ports to Luau almost line for line.

## Limits

This is a browser approximation. It has no arms, gun, Roblox shading or engine effects, and its first-person view is a fixed camera in a study, not the game's camera. Use it to choose an idea. A motion passes only in Studio; see the [motion review](../../../docs/slugs/motion-review.md).

The earlier [inspect-preview](../inspect-preview/README.md) stays as it is: it is the record of the approved Playful Flame comparison.

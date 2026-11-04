# ADR 0025: Native Inferno inspection from the approved browser study

Date: 2026-11-03. Status: Accepted for the isolated creature/combat experiment.

## Context

The owner selected v3 C, Playful Flame, and explicitly requested making it the animation. The existing gun toss, catch, reveal and lower remain accepted constraints. A static sprite or scaled flame contour already failed the owner's fluidity review. The accepted Blender/GLB creature model should remain recoverable.

## Decision

Add a dedicated client `InfernoInspect` observer for Tool-contained `InfernoLoaded` models. Sample the shared server timestamp used by `SlugInspect`; drive the existing mouth, lid, body, head and antenna bones. The gun sampler and Floppy drivers remain unchanged.

Use client EditableMeshes for the connected flowing flame and local mouth/ink surfaces. Evaluate their original skin weights on the client to avoid the observed native corner folding under large O translations; the precise engine binding cause remains unresolved. The flame changes shape and vertex colour continuously and follows the animated mouth. Its vertices are bounded against the chamber cylinder. No gameplay collision, damage or new remote request is introduced. Native preflight confirmed mesh creation and importing the existing owned mesh in the local Studio place without security changes or asset uploads.

A loaded Inferno fit is derived from the approved chamber-relative browser fit. Evaluate skinned sole samples against an inner-cap support plane; only the spring hop adds clearance. Imported mesh vertices must be converted from [mesh bounds centre](https://create.roblox.com/docs/reference/engine/classes/EditableMesh#GetCenter) into MeshPart coordinates. The imported skeleton is a sibling of the rendered mesh and is resolved by bone name.

Update the first-person copy only for marked inspect face parts: share the local mesh revision and copy surface tint alongside the existing bone transforms. Place the flame after the viewmodel render step using the visible Handle frame. Keep native meshes alive for the model's lifetime, restore rest pose on cancellation and destroy the effect resources with the model.

## Consequences and limits

This reuses the approved source and existing gun protocol without publishing animation assets. Browser shader and Roblox vertex-colour shading are different renderers; native visual review is required. EditableMesh memory/permission support on deployed experiences and low-memory devices is not established by a local Studio pass. General loaded-slug resizing and performance at multiplayer scale remain separate checks. See [native evidence](../slugs/inferno-inspect-studies.md).


## Owner correction and integration follow-up, 2026-11-03

### Later polish and runtime isolation

The owner subsequently requested shared loaded sizing, clean tooth definition, larger breath, smoother chamber lights and a lower/inward inspection pose with enough distance to show the arm. Both species use one 1.10 multiplier. Floppy's evaluated loaded body cross-section is centred after its existing spring motion; Inferno retains evaluated sole support and chamber centring. Inferno's uniform fit rejects larger 1.15/1.25 candidates during acting.

The tooth divider gets two shallow tapered points on a rigid client surface evaluated from its original skin weights. Observe world models only; do not alter replicated templates or viewport icons. Model rescaling also rescales stored bone-local offsets. First-person copies share marked face geometry and follow its revisions. Dispose each edited surface when its part is removed.

The existing Playful Flame flow/timing is preserved, with the requested larger scale directed into spare chamber height and still constrained by the cylinder/caps. Chamber light uses smooth quarter-circle Beams and matched rails with thin core/soft layers; attachments share one carrier. The viewmodel locally suppresses the source beams while displaying its own and restores them on teardown. The accepted flip and species clocks remain as below. Final scope/evidence is in the [polish record](../slugs/evidence/2026-11-03-inferno-inspect-polish.json).

The initial handoff preserved an obsolete local gun/Floppy baseline. The owner explicitly requests the newer approved inspect plus another faster flip, mouth attachment repair and a stronger spring, with the flame unchanged. Integrate the current inspect files from main; preserve the newer Floppy body/face and clear-canister fixes. Both slug bodies need the rig's Motor6Ds recreated in first person. Bound the locally evaluated mouth geometry independently of its changing silhouette and preserve physical mesh scale in the copy.

Use two related clocks: `creatureElapsed` gives real time for Inferno's approved breath/face, while `elapsed` returns shared gun time. Inferno stretches only the middle hold; quick toss/catch/reveal and plain lower have the same duration for both slugs. Floppy's act remains 3.77 s; Inferno's is 6.37 s. The owner-requested toss flight is now 0.24 s. Native flame functions, material and start/end are unchanged. [Current evidence and limits](../slugs/evidence/2026-11-03-inferno-inspect-current-build.json).


## Owner refinement, 2026-11-04

Use a tangential cylindrical sweep for a readable larger breath while bounding radial thickness and end caps. The connected surface uses orange/amber heat, moving vertex opacity and rising/spreading release motion. Freeze its emitted handle-local frame once emission stops so the recovering face cannot drag the tail downward. Head/torso/lid effort carries the exhale; no cheek-inflation driver is added.

Both species share a final 0.24 s toss and visible low catch. The first-person arm keeps some presentation weight through that catch and then releases into its current carry pose; normal movement continues underneath. Full durations become 3.90/6.50 s. Preserve the opening toss and species act. [Current native evidence](../slugs/evidence/2026-11-04-inferno-breath-return.json).


## Owner refinement: overlap and fixed footing, 2026-11-04

Inferno’s return begins at 3.95 s and overlaps gun lowering at 4.12 s, with a 4.44 s catch and 4.67 s completion. Keep the original raised/breath acting interval. Add fading 3D ember slots to the existing editable surface and expand the release in the tangent/up plane while keeping radial depth bounded.

For Floppy, constrain the sole instead of translating the full body to centre a leaning head. Limit upper/head articulation if the true elliptical chamber requires it; suppress standing lower-body sway. Preserve the coherent authored model/material bundle. Match light arcs to separate glass radii, and invalidate canister visibility caches when parts arrive after the initial selection. [Evidence](../slugs/evidence/2026-11-04-inferno-embers-footing.json).


## Owner refinement: native belly and final loaded pose, 2026-11-04

Retain Inferno's native body skin and add a local rest-space belly corrective rather than approximating an inhale solely with axial bone offsets. Head/sole stay unchanged; body mesh content is shared with first person and reset/disposed with inspection state. Start the longer inhale at 0.78 s, breath at 1.90 s, and use a small forward-leaning exhale hop.

Match both species to one measured resting height, reserving common clearance. Floppy's cap support must survive the return turn; centre his undeformed facing silhouette and fit final body/jelly/antenna deformation after facial updates. Repair eye shading once through a shared local material created by the supported runtime API, cloning material revisions into the viewmodel while retaining each instance's emission. [Native verification and limits](../slugs/evidence/2026-11-04-inhale-size-landing.json).

## Owner rollback: original Floppy, 2026-11-04

**Confirmed:** Burpy is approved. The owner rejects Floppy's under-eye repaint and antenna adjustments, requesting the original flat-bottom design with the original smooth upper-body wiggle and an enlarged size that remains inside the canister. This supersedes the Floppy repaint and equal-height fitting approach above. Remove the repaint module, preserve the accepted static face maps and original antenna transforms, and seat the authored flat ground plane on the cap. Keep only sole evaluation in the runtime support pass; use a modest uniform loaded enlargement instead of suppressing the spine motion or moving the antenna roots. [Verified restoration](../slugs/evidence/2026-11-04-floppy-original-restored.json).

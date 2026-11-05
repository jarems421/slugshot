# Slug design record: Arachnet

## Confirmed - Silkline approved, 2026-11-04

After seeing the pull/swing/release study, the owner said "that's good" and requested the next slug using the same procedure. **Snapbind main and Silkline passive are now selected cores.** Preserve the approved surface-anchor movement identity, direct pull, high-anchor swing and momentum-preserving release. Exact balance, controls, anchor durability, collision, ally access and production art remain open. This acceptance does not confirm all proposed counterplay/partner rules. The viewer retains this pair as confirmed references and now opens on [Frostcrawler](frostcrawler.md).

## Confirmed - Snapbind main and movement passive direction, 2026-11-04

**Owner:** "Snapbind is good. Yeah, let's use Snapbind. That's the main one." Snapbind is the selected main: direct impact damage plus a brief lower-body silk bind, with aim/firing retained and visible strands that can be cut. Other main alternatives are no longer active. Exact balance and implementation remain open.

**Owner passive direction:** shoot a surface and use silk to pull yourself or swing through the environment. This supersedes the earlier contact-trap/shield/rebound comparison. The surface hit still automatically creates the passive; the detailed traversal controls are separate and remain to be designed.

**Confirmed core / detailed rules open - Silkline study:** an anchor connects the shooter to the struck surface. Reel toward it for a direct pull, or use a high wall/ceiling anchor to redirect movement into a swing. Release retains tangential momentum. Floor anchors offer a low grounded pull. The artifact compares these two uses of one passive; its buttons are presentation controls, not assigned game inputs. The name used is Silkline; anchor durability/lifetime/range, steering, release/reel inputs, collision handling, friendly access and recovery interaction remain proposals. An opponent shooting the visible anchor to break the tether is proposed counterplay, not owner-confirmed behaviour.

The earlier Silkline revision opened on this pair; the current viewer retains both confirmed cores and opens on Frostcrawler. Earlier alternatives are preserved in `checkpoints/before-silkline`. These are browser demonstrations with neutral placeholders; no native movement, combat, creature source or Studio place was edited.

**Implemented/verified locally, 2026-11-04 - Silkline revision:** `check-silkline.mjs` passed 288 finite samples, confirmed Snapbind visibility/binding/cut response, high-anchor pull, attached wall/ceiling swing, release detachment and continued forward motion, grounded floor pull, selected Inferno/Aquabeek pairs, controls and 390-pixel layout. Report/captures are in `qa-silkline/` under the artifact directory; the ceiling swing capture was visually inspected. This is authored browser motion, not a physics simulation or Studio verification. Anchor destruction and game input rules are proposed, not implemented in this comparison.

## Confirmed - scope and reference identity

Arachnet is in the [owner's 14-slug bank](../ability-planning.md). On 2026-11-04 the owner finalized Aquabeek's Crashwave/Mistbank pair and requested the next slug's artifact using the same procedure. The assistant chose Arachnet from that bank for the next comparison. This does not approve any new ability or final creature art.

Use neutral small/transformed placeholders while comparing simple, independently useful main and passive abilities. Keep the shared automatic player-hit versus floor/wall/ceiling distinction. Effects should have clear outcomes, counterplay and optional partners; another slug must not supply their whole usefulness.

## Historical - main options before owner selection

| Candidate | Standalone effect | Response / tradeoff |
| --- | --- | --- |
| Snapbind | Impact damage plus a brief lower-body silk bind; aim/firing remain available. | Shoot/cut visible strands, get help cutting them, return fire or wait out the short hold. |
| Reelshot | Impact damage plus one short physical thread pulling the struck opponent toward the shooter. | Break line with cover or fire back toward the shooter; drawing a dangerous opponent closer is a risk. This is single-target, not an area suction field. |
| Anchorline | Impact damage and a visible ground anchor tether. The target can move/fire within slack, but a longer retreat makes it taut. | Shoot the weak anchor, get help cutting the line or fight within slack until expiry. |

## Historical - passive surface options before movement direction

| Candidate | Surface effect | Response / tradeoff |
| --- | --- | --- |
| Tripweb | A visible single-catch sticky patch: floor crossing, wall contact or jumping into ceiling strands triggers a short hold. | Avoid contact, clear the web before entering or cut free. No invisible whole-room trap. |
| Catchnet | A surface-anchored web canopy catches one incoming projectile, then tears away. Orientation follows floor/wall/ceiling. | Spend one shot to consume it, send a second or take an open side; no reflection or permanent shield. |
| Springweb | Contact stretches elastic silk, then rebounds a player outward from the hit surface: floor up, wall out, ceiling down. | Avoid contact or deliberately exploit the rebound. Ally/enemy and repeat rules remain to be chosen. |

Snapbind is now selected above; the other five alternatives are historical and no longer active. Damage, durations, control strength, movement restrictions, durability, team effects, repeat limits, range and other elemental rules remain open. The examples of Crashwave exploiting a hold, Backdraft/earlier fire exploiting a tether, or a net protecting a rotation are possible follow-ups, not extra equipped Arachnet powers.

## Historical implementation - initial six-option comparison

The self-contained artifact is `build/slugs/inferno/ability-concepts-20261104/Slugshot-ability-lab.html`, with the earlier HTML alias preserved. It opens on Arachnet and includes three main / three passive alternatives, floor/wall/ceiling controls, tactical/counterplay branches, relative health and camera/playback controls. Aquabeek's chosen pair and Inferno's chosen pair remain available as confirmed references. Pre-change comparison is checkpointed at `checkpoints/aquabeek-final-selection`.

The placeholders/effects are original browser geometry. No franchise mesh, texture or character art is used, no final Arachnet model/rig/export is authored and no native gameplay or upload is performed. Web identity follows the already discussed roster reference; these mechanics are original proposals, not claims about franchise canon.

**Implemented/verified locally, 2026-11-04:** `check-arachnet.mjs` passed 480 finite scene samples, the six proposed bind/pull/tether/trap/net/rebound outcomes and their scripted responses, species/main/passive/surface and playback/camera controls, and a 390-pixel page without horizontal overflow. Current report and review captures are in `qa-arachnet/`; desktop captures were visually inspected. Aquabeek exposes only its final pair, and their selected rendering source matches the checkpoint byte-for-byte. These checks verify browser concepts, not native gameplay, balance, final art approval or Studio playback.

## Unresolved

Movement-passive details; final small/transformed forms and art; balance and interaction rules; production VFX; native implementation and Studio/multiplayer/device evidence. Snapbind's main selection is confirmed.

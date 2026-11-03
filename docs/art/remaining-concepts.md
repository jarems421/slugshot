# Remaining lobby concept brief

**Confirmed, 2026-11-01:** owner said the volcano is good and moved on to the general shop. Volcano study 05 therefore has owner art approval; layout/route fitting and Studio remain separate. The next brief is recorded in [general shop](general-shop.md), with [Slugterra shop research](../research/slugterra-shops.md).

## Volcano study 05 and reusable fern, 2026-11-01

**Confirmed:** owner requested curled cave ferns at the foot, a stronger/smoother lava-spitting animation, and an independently reusable fern. They consider these the last volcano changes; no final approval of this revised study is inferred.

**Implemented:** six placements of the [shared fern asset](curled-cave-fern.md), with an isolated selectable preview, GLB download and source download. Eruption jets now evaluate continuous heads/tails rather than changing whole mesh segments. They rise, detach and fall through a longer, fuller arc. The no-WebGL version interpolates projected paths continuously, draws filled ribbons rather than many separate blurred strokes, and resizes its effect canvas only when needed.

**Implemented/verified in browser:** 36 views of each asset, eruption phase sheet, live/forced-no-WebGL controls, 390 px fit and fern download routes pass without runtime/resource errors. A timing sweep at 60 Hz confirms continuous head/tail progression (maximum normalized step 0.008772). Fern GLB structural checks pass; see its record. [Volcano](evidence/volcano/study-05.png), [eruption sequence](evidence/volcano/study-05-burst-sequence.jpg). These are browser/offline checks, not Studio or owner-device performance evidence.

**Unresolved:** owner verdict on fern and motion, broader footprint/route fitting, Blender production and Roblox runtime.

## Volcano study 04, 2026-11-01

**Confirmed:** owner likes study 03 and requested the last adjustments: replace the simple base crystals with varied existing library designs in red, gold and orange, scattered with mushrooms; make descending lava and crater spit visibly more animated. Preserve the liked mountain design.

**Implemented:** copied the library's 14 crystal design records to the website and reused six layouts (original cluster, spire, fan, crown, shard field and gold spiral) in 12 deterministic scatter sites. Their hexagonal body/tip primitive and layout formulas come from the authored library source; these are browser reconstructions of the source definitions, not imports of the Blender GLBs. The original cluster pedestal rocks are omitted so the clusters root in the volcano bedrock. Four sites use each warm palette; sizes and orientations vary. Small extra mushrooms accompany half the sites.

**Implemented/verified in browser:** faster downhill lava advection and travelling ripples; smoother fountain trails and elongated ballistic droplets. The no-WebGL fallback now animates highlights along the actual camera-projected lava ribbons and fountain curves for each of its 36 turntable angles plus overhead view. Live and forced-no-WebGL checks completed without runtime/resource errors; view, effects, rotation and 390 px layout checks passed. [View](evidence/volcano/study-04.png), [turntable](evidence/volcano/study-04-turntable.jpg), [fallback burst](evidence/volcano/study-04-fallback-burst.png).

**Unresolved:** owner verdict on the final changes, broader footprint and route fitting, Blender production and Roblox runtime. Browser motion is not evidence of engine behaviour.

## Volcano study 03, 2026-11-01

**Confirmed:** Owner rejected the previous volcano as bland, generic, lacking vibrancy and life, and asked it to belong with the Claude-authored island and Maelstrom. Compare directly to the approved library, not only generic volcano references.

**Implemented:** The private site's source was reworked with a wider fractured silhouette, continuous bevelled wall plates, broken ink joints, painted variation and cooler shadows, seven molten channels with animated crust and restrained bloom, a lit crater interior, soft smoke, timed arcing lava, and grouped mint/violet fungi with cooling crystals. The base is sculpted bedrock rather than a plain cylinder. The source of the current website is the separate Sites checkout at `site-volcano`; `volcano-concept/index.html` is the earlier local study and is not current.

**Implemented/verified in a browser:** live front/three-quarter/above/burst screenshots and a 36-angle contact sheet inspected; no runtime/shader/resource errors in the final browser check. With WebGL context creation disabled, the rendered fallback loads and its above-view, effects-pause and auto-rotate controls work. At a 390 px emulated viewport it fits without horizontal overflow. [Three-quarter evidence](evidence/volcano/study-03.png), [turntable evidence](evidence/volcano/study-03-turntable.jpg). These checks do not establish Roblox compatibility or owner art approval.

**Considering:** the broader silhouette is approximately 175 studs across at the mountain's foot, versus the blockout's 130. It will need layout fitting and owner review. The walking route is still absent from the concept. The fungus/crystal accents remain proposals; no final art or implementation approval is inferred.

**Confirmed, 2026-11-01:** The owner requested rotatable concepts for four remaining major lobby assets: one combined waterfall mountain and pond, a separate volcano, a walk-in general shop, and its shopkeeper NPC. Iterate with the owner before building or placing final assets. The shop is a general shop; its name is undecided.

**Confirmed:** The approved layout places the mountain beside the slug-side pond, the volcano behind PvP, and the shop on the opposite side. The pond and waterfall should be larger than their blockout; the pond should feel like an oasis. The features are walkable and connect to the existing spiral route. See [layout](lobby-roadmap.md#scale-map-v1-2026-11-01) and [hub](lobby-hub.md).

**Considering:** Name the shop **The Burrow & Barrel**. Give it a welcoming, chunky frontier-outpost silhouette with warm light and original slug-tech details. This name and design are proposals for the owner, not approved decisions. The shopkeeper's appearance and identity remain open.

**Implemented, 2026-11-01:** [Ember Crown volcano concept](volcano-concept/index.html) is an independently authored, interactive browser blockout with a crater, proposed exterior path and player scale figure. A Chrome headless screenshot was visually checked; the preview is a simple procedural mesh, not the existing shader-derived library pipeline or a Blender/Roblox asset. Three.js 0.159.0 is included under its MIT licence. **Unresolved:** owner art verdict, route intersections and walkability, and appearance and performance in Studio.

**Implemented/verified, 2026-11-01:** The [private concept website](https://slugshot-volcano-concept.jarems421.chatgpt.site) deploys the preview with 24 pre-rendered turntable angles when WebGL is unavailable. A Chrome screenshot with WebGL disabled shows the fallback. User interaction and the owner's device remain unverified. The site is an art concept, not a Roblox asset or experience.

**Confirmed, 2026-11-01:** Owner supplied volcano references and asked for jagged rocks forming the mountain itself, lava running in creases, diffused smoke, intermittent lava spurts and a distinctive molten glow within the Slugterra-inspired Slugshot style. Greenery is undecided; some contrasting detail at the base is desired. **Considering:** cool cave fungi as an optional accent. **Unresolved:** owner approval, including the accent; the approved lobby's walkable route has not been modelled in this concept.

**Implemented/verified:** The private site was updated with integral ridges, coloured lava and crust, diffuse smoke, periodic droplets, and a tentative cool fungus accent. Screenshots of WebGL and no-WebGL rendering were inspected, and deployment succeeded. The fallback uses rendered views with an animated 2D smoke/spark overlay. **Unresolved:** motion and appearance on the owner's device and in Studio.

**Unresolved:** The mountain/pond, shop and NPC concepts have not been generated or approved. Visual fit, exact footprint, player routes, NPC design, Roblox performance and Studio appearance remain to be tested. The existing library's shader-derived preview-to-mesh pipeline is a possible starting point; its prior game assets required separate effects and Studio verification.

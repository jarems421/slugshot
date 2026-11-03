# General shop: The Burrow Exchange (working name)

## Lobby build direction (2026-11-03)

**Confirmed by the owner, later the same day (supersedes the pit-and-bridge study 03, which was rejected):** see the [gun side plan](gun-side-plan.html) ([live](https://claude.ai/artifact/DEmM21QCY21ykLjvw93HUr)). Remove the lava ravine. The gun-side rope bridge lands on a mushroom knoll that fills the whole gun side (-135 to -40 degrees, radius 85 to the wall) and wraps round an uneven, non-circular hole. A substantial bridge crosses the hole to the shop at its centre. The hole is full of canopy built from existing assets (giant mushroom v2 in the grove colours; orange and red only on small mushrooms) and cannot be entered: invisible walls along the bridge and round the rim. No fall respawn needed.

**Confirmed by the owner:** study 02's exterior (rounded pods, portholes, trunk) is the direction. "Shop bar" means a shop counter. Keep the pit and the bridge; the pit is fairly deep but has a visible floor. The canopy becomes a jungle of mushroom canopies with hanging vines, as in the owner's two re-shared house pictures (stored privately in `private-assets/reference/shop`, not redistributed).

**Considering (agent recommendation, owner agreed):** shrink the building to fit a slightly enlarged gun-side envelope, and redesign the interior around the counter, a blaster wall and slug displays. Budget it for phones from the start.

**Unresolved:** final envelope, pit depth in studs, and the fall fade/respawn implementation.

**Implemented, not yet run in Studio (2026-11-03), gun side phase 1:** `python tools/lobby/gun_side_sites.py` writes `experiments/lobby/scale/shared/gun_side.json`: an uneven hole (56 to 102 studs from its centre at radius 200, near edge at 125, floor at -120), a 54-stud bridge 16 wide, a 26-radius shop platform, and sites for 30 knoll mushrooms, 35 canopy mushrooms in four layers (giant mushroom v2, grove colours), 207 grove plants, 9 crystals and 8 Floppies. The block-out (`Arena.luau`) loses the lava ravine and the shop box, builds the knoll floor round the hole, rock walls down to the floor, the bridge deck and platform, and 60-stud invisible barriers round the rim, along the bridge and round the platform (no camera or wall-run hits). `HubArt` places the props through the grove's templates. The place builds; luau lint and formatting pass. **Unresolved:** Studio run, walking the bridge and barriers, the knoll and cliff art, the shop pods, trunk, cap and big bridge art, and rebuilding `hub-plaza-floor`, whose art still leaves the ravine's opening.

**Implemented as a browser concept, study 03:** [live 3D page](https://claude.ai/artifact/ND4dAkrsfRti5qmCkVPF8v), source [shop-concept-03.html](shop-concept-03.html). Eight cream/lavender pods on a faceted rock pillar, gnarled purple trunk, an 84-stud blue main cap with glowing gills plus orange and violet side caps, hanging vines, 13 giant jungle mushrooms, trumpet flowers, a plank root bridge with mint studs, and a 76-deep mist pit with a lit fungus floor. Inside: curved counter, terminal, keeper's stool, a blaster wall of eight original blasters, and six slug tank ideas (Energy Column, Moss Globe, Hive Cells, Fungus Cloche, Lantern Orbs, Slug Tube Run). Verified: one headless software-rendered screenshot of the approach view ([evidence](evidence/general-shop/study-03-approach.png)); the interior views were not screenshotted. Owner verdict unresolved.

## Study 02 - pod-grown shop over a mist chasm (2026-11-02)

**Confirmed feedback:** owner rejected brown and the conventional shape. Supplied house screenshots show rounded room pods, porthole windows, a central tree and a giant blue fungal canopy. The revised design uses those architectural categories with an original arrangement and sign; reference artwork is not redistributed.

**Implemented in browser concept:** pale mint main chamber, blue/lavender side pods, branching purple trunk, two blue fungal canopies, mint portholes and warm entrance lamps. The previous counter and open central aisle remain available through the interior and lift-roof controls. The shop hangs over a dark chasm; tapered roots disappear into layered translucent noise mist, with soft sheets rising at its rim. A broad bridge has continuous side panels, top rails and mint guide strips. Rock/plant pockets on the rim contain mushrooms, curled ferns and three original exotic flower species.

**Considering scale:** building about 60 studs wide and 42 high; chasm 70 wide; bridge about 39 long with 12 studs clear. This changes the earlier 50 x 40 lobby blockout envelope and needs fitting before Studio production. The outer ground in this preview is scenery, not a finalized biome layout.

**Implemented reusable assets:** [Tidefan Bloom](https://slugshot-volcano-concept.jarems421.chatgpt.site/cave-flower-fan.glb), [Mistbell](https://slugshot-volcano-concept.jarems421.chatgpt.site/cave-flower-bell.glb), [Coil Orchid](https://slugshot-volcano-concept.jarems421.chatgpt.site/cave-flower-orchid.glb). Each has a root-ground origin, baked mesh coordinates, vertex colours and separate ink geometry. [Source](../../assets/source/environment/general-shop/cave-flowers.js) and reuse notes accompany the individual exports. These are browser concept assets; Blender production and Roblox appearance/collision are unresolved.

**Confirmed requested interaction direction:** a deliberate pit fall gradually fades to black and respawns at the spawn point. Owner describes the whirlpool equivalent as white. This iteration records that requirement; fade/respawn is not implemented or runtime-verified here.

**Implemented/verified in browser:** 36 exterior and 36 canopy-off views regenerated. Live door easing, roof/interior controls, forced-no-WebGL shop and three flower previews, download responses and 390 px layout passed with no runtime/resource errors. Standalone flowers also have live orbit previews (links below the shop controls). GLB structure, finite attributes, bounds and mesh counts checked: fan 12,384 triangles / 384,700 bytes; bell 14,400 / 450,876; orchid 8,640 / 270,176; six meshes each including ink. These are concept budgets, not optimized scattering budgets. [Three-quarter](evidence/general-shop/study-02.png), [interior](evidence/general-shop/study-02-interior.png), [canopy-off](evidence/general-shop/study-02-cutaway.png), [turntable](evidence/general-shop/study-02-turntable.jpg), [Tidefan](evidence/general-shop/flower-fan.png), [Mistbell](evidence/general-shop/flower-bell.png), [Coil Orchid](evidence/general-shop/flower-orchid.png). No Studio behavior or performance is claimed.

**Unresolved:** owner verdict on the revised shape/flowers, name and scale; final lobby placement, NPC, gameplay interactions and Studio proof. Study 01 below is preserved as history.


**Confirmed, 2026-11-01:** owner approved the volcano, then requested the next asset: an original Slugterra-inspired general shop, medium to moderately large, intended as a future interactive shopping hub. It is not exclusively a gun shop. Research actual shops before designing; see [reference research](../research/slugterra-shops.md).

**Considering:** approximately 50 studs across, 43 deep including steps, and 27 to the roof service cap. The lobby blockout reserved 50 x 40 x 18, so roof height and porch/steps need fitting before implementation. The working name is **The Burrow Exchange**; owner approval is unresolved.

## First concept

**Implemented in the browser concept:** a hollow walk-in shell, broad arched entrance with inward-opening doors, arched teal-metal roof and copper ribs, display windows, round side window and exterior energy unit. The interior has a back counter reserved for the future shopkeeper, two retail display islands and a clear middle aisle. Display dressing includes field packs, cases, maps and energy canisters. The plant at the porch uses the shared [curled fern](curled-cave-fern.md) definition. Materials follow the approved Slugshot ink/paint/glow treatment.

**Implemented/verified in browser:** [private shop preview](https://slugshot-volcano-concept.jarems421.chatgpt.site/?asset=shop), with 36 exterior and 36 roof-off views plus interior/overhead/floor-plan views. Native door animation, roof visibility, interior camera, forced-no-WebGL view selection and 390 px layout pass the browser check without runtime/resource errors. Volcano and fern routing/control/download checks also pass after adding the new asset route. [Front/three-quarter](evidence/general-shop/study-01.png), [interior](evidence/general-shop/study-01-interior.png), [roof-off](evidence/general-shop/study-01-cutaway.png), [turntable](evidence/general-shop/study-01-turntable.jpg).

The [authored source](../../assets/source/environment/general-shop/shop-preview.js) is preserved with [reproduction notes](../../assets/source/environment/general-shop/README.txt). This is browser geometry and materials; it is not a Blender source or an imported Roblox asset.

The preview offers exterior orbit, front, above, roof-off and interior views. These are concept-review interactions. Purchases, inventory, NPC dialogue and Roblox gameplay are not implemented by this model task.

**Unresolved:** owner review of this first building, NPC design, store categories and interaction design, final footprint and path clearance, Blender production, collision, Roblox import/appearance and measured device performance.

**Implemented/verified publication, 2026-11-02:** owner-private deployment succeeded for source `e2774ca6b236ac47c2b8c612aaf18b75631d7308`, deployment `appgdep_6ae837025a588191bbd3026fc6767ea8`. [Open shop study 02](https://slugshot-volcano-concept.jarems421.chatgpt.site/?asset=shop).

**Implemented backup, 2026-11-02:** complete local [viewer/source/export snapshot](environment-preview/README.md) retained for the owner-requested main integration, including all three flower GLBs and fallbacks.

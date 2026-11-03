"""Focused Rocklock build, geometry, source-fidelity and isolation checks.

Run tools/rocklock/build.py first. This command executes no Roblox gameplay.
It includes the existing movement/foundation checks unless --map-only is passed
immediately after an already successful movement verification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT / "tools/rocklock"))
from build import SPAWN, ADAPTER, triangle_wedges, dot, cross, sub
from layout import layout


def run(*args):
    print("+ " + " ".join(args),flush=True)
    subprocess.run(args,cwd=ROOT,check=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--map-only",action="store_true")
    parser.add_argument("--output-suffix",default="")
    args=parser.parse_args()
    if not args.map_only:
        run(sys.executable,"tools/verify_movement.py")
    run("rojo","sourcemap","rocklock.project.json","--output","build/rocklock/sourcemap.json")
    run("luau-lsp","analyze","--definitions=@roblox=.tools/luau/globalTypes.None.d.luau",
        "--sourcemap=build/rocklock/sourcemap.json","experiments/movement/rocklock","build/rocklock/generated/server")
    data=json.loads((ROOT / "build/rocklock/geometry.json").read_text(encoding="utf-8"))
    crystals=json.loads((ROOT / "build/rocklock/crystals/geometry.json").read_text(encoding="utf-8"))
    assert len(crystals["variants"])==5
    assert hashlib.sha256((ROOT / "tools/rocklock/crystals_blender.py").read_bytes()).hexdigest()==crystals["generator_sha256"]
    assert len({p["name"] for p in crystals["placements"]})==len(crystals["placements"])
    for variant in crystals["variants"]:
        for shard in variant["shards"]:
            edges={}
            for face in shard["triangles"]:
                a,b,c=[shard["vertices"][i] for i in face]
                n=cross(sub(b,a),sub(c,a))
                assert dot(n,n)>1e-9,"Degenerate crystal face"
                for i,j in zip(face,face[1:]+face[:1]):
                    edge=tuple(sorted((i,j)));edges[edge]=edges.get(edge,0)+1
            assert all(count==2 for count in edges.values()),"Non-watertight crystal shard"
    for key,path in [("config_sha256","experiments/movement/rocklock/config.json"),
                     ("generator_sha256","tools/rocklock/blender_scene.py"),("layout_sha256","tools/rocklock/layout.py")]:
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest()==data[key],f"Stale geometry: {path}"
    expected=layout()
    assert data["boxes"]==expected["boxes"],"Blender collision manifest differs from the authored layout"
    stalactites=[s for s in data["rocks"] if s.get("profile")=="stalactite"]
    assert len(stalactites)==12
    assert min(vertex[1] for s in stalactites for vertex in s["vertices"])>45, "Stalactites obstruct the playable routes"
    for mesh in data["rocks"]:
        assert len(mesh["triangles"])<20000
        edges={}
        for face in mesh["triangles"]:
            assert len(set(face))==3
            a,b,c=[mesh["vertices"][i] for i in face]
            n=cross(sub(b,a),sub(c,a))
            assert dot(n,n)>1e-9,"Degenerate exported triangle"
            for i,j in zip(face,face[1:]+face[:1]):
                edge=tuple(sorted((i,j)));edges[edge]=edges.get(edge,0)+1
            for pos,size,basis in triangle_wedges(a,b,c):
                assert all(s>0 for s in size)
                assert all(abs(dot(v,v)-1)<1e-6 for v in basis)
                assert abs(dot(basis[0],basis[1]))<1e-6
                assert dot(cross(basis[0],basis[1]),basis[2])>.9999
        assert all(count==2 for count in edges.values()),"Non-watertight rock mesh"
    # Building cannot silently drop geometry or replace the accepted controller.
    for file,private in [(f"SlugshotRocklock{args.output_suffix}.rbxlx",False),(f"SlugshotRocklockPrivate{args.output_suffix}.rbxlx",True)]:
        path=ROOT / "build" / file
        if private and not path.exists(): continue
        tree=ET.parse(path)
        formations=[i for i in tree.iter("Item") if i.findtext("Properties/string[@name='Name']")=="CrystalFormations"]
        assert len(formations)==1
        clusters=formations[0].findall("Item")
        assert len(clusters)==len(crystals["placements"])
        assert not any(i.findtext("Properties/string[@name='Name']")=="InspectionLighting" for i in tree.iter("Item"))
        lights=list(tree.iterfind(".//Item[@class='PointLight']"))
        assert len(lights)==len(clusters)
        for cluster in clusters:
            facets=cluster.findall("Item")
            assert facets and all(f.get("class")=="WedgePart" for f in facets)
            hosts=[f for f in facets if f.find("Item[@class='PointLight']") is not None]
            assert len(hosts)==1 and hosts[0].findtext("Properties/token[@name='Material']")=="288"
            for facet in facets:
                assert all(facet.findtext(f"Properties/bool[@name='{prop}']")=="false" for prop in ("CanCollide","CanQuery","CanTouch"))
        scripts={i.findtext("Properties/string[@name='Name']"):i.findtext("Properties/*[@name='Source']")
                 for i in tree.iter("Item") if i.get("class") in {"Script","LocalScript","ModuleScript"}}
        assert ("MovementPrivateClips" in scripts)==private
        assert not any(".spec" in (name or "") or name in {"RocklockQA","RocklockTestClient"} for name in scripts)
        for name,source in [("Config","shared/Config.luau"),("Traversal","client/Traversal.luau"),
                            ("Presentation","client/Presentation.luau"),("OriginalClips","shared/OriginalClips.luau")]:
            assert scripts[name]==(ROOT / "experiments/movement" / source).read_text(encoding="utf-8"),name
        original=(ROOT / "experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
        assert scripts["MovementSandbox"] in {original.replace(SPAWN,ADAPTER),
            (ROOT / "experiments/movement/client/init.client.luau").read_text(encoding="utf-8")}
        sources=[i.findtext("Properties/*[@name='Source']") for i in tree.iter("Item") if i.get("class")=="Script"]
        assert original.replace(SPAWN,ADAPTER) in sources,"Only the initial spawn adapter may differ"
        local_sources=[i.findtext("Properties/*[@name='Source']") for i in tree.iter("Item") if i.get("class")=="LocalScript"]
        assert (ROOT / "experiments/movement/client/init.client.luau").read_text(encoding="utf-8") in local_sources
        assert not any(i.get("class") in {"Animation","KeyframeSequence","MeshPart"} for i in tree.iter("Item"))
        wedges=[i for i in tree.iter("Item") if i.get("class")=="WedgePart"]
        art=next(i for i in tree.iter("Item") if i.findtext("Properties/string[@name='Name']")=="RockSilhouettes")
        rock_specs={s["name"]:s for s in data["rocks"]}
        for rock in art.findall("Item"):
            spec=rock_specs[rock.findtext("Properties/string[@name='Name']")]
            expected_solid="true"
            for wedge in rock.findall("Item"):
                assert wedge.findtext("Properties/bool[@name='CanCollide']")==expected_solid
                assert wedge.findtext("Properties/bool[@name='CanQuery']")==expected_solid
                assert wedge.findtext("Properties/bool[@name='CanTouch']")=="false"
        boundaries=[i for i in tree.iter("Item") if i.findtext("Properties/string[@name='Name']", "").startswith(("SideBoundary", "EndBoundary", "CornerBoundary")) and i.get("class")=="Part"]
        assert len(boundaries)==8 and all(float(i.findtext("Properties/float[@name='Transparency']"))==1 and i.findtext("Properties/bool[@name='CanCollide']")=="false" for i in boundaries)
        for box in data["boxes"]:
            if box.get("stone_skin"):
                proxy=next(i for i in tree.iter("Item") if i.get("class")=="Part" and i.findtext("Properties/string[@name='Name']")==box["name"])
                assert proxy.findtext("Properties/bool[@name='CanCollide']")=="false"
        parts=[i for i in tree.iter("Item") if i.get("class") in {"Part","WedgePart"}]
        assert len(parts)<=data["config"]["native_part_budget"]
        assert len(wedges)>3000,"Rock silhouettes missing"
    # Foundation and lab project mappings remain independent of the map.
    for project in ("default.project.json","movement.project.json","movement.private.project.json"):
        assert "rocklock" not in (ROOT / project).read_text(encoding="utf-8").lower()
    print("PASS: Rocklock strict types, controller fidelity, watertight geometry, wedge frames, budgets, private/test isolation")


if __name__=="__main__":
    try: main()
    except (AssertionError,OSError,ValueError,subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}",file=sys.stderr);sys.exit(1)

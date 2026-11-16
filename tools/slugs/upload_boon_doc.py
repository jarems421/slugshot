"""Upload Boon Doc's two forms, their halos and image maps as private assets on the owner's account (owner,
2026-11-16: "add both into Studio").

Reads build/slugs/boon-doc/roblox/{base,transformed} (tools/slugs/export_boon_doc_roblox.py). The Roblox API key comes
from the existing private client and is never printed. Identical files reuse earlier uploads. Ids and material
templates stay in ignored private-assets/boon-doc: BoonDocAsset.luau and materials.rbxmx (a BoonDocMaterials folder of
SurfaceAppearance templates, one per game mesh, cloned onto the imported MeshParts by name).
"""
import xml.etree.ElementTree as ET

import upload_rammstone as ur

ur.PRIVATE = ur.ROOT/"private-assets/boon-doc"
ur.BUILD = ur.ROOT/"build/slugs/boon-doc/roblox"
# form: (body mesh, halo mesh, texture stem)
FORMS = {"base": ("BoonDocBody", "BoonDocHalo", "boon-doc-base"),
         "transformed": ("BoonDocTransformedBody", "BoonDocTransformedHalo", "boon-doc-transformed")}


def main():
    upload = ur.private_uploader("Boon Doc ")
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "BoonDocMaterials"
    lines = ["--!strict", "-- Private model ids for Boon Doc's two forms; never commit.", "return {"]
    for form, (body, halo, stem) in FORMS.items():
        tex = ur.BUILD/form/"textures"

        def image(name, path):
            return upload(f"{form}-{name}", path, "Image", "image/png")
        for mesh, s, key in ((body, stem, ""), (halo, stem + "-halo", "halo-")):
            maps = {
                "ColorMap": image(key + "color", tex/f"{s}-color.png"),
                "NormalMap": image(key + "normal", tex/f"{s}-normal.png"),
                "RoughnessMap": image(key + "roughness", ur.gray(tex/f"{s}-roughness.png", tex/f"{s}-roughness-gray.png", "G")),
                "EmissiveMaskContent": image(key + "emissive", ur.gray(tex/f"{s}-glow.png", tex/f"{s}-emissive.png")),
            }
            if mesh == "BoonDocBody":
                # Seen in Studio (2026-11-16): his base body's baked normals turned the whole body dark (a large island
                # baked with strongly tilted normals); without them his colours show, and the body is smooth anyway.
                del maps["NormalMap"]
            ur.template(folder, mesh, maps)
        model = upload(form + "-model", ur.BUILD/form/"model.glb", "Model", "model/gltf-binary")
        lines.append(f"\t{form} = {{ model = {model} }},")
    lines += ["}", ""]
    (ur.PRIVATE/"BoonDocAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    ET.ElementTree(document).write(ur.PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: Boon Doc assets and material templates written privately")


if __name__ == "__main__":
    main()

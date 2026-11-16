"""Upload Aquabeek's two forms and their image maps as private assets on the owner's account (owner, 2026-11-14:
"build out Aquabeek and ... get into Roblox").

Reads build/slugs/aquabeek/roblox/{base,transformed} (tools/slugs/export_aquabeek_roblox.py). The Roblox API key comes
from the existing private client and is never printed. Identical files reuse earlier uploads. Ids and material
templates stay in ignored private-assets/aquabeek: AquabeekAsset.luau and materials.rbxmx (an AquabeekMaterials folder
of SurfaceAppearance templates, one per game mesh, cloned onto the imported MeshParts by name). The base form also has
her eyes and blink lids (tools/slugs/aquabeek_eyes.py): a colour map each, the eyes wet, the lids like skin.
"""
import xml.etree.ElementTree as ET

from PIL import Image

import upload_rammstone as ur

ur.PRIVATE = ur.ROOT/"private-assets/aquabeek"
ur.BUILD = ur.ROOT/"build/slugs/aquabeek/roblox"
FORMS = {"base": ("AquabeekBody", "aquabeek-base"), "transformed": ("AquabeekTransformedBody", "aquabeek-transformed")}


def main():
    upload = ur.private_uploader("Aquabeek ")
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "AquabeekMaterials"
    lines = ["--!strict", "-- Private model ids for Aquabeek's two forms; never commit.", "return {"]
    for form, (mesh, stem) in FORMS.items():
        tex = ur.BUILD/form/"textures"

        def image(name, path):
            return upload(f"{form}-{name}", path, "Image", "image/png")
        ur.template(folder, mesh, {
            "ColorMap": image("color", tex/f"{stem}-color.png"),
            "NormalMap": image("normal", tex/f"{stem}-normal.png"),
            "RoughnessMap": image("roughness", ur.gray(tex/f"{stem}-roughness.png", tex/f"{stem}-roughness-gray.png", "G")),
            "EmissiveMaskContent": image("emissive", ur.gray(tex/f"{stem}-glow.png", tex/f"{stem}-emissive.png")),
        })
        if form == "base":
            for mesh_name, file, rough in (("AquabeekEyes", "aquabeek-eyes", 0.15), ("AquabeekLids", "aquabeek-lids", 0.45)):
                flat = tex/f"{file}-roughness-gray.png"
                Image.new("L", (16, 16), round(rough*255)).save(flat)
                ur.template(folder, mesh_name, {"ColorMap": image(file + "-color", tex/f"{file}-color.png"),
                                                "RoughnessMap": image(file + "-roughness", flat)})
        model = upload(form + "-model", ur.BUILD/form/"model.glb", "Model", "model/gltf-binary")
        extra = ""
        if form == "transformed":
            # Her flight water (tools/slugs/build_aquabeek_water.py), clipped on to the transformed form in flight.
            water = ur.BUILD.parent/"water"
            wtex = water/"textures"
            ur.template(folder, "AquabeekWater", {
                "ColorMap": upload("water-color", wtex/"aquabeek-water-color.png", "Image", "image/png"),
                "RoughnessMap": upload("water-roughness", ur.gray(wtex/"aquabeek-water-roughness.png",
                                                                  wtex/"aquabeek-water-roughness-gray.png", "G"),
                                       "Image", "image/png"),
                "EmissiveMaskContent": upload("water-emissive", ur.gray(wtex/"aquabeek-water-glow.png",
                                                                        wtex/"aquabeek-water-emissive.png"),
                                              "Image", "image/png"),
            })
            extra = f", water = {upload('water-model', water/'model.glb', 'Model', 'model/gltf-binary')}"
        lines.append(f"\t{form} = {{ model = {model}{extra} }},")
    lines += ["}", ""]
    (ur.PRIVATE/"AquabeekAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    ET.ElementTree(document).write(ur.PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: Aquabeek assets and material templates written privately")


if __name__ == "__main__":
    main()

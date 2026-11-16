"""Upload Tormato's two forms and their image maps as private assets on the owner's account (owner, 2026-11-16: "add
both into Studio").

Reads build/slugs/tormato/roblox/{base,transformed} (tools/slugs/export_tormato_roblox.py). The Roblox API key comes
from the existing private client and is never printed. Identical files reuse earlier uploads. Ids and material
templates stay in ignored private-assets/tormato: TormatoAsset.luau and materials.rbxmx (a TormatoMaterials folder of
SurfaceAppearance templates, one per game mesh, cloned onto the imported MeshParts by name). The base form also carries
TormatoEyes, his spinning storm eyes and their ink lines (tools/slugs/tormato_eyes.py): colour and glow, wet.
"""
import xml.etree.ElementTree as ET

from PIL import Image

import upload_rammstone as ur

ur.PRIVATE = ur.ROOT/"private-assets/tormato"
ur.BUILD = ur.ROOT/"build/slugs/tormato/roblox"
FORMS = {"base": ("TormatoBody", "tormato-base"), "transformed": ("TormatoTransformedBody", "tormato-transformed")}


def main():
    upload = ur.private_uploader("Tormato ")
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "TormatoMaterials"
    lines = ["--!strict", "-- Private model ids for Tormato's two forms; never commit.", "return {"]
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
            flat = tex/"tormato-eyes-roughness-gray.png"
            Image.new("L", (16, 16), round(0.15*255)).save(flat)
            ur.template(folder, "TormatoEyes", {
                "ColorMap": image("eyes-color", tex/"tormato-eyes-color.png"),
                "RoughnessMap": image("eyes-roughness", flat),
                "EmissiveMaskContent": image("eyes-emissive", ur.gray(tex/"tormato-eyes-glow.png", tex/"tormato-eyes-emissive.png")),
            })
        model = upload(form + "-model", ur.BUILD/form/"model.glb", "Model", "model/gltf-binary")
        lines.append(f"\t{form} = {{ model = {model} }},")
    lines += ["}", ""]
    (ur.PRIVATE/"TormatoAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    ET.ElementTree(document).write(ur.PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: Tormato assets and material templates written privately")


if __name__ == "__main__":
    main()

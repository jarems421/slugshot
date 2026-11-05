"""Produce the review set for a motion study: real-speed and diagnostic video, contact sheet and technical report.

python tools/slugs/review_motion.py inferno-transform [--fps 60] [--cameras gameplay,side]
Output goes to ignored build/slugs/motion-preview/<study>/review. The technical report never passes a motion on looks.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_motion_preview import ROOT, build
from cli import blender_executable

STAGE = (20, 23, 29, 255)
ENCODER = """
import pathlib
import sys

import bpy

folder, out, fps, width, height = sys.argv[sys.argv.index('--') + 1:]
files = sorted(pathlib.Path(folder).glob('*.png'))
scene = bpy.context.scene
strip = scene.sequence_editor_create().strips.new_image(name='motion', filepath=str(files[0]), channel=1, frame_start=1)
for item in files[1:]:
    strip.elements.append(item.name)
scene.frame_start, scene.frame_end = 1, len(files)
scene.render.fps = int(fps)
scene.render.resolution_x, scene.render.resolution_y = int(width), int(height)
scene.render.resolution_percentage = 100
scene.render.image_settings.media_type = 'VIDEO'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.use_sequencer = True
scene.render.filepath = out
bpy.ops.render.render(animation=True)
"""


def stitch(frames, camera, letters, target):
    """One side-by-side frame per time step, with the concepts labelled, so a video keeps them synchronised."""
    target.mkdir(parents=True, exist_ok=True)
    names = sorted(p.name for p in (frames / camera / letters[0]).glob("*.png"))
    size = None
    for name in names:
        # The canvases are transparent over the page's stage colour; dropping their alpha would turn a soft glow into a hard disc.
        images = [Image.alpha_composite(Image.new("RGBA", opened.size, STAGE), opened).convert("RGB")
                  for opened in (Image.open(frames / camera / letter / name).convert("RGBA") for letter in letters)]
        w, h = images[0].size
        w, h = w - w % 2, h - h % 2
        sheet = Image.new("RGB", (w * len(images), h), (16, 18, 23))
        draw = ImageDraw.Draw(sheet)
        for i, (image, letter) in enumerate(zip(images, letters)):
            sheet.paste(image.crop((0, 0, w, h)), (i * w, 0))
            draw.text((i * w + 10, 8), letter, fill=(246, 164, 92))
        sheet.save(target / name)
        size = sheet.size
    return names, size


def encode(blender, folder, out, fps, size):
    script = folder.parent / "encode_video.py"
    script.write_text(ENCODER, encoding="utf-8")
    subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1", "--python", script, "--",
                    folder, out, str(fps), str(size[0]), str(size[1])], check=True, stdout=subprocess.DEVNULL)
    script.unlink()


def contact_sheet(folder, names, out, columns=2, rows=7):
    picks = [names[round(i * (len(names) - 1) / (columns * rows - 1))] for i in range(columns * rows)]
    first = Image.open(folder / picks[0])
    width = 1000
    height = round(first.height * width / first.width)
    sheet = Image.new("RGB", (width * columns, height * rows), (16, 18, 23))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(picks):
        image = Image.open(folder / name).resize((width, height))
        x, y = (i % columns) * width, (i // columns) * height
        sheet.paste(image, (x, y))
        draw.text((x + 6, y + height - 14), name[:-4], fill=(236, 232, 226))
    sheet.save(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("study")
    parser.add_argument("--fps", type=int, default=60)
    parser.add_argument("--cameras", default="gameplay,side")
    args = parser.parse_args()
    page = build(args.study, False)
    review = page.parent / "review"
    if review.exists():
        shutil.rmtree(review)
    subprocess.run(["node", ROOT / "tools/slugs/capture_motion.mjs", page, review, str(args.fps), args.cameras], check=True, cwd=ROOT)
    report = json.loads((review / "technical-report.json").read_text(encoding="utf-8"))
    letters = [c["concept"] for c in report["concepts"]]
    blender = str(ROOT / ".tools/blender-5.2.3-windows-x64/blender.exe")
    if not Path(blender).exists():
        blender = str(blender_executable())
    for camera in args.cameras.split(","):
        joined = review / "joined" / camera
        names, size = stitch(review / "frames", camera, letters, joined)
        contact_sheet(joined, names, review / f"{args.study}-{camera}-contact.png")
        # Same frames: played at full rate for judging, at quarter rate for finding problems.
        encode(blender, joined, review / f"{args.study}-{camera}-real-speed.mp4", args.fps, size)
        encode(blender, joined, review / f"{args.study}-{camera}-quarter-speed.mp4", max(args.fps // 4, 1), size)
    # Frames are bulky and every view of them is above.
    shutil.rmtree(review / "frames")
    shutil.rmtree(review / "joined")
    print(review)
    for path in sorted(review.iterdir()):
        print(" ", path.name, path.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

"""Render a slug concept page's turntable frames through headless Chrome.

The page draws each frame itself when opened with ?render=1 and posts the JPEGs
back here. Usage:
    python tools/slugs/render_concept.py docs/slugs/catalog/evidence/inferno/inferno.html
    python tools/slugs/render_concept.py <page> --size 480 --frames 0,3,6,12 --out <dir>
"""
from __future__ import annotations

import argparse
import base64
import functools
import http.server
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.parse
from pathlib import Path

CHROME_PATHS = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("page", type=Path)
    parser.add_argument("--out", type=Path, help="defaults to frames/ beside the page")
    parser.add_argument("--size", type=int, default=640)
    parser.add_argument("--forms", default="base,comet")
    parser.add_argument("--frames", default="", help="comma-separated turntable indices; default is all")
    parser.add_argument("--timeout", type=float, default=540.0)
    args = parser.parse_args()

    page = args.page.resolve()
    out = (args.out or page.parent / "frames").resolve()
    out.mkdir(parents=True, exist_ok=True)
    state = {"done": False, "error": None, "count": 0}

    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            path = urllib.parse.unquote(self.path)
            if path.startswith("/frame/"):
                name = Path(path).name
                (out / name).write_bytes(base64.b64decode(body.split(b",", 1)[1]))
                state["count"] += 1
            elif path == "/done":
                state["done"] = True
            elif path == "/error":
                state["error"] = body.decode("utf-8", "replace")
            self.send_response(204)
            self.end_headers()

    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", 0), functools.partial(Handler, directory=str(page.parent))
    )
    threading.Thread(target=server.serve_forever, daemon=True).start()

    chrome = next((p for p in CHROME_PATHS if Path(p).exists()), None)
    if chrome is None:
        raise SystemExit("Chrome or Edge not found")
    query = urllib.parse.urlencode(
        {"render": 1, "size": args.size, "forms": args.forms, "frames": args.frames}
    )
    url = f"http://127.0.0.1:{server.server_port}/{page.name}?{query}"
    profile = tempfile.mkdtemp(prefix="slug-concept-chrome-")
    process = subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--use-angle=swiftshader",
            "--enable-unsafe-swiftshader",
            "--ignore-gpu-blocklist",
            "--no-first-run",
            "--disable-background-timer-throttling",
            f"--user-data-dir={profile}",
            url,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        deadline = time.time() + args.timeout
        while not state["done"] and not state["error"] and time.time() < deadline:
            time.sleep(0.5)
    finally:
        process.terminate()
        process.wait(timeout=20)
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)

    if state["error"]:
        print("Page error:", state["error"])
        return 1
    print(f"{state['count']} frames in {out}" + ("" if state["done"] else " (timed out)"))
    return 0 if state["done"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

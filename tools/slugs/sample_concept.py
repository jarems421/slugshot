"""Evaluate a slug concept page's own shader at many points through headless Chrome.

Used to rebuild an approved concept in Blender from exactly the maths the owner approved, rather than porting
the shader by hand. The caller supplies GLSL defining `vec4 probe(vec3 p)`, compiled after the page's fragment
shader (its `main` removed) so it can call the page's functions. It runs on a regular grid (`sample_grid`) or on
a list of points (`sample_points`); each result comes back as four bytes. `pack24(v, range)` packs a signed
value into the first three for distances; `unpack24` reads it back.

Runs on SwiftShader, as the turntable renders do: Windows GPU drivers have miscompiled parts of these shaders
(see the lesson index, "scales missing in live 3D"). Nothing leaves the machine.
"""
from __future__ import annotations

import functools
import http.server
import json
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.parse
from pathlib import Path

import numpy as np

CHROME_PATHS = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
)
MAX_PIXELS = 1 << 21

SAMPLER = """
uniform vec3 uOrigin; uniform float uStep; uniform vec2 uGrid; uniform float uK0;
uniform float uMode; uniform sampler2D uPts; uniform vec2 uPtsSize;
vec4 pack24(float v, float range) {
  float u = clamp(v/range*0.5 + 0.5, 0.0, 1.0);
  float n = floor(u*16777215.0);
  float r = floor(n/65536.0); n -= r*65536.0;
  float g = floor(n/256.0);
  return vec4(r, g, n - g*256.0, 0.0)/255.0;
}
"""
MAIN = """
void main() {
  vec2 f = floor(gl_FragCoord.xy);
  vec3 p;
  if (uMode < 0.5) {
    float k = floor((f.y + 0.5)/uGrid.y);
    p = uOrigin + uStep*vec3(f.x, f.y - k*uGrid.y, k + uK0);
  } else {
    p = texture2D(uPts, (f + 0.5)/uPtsSize).xyz;
  }
  gl_FragColor = probe(p);
}
"""
PAGE = """<!doctype html><meta charset="utf-8"><body><script>
(async function () {
  const job = JSON.parse(%(job)s);
  try {
    const canvas = document.createElement("canvas");
    const gl = canvas.getContext("webgl2", { antialias: false });
    if (!gl) throw new Error("no WebGL2");
    function sh(type, src) {
      const s = gl.createShader(type);
      gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
      return s;
    }
    const prog = gl.createProgram();
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, "attribute vec2 aPos; void main() { gl_Position = vec4(aPos, 0.0, 1.0); }"));
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, job.source));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
    gl.useProgram(prog);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, "aPos");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    const U = n => gl.getUniformLocation(prog, n);
    for (const [k, v] of Object.entries(job.uniforms || {})) gl.uniform1f(U(k), v);
    const fbo = gl.createFramebuffer();
    async function pass(w, h, index) {
      const tex = gl.createTexture();
      gl.activeTexture(gl.TEXTURE0);   // the points stay bound on unit 1
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
      gl.viewport(0, 0, w, h);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      const out = new Uint8Array(w*h*4);
      gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, out);
      gl.deleteTexture(tex);
      await fetch("/out/" + index, { method: "POST", body: out });
    }
    if (job.mode === "grid") {
      const [nx, ny, nz] = job.dims;
      const kc = Math.max(1, Math.min(Math.floor(job.chunk/(nx*ny)), Math.floor(8192/ny)));
      gl.uniform1f(U("uMode"), 0.0);
      gl.uniform3fv(U("uOrigin"), job.origin);
      gl.uniform1f(U("uStep"), job.step);
      gl.uniform2f(U("uGrid"), nx, ny);
      let index = 0;
      for (let k0 = 0; k0 < nz; k0 += kc) {
        gl.uniform1f(U("uK0"), k0);
        await pass(nx, ny*Math.min(kc, nz - k0), index++);
      }
    } else {
      const pts = new Float32Array(await (await fetch("points.bin")).arrayBuffer());
      const n = pts.length/3, W = 2048, per = Math.max(1, Math.floor(job.chunk/W))*W;
      gl.uniform1f(U("uMode"), 1.0);
      const ptex = gl.createTexture();
      let index = 0;
      for (let s = 0; s < n; s += per) {
        const m = Math.min(per, n - s), H = Math.ceil(m/W);
        const data = new Float32Array(W*H*4);
        for (let i = 0; i < m; i++) {
          data[i*4] = pts[(s + i)*3]; data[i*4 + 1] = pts[(s + i)*3 + 1]; data[i*4 + 2] = pts[(s + i)*3 + 2];
        }
        gl.activeTexture(gl.TEXTURE1);
        gl.bindTexture(gl.TEXTURE_2D, ptex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, W, H, 0, gl.RGBA, gl.FLOAT, data);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.uniform1i(U("uPts"), 1);
        gl.uniform2f(U("uPtsSize"), W, H);
        await pass(W, H, index++);
      }
    }
    await fetch("/done", { method: "POST" });
  } catch (e) {
    await fetch("/error", { method: "POST", body: String(e && e.message || e) });
  }
})();
</script>
"""


def fragment_source(page: Path) -> str:
    """The page's fragment shader without its main()."""
    html = Path(page).read_text(encoding="utf-8")
    start = html.index('<script id="fs"')
    start = html.index(">", start) + 1
    text = html[start:html.index("</script>", start)]
    return text[:text.rindex("void main()")]


def _run(page: Path, defines: dict, probe: str, job: dict, points: np.ndarray | None, timeout: float,
         chunk: int = MAX_PIXELS) -> list[bytes]:
    job = dict(job, chunk=chunk)
    head = "".join(f"#define {k} {v}\n" for k, v in defines.items())
    job = dict(job, source=head + fragment_source(page) + SAMPLER + probe + MAIN)
    work = Path(tempfile.mkdtemp(prefix="slug-sample-"))
    profile = tempfile.mkdtemp(prefix="slug-sample-chrome-")
    (work/"index.html").write_text(PAGE % {"job": json.dumps(json.dumps(job))}, encoding="utf-8")
    if points is not None:
        (work/"points.bin").write_bytes(np.ascontiguousarray(points, np.float32).tobytes())
    state = {"done": False, "error": None, "out": {}}

    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            path = urllib.parse.unquote(self.path)
            if path.startswith("/out/"):
                state["out"][int(path[5:])] = body
            elif path == "/done":
                state["done"] = True
            elif path == "/error":
                state["error"] = body.decode("utf-8", "replace")
            self.send_response(204)
            self.end_headers()

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(work)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    chrome = next((p for p in CHROME_PATHS if Path(p).exists()), None)
    if chrome is None:
        raise SystemExit("Chrome or Edge not found")
    process = subprocess.Popen(
        [chrome, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
         "--no-first-run", "--disable-background-timer-throttling", f"--user-data-dir={profile}",
         f"http://127.0.0.1:{server.server_port}/index.html"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.time() + timeout
        while not state["done"] and not state["error"] and time.time() < deadline:
            time.sleep(0.2)
    finally:
        process.terminate()
        try:
            process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            process.kill()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
        shutil.rmtree(work, ignore_errors=True)
    if state["error"]:
        raise RuntimeError("shader sampling failed: " + state["error"])
    if not state["done"]:
        raise TimeoutError("shader sampling timed out")
    return [state["out"][i] for i in range(len(state["out"]))]


def sample_grid(page, defines, probe, bounds, step, timeout=1800.0, chunk=MAX_PIXELS):
    """probe() on a grid; bounds ((x0, x1), (y0, y1), (z0, z1)). Returns (xs, ys, zs, bytes[nx, ny, nz, 4])."""
    axes = [np.arange(a, b + step*0.5, step) for a, b in bounds]
    nx, ny, nz = (len(a) for a in axes)
    origin = [float(a[0]) for a in axes]
    chunks = _run(Path(page), defines, probe, {"mode": "grid", "dims": [nx, ny, nz], "origin": origin, "step": step},
                  None, timeout, chunk)
    slabs = [np.frombuffer(c, np.uint8).reshape(-1, ny, nx, 4) for c in chunks]   # (k, j, i, 4)
    data = np.concatenate(slabs)[:nz].transpose(2, 1, 0, 3)
    return axes[0], axes[1], axes[2], data


def sample_points(page, defines, probe, points, timeout=1800.0, chunk=MAX_PIXELS):
    """probe() at each of points (N, 3). Returns bytes (N, 4). Lower chunk for heavy probes, so no draw runs long."""
    points = np.asarray(points, np.float32).reshape(-1, 3)
    chunks = _run(Path(page), defines, probe, {"mode": "points"}, points, timeout, chunk)
    return np.concatenate([np.frombuffer(c, np.uint8).reshape(-1, 4) for c in chunks])[:len(points)]


def unpack24(data, range_):
    n = data[..., 0].astype(np.float64)*65536 + data[..., 1].astype(np.float64)*256 + data[..., 2]
    return ((n/16777215.0) - 0.5)*2.0*range_

// Steps a built motion study frame by frame in a disposable headless Edge and saves every concept's frames, so a
// capture plays at true speed however slowly this machine renders. No browser package is installed.
// node tools/slugs/capture_motion.mjs <built.html> <outDir> [fps] [camera,camera]
import { spawn, spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [page, out, fpsArg, camerasArg] = process.argv.slice(2);
if (!page || !out) throw new Error('usage: capture_motion.mjs <built.html> <outDir> [fps] [cameras]');
const fps = +(fpsArg || 60), cameras = (camerasArg || 'gameplay,side').split(',');
await mkdir(out, { recursive: true });
const profile = await mkdtemp(path.join(tmpdir(), 'slug-motion-'));
const edge = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const browser = spawn(edge, ['--headless=new', '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--user-data-dir=' + profile, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let socket;
try {
  let port;
  for (let i = 0; i < 60; i++) { try { port = +(await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; } catch { await sleep(250); } }
  if (!port) throw new Error('Headless browser did not start');
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  socket = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  let next = 1; const pending = new Map(), exceptions = [];
  socket.onmessage = e => { const m = JSON.parse(e.data); if (m.id) { const p = pending.get(m.id); pending.delete(m.id); if (m.error) p.reject(new Error(JSON.stringify(m.error))); else p.resolve(m.result); } else if (m.method === 'Runtime.exceptionThrown') exceptions.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text); };
  const call = (method, params = {}) => new Promise((resolve, reject) => { const id = next++; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })); });
  const evaluate = async expression => { const r = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }); if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || JSON.stringify(r.exceptionDetails)); return r.result.value; };
  await call('Runtime.enable'); await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 1500, height: 900, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: pathToFileURL(path.resolve(page)).href });
  let ready = false;
  for (let i = 0; i < 240; i++) { ready = await evaluate('!!window.motionPreview?.ready'); if (ready) break; if (await evaluate('!document.querySelector("#error")?.hidden')) break; await sleep(250); }
  if (!ready) throw new Error('Preview not ready: ' + await evaluate('document.querySelector("#error")?.textContent') + ' ' + exceptions.join(' | '));
  const info = await evaluate('({duration:motionPreview.duration,concepts:motionPreview.concepts})');
  const frames = Math.round(info.duration * fps);
  for (const camera of cameras) {
    for (const letter of info.concepts) await mkdir(path.join(out, 'frames', camera, letter), { recursive: true });
    for (let f = 0; f <= frames; f++) {
      const count = await evaluate(`motionPreview.sample(${f / fps},${JSON.stringify(camera)})`);
      if (count) throw new Error('Page errors: ' + await evaluate('motionPreview.errors.join(" | ")'));
      for (let i = 0; i < info.concepts.length; i++) {
        const data = await evaluate(`motionPreview.capture(${i})`);
        await writeFile(path.join(out, 'frames', camera, info.concepts[i], `${String(f).padStart(4, '0')}.png`), Buffer.from(data.split(',')[1], 'base64'));
      }
    }
  }
  const report = await evaluate('motionPreview.report()');
  report.fps = fps; report.cameras = cameras; report.exceptions = exceptions;
  await writeFile(path.join(out, 'technical-report.json'), JSON.stringify(report, null, 2));
  if (exceptions.length) throw new Error('Exceptions: ' + exceptions.join(' | '));
  console.log(JSON.stringify(report.concepts.map(c => ({ concept: c.concept, finite: c.finite, snaps: c.snaps, spike: c.largestSpike, at: c.largestSpikeAt, peakShare: c.gameplayCamera.peakShare, visibleSeconds: c.gameplayCamera.seconds }))));
} catch (error) {
  console.error(error);
  process.exitCode = 1;
} finally {
  if (socket) socket.close();
  // Edge's launcher exits early and its children outlive it, so find them all by this run's private profile folder.
  const stop = `Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like '*${path.basename(profile)}*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`;
  spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', stop], { stdio: 'ignore' });
  await sleep(300);
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }).catch(() => {});
}
process.exit(process.exitCode || 0);

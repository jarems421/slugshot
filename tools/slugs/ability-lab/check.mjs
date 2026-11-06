// Checks the built ability lab in a disposable headless Edge and captures every Tormato option for review.
// node tools/slugs/ability-lab/check.mjs   (browser demonstrations only: not physics, balance or Studio evidence)
import { spawn, spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const out = path.resolve('build/slugs/ability-lab'), qa = path.join(out, 'qa');
await mkdir(qa, { recursive: true });
const profile = await mkdtemp(path.join(tmpdir(), 'slug-lab-'));
const browser = spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', ['--headless=new', '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--user-data-dir=' + profile, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let socket;
try {
  let port;
  for (let i = 0; i < 60; i++) { try { port = +(await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; } catch { await sleep(250); } }
  if (!port) throw new Error('Browser failed to start');
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  socket = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  let next = 1; const pending = new Map(), exceptions = [];
  socket.onmessage = e => { const m = JSON.parse(e.data); if (m.id) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.reject(new Error(JSON.stringify(m.error))) : p.resolve(m.result); } else if (m.method === 'Runtime.exceptionThrown') exceptions.push(m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text); };
  const call = (method, params = {}) => new Promise((resolve, reject) => { const id = next++; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })); });
  const evaluate = async expression => { const r = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }); if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || JSON.stringify(r.exceptionDetails)); return r.result.value; };
  await call('Runtime.enable'); await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 1480, height: 1230, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: pathToFileURL(path.join(out, 'Slugshot-ability-lab.html')).href });
  let ready = false;
  for (let i = 0; i < 200; i++) { ready = await evaluate('!!window.abilityPreview?.ready'); if (ready) break; await sleep(250); }
  if (!ready) throw new Error('Lab not ready: ' + await evaluate('document.querySelector("#error")?.textContent') + exceptions.join(' | '));
  await evaluate('abilityPreview.state.playing=false');
  const concepts = await evaluate('abilityPreview.concepts.map((c,index)=>({index,name:c.name,slug:c.slug,kind:c.kind,fresh:c.frightIndex===1?1:0,confirmed:!!c.confirmed}))');
  const opensOn = await evaluate('abilityPreview.concepts[abilityPreview.state.index].slug');
  const sweep = await evaluate(`(()=>{let finite=true,errors=[],samples=0;for(const c of abilityPreview.concepts){const surfaces=c.kind==='main'?['floor']:['floor','wall','ceiling'];const index=abilityPreview.concepts.indexOf(c);for(const surface of surfaces){abilityPreview.state.surface=surface;for(const counter of [false,true])for(let t=0;t<=8;t+=.5){const m=abilityPreview.sample(t,index,counter);finite=finite&&m.finite!==false;samples++;}}}return {finite,samples,errors:abilityPreview.errors}})()`);
  const runOn = (key, value, time, counter = false, surface = 'floor') => evaluate(`(()=>{const index=abilityPreview.concepts.findIndex(c=>c.${key}===${value});abilityPreview.state.surface=${JSON.stringify(surface)};return abilityPreview.sample(${time},index,${counter}).study})()`);
  const run = (...args) => runOn('vineIndex', ...args), light = (...args) => runOn('lightIndex', ...args), gas = (...args) => runOn('gasIndex', ...args), hop = (...args) => runOn('hopIndex', ...args), fright = (...args) => runOn('frightIndex', ...args);
  const mechanics = {
    tangleStillWorks: (await run(2, 4.6)).returnWeak === true,
    lanternStillReveals: (await light(8, 4.6)).revealed === true,
    nauseaStillWorks: (await gas(8, 4.6)).replyWeak === true,
    stickyBombHitsTeammate: (await hop(2, 4.8)).teammateHit === true,
    runningAwaySparesTeammate: (await hop(2, 4.8, true)).teammateHit === false,
    mineTriggers: (await hop(3, 5)).triggered === true,
    mineOnWall: (await hop(3, 5, false, 'wall')).triggered === true,
    mineOnCeiling: (await hop(3, 5, false, 'ceiling')).triggered === true,
    mineAvoided: (await hop(3, 5, true)).triggered === false,
    jumpScareScares: (await fright(1, 3.6)).scared === true,
    jumpScareWearsOff: (await fright(1, 5.2)).scared === false,
    jumpScareDodged: (await fright(1, 3.6, true)).scared === false,
    decoyDrawsFire: (await fright(5, 4.6)).enemyFooled === true,
    decoyOnWall: (await fright(5, 4.6, false, 'wall')).decoyUp === true,
    decoySeenThrough: (await fright(5, 4.6, true)).enemyFooled === false,
  };
  const confirmedOnly = ['gas', 'hop', 'fright', 'light', 'vine', 'tormato', 'boon', 'inferno', 'frost', 'arachnet', 'tazer', 'rock'].every(slug => concepts.filter(c => c.slug === slug).length === 2);
  // Stills for looking at: the newest change (Jump Scare), used well and then countered.
  const shots = [];
  for (const c of concepts.filter(c => c.fresh)) {
    for (const [label, counter] of [['use', false], ['counter', true]]) {
      for (const [surface, time] of c.kind === 'main' ? [['floor', 3.5], ['floor', 4.6]] : [['floor', 4.6], ['wall', 4.6], ['ceiling', 4.6]]) {
        await evaluate(`abilityPreview.state.surface='${surface}';abilityPreview.sample(${time},${c.index},${counter})`);
        await sleep(60);
        const shot = await call('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1480, height: 1230, scale: 0.6 } });
        const name = `${c.slug}-${c.fresh}-${label}-${surface}-${time}.png`;
        await writeFile(path.join(qa, name), Buffer.from(shot.data, 'base64'));
        shots.push(name);
      }
    }
  }
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await sleep(100);
  const mobile = await evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})');
  const report = { opensOn, concepts, sweep, mechanics, confirmedOnly, mobile, exceptions, shots, limit: 'Browser demonstration only' };
  await writeFile(path.join(qa, 'report.json'), JSON.stringify(report, null, 2));
  const failed = Object.entries(mechanics).filter(([, ok]) => !ok).map(([name]) => name);
  if (exceptions.length || !sweep.finite || sweep.errors.length || failed.length || !confirmedOnly || opensOn !== 'hop' || mobile.scroll > mobile.width) throw new Error('QA failed: ' + JSON.stringify({ exceptions, sweep, failed, confirmedOnly, opensOn, mobile }));
  console.log(`PASS: ${sweep.samples} finite samples; every kit, with counterplay; confirmed slugs show only their pair; opens on Hop Rock; 390-pixel layout`);
} catch (error) {
  console.error(error);
  process.exitCode = 1;
} finally {
  if (socket) socket.close();
  // Edge's children outlive its launcher, so end them by this run's private profile folder.
  const stop = `Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like '*${path.basename(profile)}*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`;
  spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', stop], { stdio: 'ignore' });
  await sleep(300);
  await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }).catch(() => {});
}
process.exit(process.exitCode || 0);

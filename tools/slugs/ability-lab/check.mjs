// Checks the built ability lab in a disposable headless Edge and captures Boon Doc's kit for review.
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
  const concepts = await evaluate('abilityPreview.concepts.map((c,index)=>({index,name:c.name,slug:c.slug,kind:c.kind,boon:c.boonIndex||0,confirmed:!!c.confirmed}))');
  const opensOn = await evaluate('abilityPreview.concepts[abilityPreview.state.index].slug');
  const sweep = await evaluate(`(()=>{let finite=true,errors=[],samples=0;for(const c of abilityPreview.concepts){const surfaces=c.kind==='main'?['floor']:['floor','wall','ceiling'];const index=abilityPreview.concepts.indexOf(c);for(const surface of surfaces){abilityPreview.state.surface=surface;for(const counter of [false,true])for(let t=0;t<=8;t+=.5){const m=abilityPreview.sample(t,index,counter);finite=finite&&m.finite!==false;samples++;}}}return {finite,samples,errors:abilityPreview.errors}})()`);
  const runOn = (key, value, time, counter = false, surface = 'floor') => evaluate(`(()=>{const index=abilityPreview.concepts.findIndex(c=>c.${key}===${value});abilityPreview.state.surface=${JSON.stringify(surface)};return abilityPreview.sample(${time},index,${counter}).study})()`);
  const fire = (...args) => runOn('infernoIndex', ...args), run = (...args) => runOn('boonIndex', ...args);
  const mechanics = {
    breathTracks: (await fire(2, 4.5)).breathing === true,
    coverBlocksBreath: (await fire(2, 4.5, true)).blocked === true,
    curtainRisesInFlight: (await fire(7, 2)).curtainUp === true,
    curtainBurnsOut: (await fire(7, 7.8)).curtainUp === false,
    crossingBurns: (await fire(7, 5.5)).relativeDamage > 0,
    goingRoundAvoids: (await fire(7, 6, true)).relativeDamage === 0,
    mendingHealsTeammate: (await run(1, 4)).friendHealth > 0.9,
    mendingHitsEnemyAndHealsSelf: (await run(1, 5.5)).shooterHealed === true && (await run(1, 5.5)).enemyHealth < 1,
    coverBlocksTeammateHeal: (await run(1, 4, true)).healed === false,
    dodgingHealsNobody: (await run(1, 5.5, true)).shooterHealed === false,
    springHealsFloor: (await run(3, 6, false, 'floor')).friendHealth > 0.9,
    springHealsWall: (await run(3, 6, false, 'wall')).inPool === true,
    springHealsCeiling: (await run(3, 6, false, 'ceiling')).inPool === true,
    leavingStopsHealing: (await run(3, 7, true)).inPool === false,
  };
  const confirmedOnly = ['boon', 'inferno', 'frost', 'arachnet', 'tazer', 'rock'].every(slug => concepts.filter(c => c.slug === slug).length === 2);
  // Stills for looking at: every Boon Doc option, used well and then countered.
  const shots = [];
  for (const c of concepts.filter(c => c.boon)) {
    for (const [label, counter] of [['use', false], ['counter', true]]) {
      for (const [surface, time] of c.kind === 'main' ? [['floor', 3.6], ['floor', 5.4]] : [['floor', 4.6], ['wall', 4.6], ['ceiling', 4.6]]) {
        await evaluate(`abilityPreview.state.surface='${surface}';abilityPreview.sample(${time},${c.index},${counter})`);
        await sleep(60);
        const shot = await call('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1480, height: 1230, scale: 0.6 } });
        const name = `${c.boon}-${label}-${surface}-${time}.png`;
        await writeFile(path.join(qa, name), Buffer.from(shot.data, 'base64'));
        shots.push(name);
      }
    }
  }
  // The newest confirmed passive too: it has to read in flight, not only after landing.
  const curtain = await evaluate('abilityPreview.concepts.findIndex(c=>c.infernoIndex===7)');
  for (const [label, counter, time] of [['use', false, 1.5], ['use', false, 2.6], ['use', false, 5.4], ['counter', true, 5.4]]) {
    await evaluate(`abilityPreview.state.surface='floor';abilityPreview.sample(${time},${curtain},${counter})`);
    await sleep(60);
    const shot = await call('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1480, height: 1230, scale: 0.6 } });
    await writeFile(path.join(qa, `curtain-${label}-${time}.png`), Buffer.from(shot.data, 'base64'));
  }
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await sleep(100);
  const mobile = await evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})');
  const report = { opensOn, concepts, sweep, mechanics, confirmedOnly, mobile, exceptions, shots, limit: 'Browser demonstration only' };
  await writeFile(path.join(qa, 'report.json'), JSON.stringify(report, null, 2));
  const failed = Object.entries(mechanics).filter(([, ok]) => !ok).map(([name]) => name);
  if (exceptions.length || !sweep.finite || sweep.errors.length || failed.length || !confirmedOnly || opensOn !== 'boon' || mobile.scroll > mobile.width) throw new Error('QA failed: ' + JSON.stringify({ exceptions, sweep, failed, confirmedOnly, opensOn, mobile }));
  console.log(`PASS: ${sweep.samples} finite samples; Inferno's and Boon Doc's kits, with counterplay; confirmed slugs show only their pair; opens on Boon Doc; 390-pixel layout`);
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

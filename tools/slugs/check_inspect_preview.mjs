// Native Chrome DevTools QA; no browser package installation. Only owns its disposable headless browser.
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
const root = process.cwd(), out = path.join(root, 'build/slugs/inferno/inspect-preview', process.argv[2] ? 'qa-v3' : 'qa');
await mkdir(out, { recursive: true });
const chrome = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const profile = path.join(out, 'browser-' + Date.now()); await mkdir(profile);
const browser = spawn(chrome, ['--headless=new', '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--user-data-dir=' + profile, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
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
  socket.onmessage = e => { const m = JSON.parse(e.data); if (m.id) { const p = pending.get(m.id); pending.delete(m.id); if (m.error) p.reject(m.error); else p.resolve(m.result); } else if (m.method === 'Runtime.exceptionThrown') exceptions.push(m.params.exceptionDetails.text); };
  const call = (method, params = {}) => new Promise((resolve, reject) => { const id = next++; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })); });
  const evaluate = async expression => { const r = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }); if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails)); return r.result.value; };
  await call('Runtime.enable'); await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 1540, height: 1040, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: process.argv[2] || 'http://127.0.0.1:8793/' });
  let ready = false;
  for (let i = 0; i < 100; i++) { ready = await evaluate('!!window.inspectPreview?.ready'); if (ready) break; await sleep(250); }
  if (!ready) throw new Error('Preview not ready: ' + await evaluate('document.querySelector("#error").textContent'));
  const stats = [];
  for (const [name, time, mode] of [['look', 1.47, 'chamber'], ['prepare',1.76,'chamber'],['mouth', 2.03, 'chamber'], ['breath', 2.6, 'chamber'], ['recover',3.94,'chamber'],['smile', 4.34, 'chamber'], ['windup', 4.78, 'chamber'], ['settle', 5.15, 'chamber'], ['landing', 5.58, 'chamber'], ['fire', 2.6, 'fire'], ['gun', 2.6, 'gun']]) {
    const sample=await evaluate(`window.inspectPreview.sample(${time},${JSON.stringify(mode)})`);
    const fitting=await evaluate(`inspectPreview.fitMetrics(0)`), expression=await evaluate(`inspectPreview.expression(0)`);
    stats.push({ name, ...sample, fitting, expression });
    await sleep(200);
    const shot = await call('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
    await writeFile(path.join(out, `${name}.png`), Buffer.from(shot.data, 'base64'));
    for (let i = 0; i < 3; i++) {
      const data = await evaluate(`window.inspectPreview.capture(${i})`);
      await writeFile(path.join(out, `${name}-${i}.png`), Buffer.from(data.split(',')[1], 'base64'));
    }
  }
  const sweep = await evaluate(`(()=>{let poses=[],geometryFinite=true;for(let i=0;i<=204;i++){let t=i/30;window.inspectPreview.sample(t,'chamber');poses.push(window.inspectPreview.gunPose(t));for(let k=0;k<3;k++)geometryFinite=geometryFinite&&inspectPreview.geometry(k).every(Number.isFinite)}return {stats:window.inspectPreview.stats(),allFinite:poses.flat().every(Number.isFinite)&&geometryFinite,endPoseDifference:Math.max(...poses[0].map((v,i)=>Math.abs(v-poses.at(-1)[i])))};})()`);
  const motion = await evaluate(`(()=>{inspectPreview.sample(2.4,'chamber');let a=inspectPreview.geometry(0);inspectPreview.sample(2.6,'chamber');let b=inspectPreview.geometry(0),displacement=0;for(let i=0;i<a.length;i++)displacement+=Math.abs(a[i]-b[i]);let open=inspectPreview.mouth(0);inspectPreview.sample(.6,'chamber');let before=inspectPreview.stats().acting;inspectPreview.sample(4.24,'chamber');let smile=inspectPreview.mouth(0);return {meanShapeDisplacement:displacement/a.length,alreadyLooking:before.every(x=>x.looking===1),mouthOpenHeight:Math.abs(open[0][1]-open[1][1]),smileHeight:Math.abs(smile[0][1]-smile[1][1])}})()`);
  const controls = await evaluate(`(()=>{document.querySelector('[data-solo="1"]').click();let focused=document.querySelector('.studies').classList.contains('focus');document.querySelector('#compare').click();document.querySelector('[data-time="2.6"]').click();return {focused,compareRestored:!document.querySelector('.studies').classList.contains('focus'),beatPaused:!inspectPreview.state.playing,beatTime:inspectPreview.state.time}})()`);
  await call('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
  await sleep(100);
  const mobile = await evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})');
  const fitting=stats.filter(s=>s.mode==='chamber').every(s=>s.fitting.radialRatio<1 && s.fitting.frontMargin>0 && Math.abs(s.fitting.groundGap-s.fitting.intendedGap)<1e-5 && Math.abs(s.fitting.sizeIncrease-1.27)<1e-6);
  const prepareExpression=stats.find(s=>s.name==='prepare').expression;
  const breathExpression=stats.find(s=>s.name==='breath').expression;
  const lidChange=Math.hypot(...prepareExpression.leftLid.map((v,i)=>v-breathExpression.leftLid[i]));
  const face={lidChange,warmerMouth:breathExpression.mouthColor[0]>.1,inkWarmth:breathExpression.inkColor[0]};
  if (process.argv.includes('--motion')) {
    await call('Emulation.setDeviceMetricsOverride', { width: 1540, height: 1040, deviceScaleFactor: 1, mobile: false });
    const motionDir = path.join(out, 'motion'); await mkdir(motionDir, { recursive: true });
    await evaluate('inspectPreview.state.solo=0');
    // A timed 20 fps preview of mouth preparation, sustained flow and return to the grin.
    for (let frame = 0; frame < 66; frame++) {
      const data = await evaluate(`inspectPreview.sample(${1.4 + frame / 20},'chamber');inspectPreview.capture(0)`);
      await writeFile(path.join(motionDir, `${String(frame).padStart(3,'0')}.png`), Buffer.from(data.split(',')[1], 'base64'));
    }
  }
  const report = { stats, sweep, motion, face, fitting, controls, mobile, exceptions };
  await writeFile(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  if (exceptions.length || !sweep.allFinite || sweep.stats.containment.some(x => x > 1.0001) || mobile.scroll > mobile.width || !controls.focused || !controls.compareRestored || !controls.beatPaused || !motion.alreadyLooking || motion.meanShapeDisplacement < .003 || motion.mouthOpenHeight < .07 || !fitting || face.lidChange<.005 || !face.warmerMouth) throw new Error('Preview QA failed: ' + JSON.stringify(report));
  console.log('PASS: model loading, finite poses, fire bounds, focus/compare/beat controls and mobile width');
  console.log(JSON.stringify({ dimensions: stats[0].dimensions, containment: sweep.stats.containment, output: out }));
} finally {
  if (socket) socket.close(); browser.kill();
}

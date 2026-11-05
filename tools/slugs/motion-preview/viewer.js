import * as T from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// Everything a study can do to a slug goes through drive and place, which match the runtime's Bone.Transform and
// PivotTo, so an accepted concept ports to Luau almost line for line. Springs are baked up front at the same fixed step
// as the game, so scrubbing and every synchronised stage show exactly the same moment.
const STEP = kit.TIME_STEP, FRAME = 1 / 60;
const state = { time: 0, playing: !matchMedia('(prefers-reduced-motion: reduce)').matches, speed: 1, camera: 'gameplay', yaw: .7, pitch: .2, zoom: 1, solo: -1 };
const stages = [], errors = [];
window.addEventListener('error', e => errors.push(e.message));
window.addEventListener('unhandledrejection', e => errors.push(String(e.reason)));
const $ = selector => document.querySelector(selector);
const WORLD_UP = new T.Vector3(0, 1, 0);

function bytesOf(base64) {
  const text = atob(base64), out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) out[i] = text.charCodeAt(i);
  return out.buffer;
}

function bake(concept) {
  const names = Object.keys(concept.springs || {}), springs = {};
  for (const name of names) springs[name] = kit.spring(concept.springs[name]);
  const steps = Math.ceil(study.duration / STEP) + 2, values = {};
  for (const name of names) values[name] = new Float64Array(steps);
  for (let i = 0; i < steps; i++) {
    if (concept.step) concept.step(i * STEP, springs, i === 0);
    for (const name of names) { kit.stepSpring(springs[name], STEP); values[name][i] = springs[name].x; }
  }
  return t => {
    const out = {}, at = Math.min(Math.max(t, 0) / STEP, steps - 1.001), i = Math.floor(at), share = at - i;
    for (const name of names) out[name] = values[name][i] + (values[name][i + 1] - values[name][i]) * share;
    return out;
  };
}

function parseModel(name) {
  return new Promise((resolve, reject) => new GLTFLoader().parse(bytesOf(MODELS[name]), '', g => resolve(g.scene), reject));
}

// Concept axes as in the game: sideways is from one spacing bone to the other, up is the world's, front is their cross.
async function makeForm(spec) {
  const scene = await parseModel(spec.model);
  const group = new T.Group(); group.add(scene);
  const hidden = new Set(spec.hide || []);
  scene.traverse(o => {
    if (!o.isMesh) return;
    o.frustumCulled = false;
    if (hidden.has(o.name)) { o.visible = false; return; }
    o.material = o.material.clone();
    if ('metalness' in o.material) { o.material.metalness = 0; o.material.roughness = .7; o.material.emissiveIntensity = .1; }
    // An ink shell is already inside out, so its normal front faces are the ones that show round the silhouette.
    if (/ink/i.test(o.name)) o.material = new T.MeshBasicMaterial({ color: 0x241b19, side: /mouth/i.test(o.name) ? T.DoubleSide : T.FrontSide });
  });
  const inner = new T.Group(); group.add(inner); inner.add(scene);
  if (spec.turn) inner.rotation.y = spec.turn;
  group.updateMatrixWorld(true);
  const [left, right] = spec.spacing.bones.map(n => scene.getObjectByName(n));
  const a = left.getWorldPosition(new T.Vector3()), b = right.getWorldPosition(new T.Vector3());
  const sideways = b.clone().sub(a).normalize();
  const up = WORLD_UP.clone().addScaledVector(sideways, -sideways.dot(WORLD_UP)).normalize();
  const front = new T.Vector3().crossVectors(sideways, up);
  const unit = a.distanceTo(b) / spec.spacing.units;
  const bones = {};
  scene.traverse(o => {
    if (!o.isBone) return;
    const q = o.getWorldQuaternion(new T.Quaternion()).invert();
    bones[o.name] = {
      node: o, p: o.position.clone(), q: o.quaternion.clone(),
      x: sideways.clone().applyQuaternion(q), y: up.clone().applyQuaternion(q), z: front.clone().applyQuaternion(q),
      parentScale: o.parent.getWorldScale(new T.Vector3()).x,
    };
  });
  const box = new T.Box3();
  scene.traverse(o => { if (o.isMesh && o.visible) box.expandByObject(o); });
  const fit = spec.size / Math.max(box.max.y - box.min.y, 1e-6);
  return { group, bones, unit, fit, floor: box.min.y, spec };
}

const glowTexture = (() => {
  const canvas = document.createElement('canvas'); canvas.width = canvas.height = 128;
  const g = canvas.getContext('2d'), r = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(.35, 'rgba(255,255,255,.42)'); r.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = r; g.fillRect(0, 0, 128, 128);
  const texture = new T.CanvasTexture(canvas); texture.colorSpace = T.SRGBColorSpace; return texture;
})();

async function makeStage(article, index) {
  const canvas = article.querySelector('canvas');
  const renderer = new T.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.6));
  renderer.outputColorSpace = T.SRGBColorSpace;
  renderer.toneMapping = T.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.15;
  const scene = new T.Scene(), camera = new T.PerspectiveCamera(70, 1, .05, 2000);
  // The same light for every concept, every study.
  scene.add(new T.HemisphereLight(0xe9efff, 0x4d3541, 2.1));
  const key = new T.DirectionalLight(0xffe5c6, 3); key.position.set(2, 4, 5); scene.add(key);
  const rim = new T.DirectionalLight(0x90badf, 2); rim.position.set(-3, 2, -2); scene.add(rim);
  const floor = new T.GridHelper(400, 200, 0x4a4d57, 0x2a2c33); scene.add(floor);
  const forms = {};
  for (const [name, spec] of Object.entries(study.forms)) { forms[name] = await makeForm(spec); scene.add(forms[name].group); }
  const glow = new T.Sprite(new T.SpriteMaterial({ map: glowTexture, depthTest: false, transparent: true, toneMapped: false }));
  glow.renderOrder = 20; scene.add(glow);
  const concept = study.concepts[index];
  const rig = {
    show(name) { for (const [key, form] of Object.entries(forms)) form.group.visible = key === name; },
    // Offset in concept units along (sideways, up, front), then rotations about those axes: InfernoMotion's drive.
    drive(formName, boneName, offset, pitch = 0, yaw = 0, roll = 0) {
      const form = forms[formName], b = form.bones[boneName];
      if (!b) return;
      const v = new T.Vector3();
      if (offset) v.addScaledVector(b.x, offset[0]).addScaledVector(b.y, offset[1]).addScaledVector(b.z, offset[2]);
      b.node.position.copy(b.p).add(v.multiplyScalar(form.unit / b.parentScale).applyQuaternion(b.q));
      b.node.quaternion.copy(b.q)
        .multiply(new T.Quaternion().setFromAxisAngle(b.y, yaw))
        .multiply(new T.Quaternion().setFromAxisAngle(b.x, pitch))
        .multiply(new T.Quaternion().setFromAxisAngle(b.z, roll));
    },
    place(formName, position, euler = [0, 0, 0], scale = 1) {
      const form = forms[formName], s = form.fit * scale;
      form.group.position.set(position[0], position[1] - form.floor * s, position[2]);
      form.group.quaternion.setFromEuler(new T.Euler(euler[0], euler[1], euler[2], 'XYZ'));
      form.group.scale.setScalar(s);
    },
    glow(level, size, color = 0xffffff, at = [0, 0, 0]) {
      glow.visible = level > 0.001;
      glow.material.opacity = Math.min(level, 1); glow.material.color.set(color);
      glow.scale.setScalar(size); glow.position.set(at[0], at[1], at[2]);
    },
    head() { for (const form of Object.values(forms)) if (form.group.visible && form.bones.head) return form.bones.head.node.getWorldPosition(new T.Vector3()); return null; },
    root() { for (const form of Object.values(forms)) if (form.group.visible) return form.bones.root.node.getWorldPosition(new T.Vector3()); return null; },
  };
  const stage = { index, canvas, renderer, scene, camera, floor, forms, glow, concept, rig, channels: bake(concept), label: article.querySelector('.phase') };
  let drag = null;
  canvas.addEventListener('pointerdown', e => { drag = [e.clientX, e.clientY]; canvas.setPointerCapture(e.pointerId); setCamera('orbit'); });
  canvas.addEventListener('pointermove', e => { if (!drag) return; state.yaw += (e.clientX - drag[0]) * .006; state.pitch = T.MathUtils.clamp(state.pitch + (e.clientY - drag[1]) * .004, -.8, 1.2); drag = [e.clientX, e.clientY]; });
  canvas.addEventListener('pointerup', () => { drag = null; });
  canvas.addEventListener('pointercancel', () => { drag = null; });
  canvas.addEventListener('wheel', e => { e.preventDefault(); state.zoom = T.MathUtils.clamp(state.zoom * Math.exp(e.deltaY * .001), .3, 4); }, { passive: false });
  stages.push(stage);
  return stage;
}

function pose(stage, t) {
  for (const form of Object.values(stage.forms)) for (const b of Object.values(form.bones)) { b.node.position.copy(b.p); b.node.quaternion.copy(b.q); }
  stage.rig.glow(0, 1);
  stage.concept.pose(stage.rig, t, stage.channels(t));
  stage.scene.updateMatrixWorld(true);
}

function aim(stage, t) {
  const camera = stage.camera, focus = new T.Vector3(...study.focus(t, stage.index)), reach = study.frame * state.zoom;
  camera.fov = 35;
  if (state.camera === 'gameplay') {
    const view = study.gameplayCamera(t);
    camera.position.set(...view.position); camera.fov = view.fov;
    camera.lookAt(new T.Vector3(...view.target));
  } else {
    const yaw = state.camera === 'side' ? Math.PI / 2 : state.camera === 'front' ? 0 : state.yaw;
    const pitch = state.camera === 'orbit' ? state.pitch : .1;
    camera.position.set(focus.x + Math.sin(yaw) * Math.cos(pitch) * reach, focus.y + Math.sin(pitch) * reach, focus.z + Math.cos(yaw) * Math.cos(pitch) * reach);
    camera.lookAt(focus);
  }
  const width = Math.max(stage.canvas.clientWidth, 1), height = Math.max(stage.canvas.clientHeight, 1), ratio = stage.renderer.getPixelRatio();
  if (stage.canvas.width !== Math.round(width * ratio) || stage.canvas.height !== Math.round(height * ratio)) stage.renderer.setSize(width, height, false);
  camera.aspect = width / height; camera.updateProjectionMatrix();
}

function draw(stage, t) {
  pose(stage, t); aim(stage, t);
  stage.floor.visible = true;
  stage.renderer.render(stage.scene, stage.camera);
  const beat = study.beats.filter(b => b.t <= t + 1e-6).at(-1);
  stage.label.textContent = (stage.concept.beatLabel && stage.concept.beatLabel(t)) || (beat ? beat.label : '');
}

function renderAll() { for (const stage of stages) if (state.solo < 0 || state.solo === stage.index) draw(stage, state.time); }

function setPlaying(value) { state.playing = value; $('#play').textContent = value ? 'Pause' : 'Play'; }
function setCamera(name) { state.camera = name; document.querySelectorAll('[data-camera]').forEach(b => b.setAttribute('aria-pressed', b.dataset.camera === name)); }
function setSpeed(value) {
  state.speed = value;
  document.querySelectorAll('[data-speed]').forEach(b => b.setAttribute('aria-pressed', +b.dataset.speed === value));
  const note = $('#speed-note');
  note.textContent = value === 1 ? 'Real speed: judge the motion here' : `${value}× is for finding problems, not for judging the motion`;
  note.classList.toggle('diagnosis', value !== 1);
}

// How much of the frame the slug fills from this camera: an animation that is lovely slowed down can be invisible at real speed.
function coverage(stage) {
  const gl = stage.renderer.getContext(), floorWas = stage.floor.visible, glowWas = stage.glow.visible;
  stage.floor.visible = false; stage.glow.visible = false;
  stage.renderer.setClearColor(0x000000, 0);
  stage.renderer.render(stage.scene, stage.camera);
  const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight, px = new Uint8Array(w * h * 4);
  gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, px);
  let solid = 0; for (let i = 3; i < px.length; i += 4) if (px[i] > 0) solid++;
  stage.floor.visible = floorWas; stage.glow.visible = glowWas;
  return solid / (w * h);
}

// Technical only. A clean result here says nothing about whether the motion is any good.
function technicalReport() {
  const heights = Math.max(...Object.values(study.forms).map(f => f.size));
  const swaps = study.swaps || [];
  return stages.map(stage => {
    const frames = Math.round(study.duration / FRAME), track = [], visible = [];
    let finite = true, lowest = Infinity;
    const cameraWas = state.camera; state.camera = 'gameplay';
    for (let i = 0; i <= frames; i++) {
      const t = i * FRAME;
      pose(stage, t); aim(stage, t);
      const head = stage.rig.head(), root = stage.rig.root();
      const focus = new T.Vector3(...study.focus(t, stage.index));
      // A study may hide the slug once its shot has hit.
      if (!head || !root) { visible.push(0); continue; }
      finite = finite && [head.x, head.y, head.z, root.x, root.y, root.z].every(Number.isFinite);
      track.push({ t, p: head.clone().sub(focus) });
      lowest = Math.min(lowest, root.y);
      visible.push(coverage(stage));
    }
    state.camera = cameraWas;
    let spike = 0, spikeAt = 0, snaps = 0;
    for (let i = 2; i < track.length; i++) {
      const near = swaps.some(s => Math.abs(track[i].t - s(stage.index)) < 2.5 * FRAME);
      if (near) continue;
      const a = track[i].p.clone().sub(track[i - 1].p), b = track[i - 1].p.clone().sub(track[i - 2].p);
      const jump = a.sub(b).length() / heights;
      if (jump > spike) { spike = jump; spikeAt = track[i].t; }
      if (jump > (study.snapLimit || .12)) snaps++;
    }
    const peak = Math.max(...visible), seen = visible.filter(v => v >= .002).length;
    return {
      concept: stage.concept.letter, name: stage.concept.name, finite,
      snaps, largestSpike: +spike.toFixed(4), largestSpikeAt: +spikeAt.toFixed(3), lowestRoot: +lowest.toFixed(3),
      gameplayCamera: { peakShare: +peak.toFixed(5), framesAboveFifthOfAPercent: seen, frames: visible.length, seconds: +(seen * FRAME).toFixed(3), perFrame: visible.map(v => +v.toFixed(5)) },
      visualVerdict: 'pending owner review',
    };
  });
}

function buildPage() {
  document.title = study.title;
  $('#eyebrow').textContent = study.eyebrow;
  $('#title').textContent = study.title;
  $('#brief').textContent = study.brief;
  $('#status').textContent = study.status;
  $('#scrub').max = study.duration; $('#scrub').step = 1 / 120;
  $('#note').textContent = study.note;
  const list = $('.studies');
  study.concepts.forEach((c, i) => {
    const article = document.createElement('article');
    article.innerHTML = '<div class="stage"><canvas></canvas><span class="letter"></span><span class="phase">Loading…</span></div><div class="description"><h2></h2><p></p><button class="solo" type="button"></button></div>';
    article.querySelector('canvas').setAttribute('aria-label', `Concept ${c.letter}, ${c.name}`);
    article.querySelector('.letter').textContent = c.letter;
    article.querySelector('h2').textContent = c.name;
    article.querySelector('p').textContent = c.note;
    const solo = article.querySelector('.solo');
    solo.textContent = `Focus ${c.letter}`;
    solo.onclick = () => { state.solo = i; list.classList.add('focus'); document.querySelectorAll('article').forEach((a, k) => a.classList.toggle('focused', k === i)); $('#compare').hidden = false; };
    list.append(article);
  });
  const beats = $('.beats');
  study.beats.forEach(b => {
    const button = document.createElement('button');
    button.type = 'button'; button.innerHTML = `<span>${b.t.toFixed(2)} s</span> <b></b>`; button.querySelector('b').textContent = b.label;
    button.onclick = () => { state.time = b.t; setPlaying(false); renderAll(); };
    beats.append(button);
  });
  $('#play').onclick = () => setPlaying(!state.playing);
  $('#replay').onclick = () => { state.time = 0; setSpeed(1); setPlaying(true); };
  $('#compare').onclick = () => { state.solo = -1; list.classList.remove('focus'); $('#compare').hidden = true; };
  $('#scrub').oninput = e => { state.time = +e.target.value; setPlaying(false); renderAll(); };
  document.querySelectorAll('[data-speed]').forEach(b => b.onclick = () => setSpeed(+b.dataset.speed));
  document.querySelectorAll('[data-camera]').forEach(b => b.onclick = () => { setCamera(b.dataset.camera); renderAll(); });
  document.addEventListener('keydown', e => { if (e.code === 'Space' && !['INPUT', 'BUTTON'].includes(e.target.tagName)) { e.preventDefault(); setPlaying(!state.playing); } });
}

let previous = performance.now();
function frame(now) {
  if (state.playing) state.time = (state.time + Math.min((now - previous) / 1000, .1) * state.speed) % study.duration;
  previous = now;
  if (!window.motionPreview.frozen) renderAll();
  $('#time').textContent = `${state.time.toFixed(2)} / ${study.duration.toFixed(2)} s`;
  $('#scrub').value = state.time;
  requestAnimationFrame(frame);
}

try {
  buildPage(); setCamera('gameplay'); setSpeed(1);
  await Promise.all([...document.querySelectorAll('article')].map((article, i) => makeStage(article, i)));
  stages.sort((a, b) => a.index - b.index);
  window.motionPreview = {
    ready: true, frozen: false, state, errors, id: study.id, duration: study.duration, concepts: study.concepts.map(c => c.letter),
    sample(t, cameraName = state.camera) { window.motionPreview.frozen = true; setPlaying(false); setCamera(cameraName); state.time = t; state.solo = -1; for (const stage of stages) draw(stage, t); return errors.length; },
    capture(i) { return stages[i].canvas.toDataURL('image/png'); },
    report() { window.motionPreview.frozen = true; setPlaying(false); return { study: study.id, title: study.title, duration: study.duration, status: study.status, concepts: technicalReport() }; },
  };
  setPlaying(state.playing); requestAnimationFrame(frame);
} catch (error) {
  errors.push(String(error)); const label = $('#error'); label.hidden = false; label.textContent = 'The preview could not load: ' + error;
  console.error(error);
}

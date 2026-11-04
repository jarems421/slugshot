import * as T from 'three';
import { GLTFLoader } from './vendor/loaders/GLTFLoader.js';
import { variants, acting, makeFlame, deformFlame } from './flow.js';

const TAU = Math.PI * 2, duration = 6.8;
const smooth = x => { x = T.MathUtils.clamp(x, 0, 1); return x * x * (3 - 2 * x); };
const pulse = (t, at, length) => Math.sin(Math.PI * T.MathUtils.clamp((t - at) / length, 0, 1)) ** 2;
const windowed = (t, start, end, fade = .25) => smooth((t - start) / fade) * (1 - smooth((t - end) / fade));
const soft = value => { const x=T.MathUtils.clamp(value,0,1); return T.MathUtils.clamp(x*x*x*(10-15*x+6*x*x),0,1); };
const state = { time: 1.47, playing: !matchMedia('(prefers-reduced-motion: reduce)').matches, speed: 1, mode: 'chamber', yaw: .08, pitch: .18, zoom: 1, solo: -1 };
const stages = [], errors = [];
const palette = await (await fetch('./palette.json')).json();
window.addEventListener('error', e => errors.push(e.message));
window.addEventListener('unhandledrejection', e => errors.push(String(e.reason)));

// Exact scalar timing and CFrame basis from SlugInspect; all candidates share this sampler.
function gunPose(t) {
  const reveal = smooth((t - .98) / .48) * (1 - smooth((t - 5.45) / .4));
  const barrel = new T.Vector3(-.42, .89, .2).normalize(), back = barrel.clone().negate();
  const right = new T.Vector3(0, 0, -1).addScaledVector(back, back.z).normalize();
  const up = new T.Vector3().crossVectors(back, right);
  const basis = new T.Matrix4().makeBasis(right, up, back);
  const rotation = new T.Quaternion().setFromRotationMatrix(basis).multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 0, 1), 65 * Math.PI / 180 * (1 - reveal)));
  const air = pulse(t, .18, .64), down = pulse(t, 5.9, .75);
  const spin = TAU * (smooth((t - .18) / .64) - smooth((t - 5.9) / .75));
  const travel = new T.Vector3(-1.5 * air - 1.2 * down, 1.1 * air + .9 * down, -.65 * air - .5 * down);
  const pivot = new T.Vector3(0, .1, -.3), turn = new T.Quaternion().setFromAxisAngle(new T.Vector3(1, 0, 0), spin);
  const pivotShift = pivot.clone().sub(pivot.clone().applyQuaternion(turn)).applyQuaternion(rotation);
  const weight = smooth(t / .55) * (1 - smooth((t - 5.9) / .75));
  const held = new T.Quaternion().slerpQuaternions(new T.Quaternion(), rotation, weight);
  return { q: held.multiply(turn), position: travel.add(pivotShift).multiplyScalar(.48).add(new T.Vector3(.0, -.28 * (1 - weight), 0)) };
}

function outline(mesh) {
  const ink = mesh.clone();
  ink.name = 'PreviewBodyInk';
  ink.material = new T.MeshBasicMaterial({ color: 0x241b19, side: T.BackSide });
  ink.material.onBeforeCompile = shader => { shader.vertexShader = shader.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = vec3(position + normal * 0.004);'); };
  mesh.parent.add(ink);
}

async function makeStage(article, index) {
  const canvas = article.querySelector('canvas');
  const renderer = new T.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.6));
  renderer.outputColorSpace = T.SRGBColorSpace;
  renderer.toneMapping = T.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.15;
  const scene = new T.Scene(), camera = new T.PerspectiveCamera(35, 1, .005, 60);
  scene.add(new T.HemisphereLight(0xe9efff, 0x4d3541, 2.1));
  const key = new T.DirectionalLight(0xffe5c6, 3); key.position.set(2, 4, 5); scene.add(key);
  const rim = new T.DirectionalLight(0x90badf, 2); rim.position.set(-3, 2, -2); scene.add(rim);
  const gunRig = new T.Group(); scene.add(gunRig);
  const loader = new GLTFLoader();
  const [gunAsset, slugAsset] = await Promise.all([loader.loadAsync('./blaster.glb'), loader.loadAsync('./inferno.glb')]);
  const gun = gunAsset.scene; gun.scale.set(1.375, 1.1, 1.1); gunRig.add(gun);
  gun.updateMatrixWorld(true);
  const chamberMesh = gun.getObjectByName('CanisterTeal');
  const chamberBox = new T.Box3().setFromObject(chamberMesh), centre = chamberBox.getCenter(new T.Vector3()), size = chamberBox.getSize(new T.Vector3());
  gun.traverse(o => {
    if (!o.isMesh) return;
    o.material = o.material.clone(); o.material.metalness = .25; o.material.roughness = .48;
    if (palette[o.name]) o.material.color.set('#' + palette[o.name]);
    if (o.name === 'CanisterTeal') { o.material = new T.MeshBasicMaterial({ color: 0xa5d8de, transparent: true, opacity: .055, depthWrite: false, side: T.FrontSide }); o.renderOrder = 10; }
    if (o.name === 'White') { o.material = new T.MeshBasicMaterial({ color: 0xeff9ff }); }
  });
  const bodyPivot = new T.Group(); gunRig.add(bodyPivot);
  const slug = slugAsset.scene; bodyPivot.add(slug);
  const mouthLine = slug.getObjectByName('InfernoMouthLine'); mouthLine.visible = false;
  slug.traverse(o => {
    if (!o.isMesh) return;
    o.frustumCulled = false;
    o.material = o.material.clone(); o.material.metalness = 0; o.material.roughness = .7;
    if (o.material.emissive) o.material.emissiveIntensity = .10;
    if (o.name === 'InfernoMouthInk') { o.material = new T.MeshBasicMaterial({ color: 0x291b17, side: T.DoubleSide }); }
  });
  outline(slug.getObjectByName('InfernoBody'));
  const box = new T.Box3().setFromObject(slug), slugCentre = box.getCenter(new T.Vector3()), slugSize = box.getSize(new T.Vector3());
  slug.position.sub(slugCentre);
  const oldFit = Math.min(size.x * .70 / slugSize.x, size.y * .69 / slugSize.z, size.z * .78 / slugSize.y);
  const fit = oldFit * 1.27;
  bodyPivot.scale.setScalar(fit); bodyPivot.position.copy(centre);
  const bones = {};
  slug.traverse(o => { if (o.isBone) bones[o.name] = { node: o, p: o.position.clone(), q: o.quaternion.clone() }; });
  // Thin the existing ink mesh toward the matching lip surface, retaining its topology and skin weights.
  const mouthMesh = slug.getObjectByName('InfernoMouth'), inkMesh = slug.getObjectByName('InfernoMouthInk');
  const inkPosition = inkMesh.geometry.attributes.position, lipPosition = mouthMesh.geometry.attributes.position;
  const inkRest = new Float32Array(inkPosition.array), inkThin = new Float32Array(inkRest.length);
  for(let i=0;i<inkPosition.count;i++) {
    const point=new T.Vector3().fromBufferAttribute(inkPosition,i); let nearest=0, distance=Infinity;
    for(let j=0;j<lipPosition.count;j++) { const d=point.distanceToSquared(new T.Vector3().fromBufferAttribute(lipPosition,j));if(d<distance){distance=d;nearest=j;} }
    const edge=new T.Vector3().fromBufferAttribute(lipPosition,nearest);
    const target=edge.addScaledVector(point.clone().sub(edge),.28);
    inkThin.set(target.toArray(),i*3);
  }
  const body = slug.getObjectByName('InfernoBody'); slug.updateMatrixWorld(true); body.skeleton.update();
  const restFoot = [], localPoint=new T.Vector3();let sole=Infinity;
  for(let i=0;i<body.geometry.attributes.position.count;i++) {
    body.getVertexPosition(i,localPoint);body.localToWorld(localPoint);bodyPivot.worldToLocal(localPoint);
    sole=Math.min(sole,localPoint.y);restFoot.push(localPoint.y);
  }
  const feet=restFoot.map((y,i)=>y<sole+.025?i:-1).filter(i=>i>=0);
  const fire = makeFlame(index); gunRig.add(fire);
  const light = new T.PointLight(0xff8a2c, 0, size.z * 3); gunRig.add(light);
  const frameMat = new T.MeshBasicMaterial({ color: 0x86b7cf, transparent: true, opacity: .32 });
  const radius = Math.min(size.x, size.y) / 2;
  const rings = [];
  for (const end of [-1, 1]) {
    const ring = new T.Mesh(new T.TorusGeometry(radius * 1.015, radius * .025, 6, 64), frameMat);
    ring.position.copy(centre).add(new T.Vector3(0, 0, end * size.z * .48)); gunRig.add(ring); rings.push(ring);
  }
  const stage = { index, canvas, renderer, scene, camera, gunRig, gun, slug, bodyPivot, bones, fire, light, centre, size, fit, oldFit, radius, rings, body, feet, inkMesh, inkRest, inkThin, phase: article.querySelector('.phase'), containment: 0, samples: 0 };
  let drag = null;
  canvas.addEventListener('pointerdown', e => { drag = [e.clientX, e.clientY]; canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener('pointermove', e => { if (!drag) return; state.yaw += (e.clientX - drag[0]) * .006; state.pitch = T.MathUtils.clamp(state.pitch + (e.clientY - drag[1]) * .004, -.8, .8); drag = [e.clientX, e.clientY]; });
  canvas.addEventListener('pointerup', () => { drag = null; });
  canvas.addEventListener('pointercancel', () => { drag = null; });
  canvas.addEventListener('wheel', e => { e.preventDefault(); state.zoom = T.MathUtils.clamp(state.zoom * Math.exp(e.deltaY * .001), .48, 2.8); }, { passive: false });
  stages.push(stage); return stage;
}

function update(stage, t) {
  const { gunRig, bodyPivot, bones, fire, index, centre, size, fit } = stage, spec = variants[index];
  const pose = gunPose(t); gunRig.position.copy(pose.position); gunRig.quaternion.copy(pose.q);
  for (const b of Object.values(bones)) { b.node.position.copy(b.p); b.node.quaternion.copy(b.q); }
  const action = acting(t, index), { looking, inhale, exhale, mouth: mouthAmount, press, lift, turn, smug } = action;
  const breath = exhale;
  const breathSway = .014 * Math.sin((t - spec.start) * 6) * exhale;
  // Already facing the holder before the raised chamber is revealed. The only turn is in the return hop.
  bodyPivot.quaternion.setFromEuler(new T.Euler(-Math.PI / 2, 0, 0));
  bodyPivot.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), Math.PI / 2 * looking));
  bodyPivot.position.copy(centre);
  const head = bones.head;
  const lag = Math.sin(Math.PI * turn);
  head.node.position.y += -.14 * press + .012 * inhale + .006 * exhale;
  const preparation=windowed(t,1.35,spec.end,.32), cheek=soft((t-spec.end)/.62)*looking;
  head.node.quaternion.multiply(new T.Quaternion().setFromEuler(new T.Euler(.12 * inhale - .075 * exhale + .09 * lift - .035*cheek, .10 * looking + .13 * lag + .04*cheek, spec.tilt * smug + breathSway + .045*inhale)));
  bones.body_upper.node.position.y -= .12 * press;
  bones.body_upper.node.quaternion.multiply(new T.Quaternion().setFromEuler(new T.Euler(.045 * inhale - .025 * exhale - .05 * lift, -.07 * lag, -.5 * spec.tilt * smug)));
  bones.body_lower.node.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), -.05 * lag));
  for (const tag of ['L', 'R']) {
    const bone = bones['antenna_' + tag];
    const follow = .028 * Math.sin(t * 3.4 - .35) + .06 * inhale - .04 * exhale + .12 * press - .08 * lift;
    bone.node.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 0, 1), (tag === 'L' ? 1 : -1) * follow));
    bones['antenna_tip_' + tag].node.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(1, 0, 0), .08 * Math.sin(t * 3.4 - .85) + .08 * press));
  }
  // Anticipation opens the eyes, exhaling concentrates them, and the returning grin lifts one cheek/lid.
  bones.lid_L.node.position.y += .014*inhale-.007*exhale+.004*cheek;
  bones.lid_R.node.position.y += .010*inhale-.009*exhale-.014*smug;
  bones.lid_L.node.position.x -= .004*exhale;
  bones.lid_R.node.position.x += .004*exhale;
  const opening=t<spec.end;
  const widthBlend=soft(mouthAmount), heightBlend=soft((mouthAmount-(opening?.08:.02))/(opening?.92:.98));
  for (const [name, b] of Object.entries(bones)) {
    if (/^mouth_[tb]\d$/.test(name)) {
      const k = +name.slice(-1), upper = name[6] === 't';
      const theta = upper ? Math.PI - k / 8 * Math.PI : Math.PI + k / 8 * Math.PI;
      const target = new T.Vector3(.008 + .038 * Math.cos(theta), .067 + .042 * Math.sin(theta), .278 + .004 * Math.sin(k / 8 * Math.PI));
      b.node.position.x=T.MathUtils.lerp(b.p.x,target.x,widthBlend);
      b.node.position.y=T.MathUtils.lerp(b.p.y,target.y,heightBlend);
      b.node.position.z=T.MathUtils.lerp(b.p.z,target.z,soft((mouthAmount-.12)/.88));
      const corner=Math.abs(k-4)/4;
      b.node.position.y+=(.010*preparation+.017*smug)*corner*(1-mouthAmount)*(k>4?1:.45);
    } else if (name === 'mouth_tail_L' || name === 'mouth_tail_R') {
      b.node.position.lerp(new T.Vector3(name.endsWith('L') ? -.031 : .047, .067, .277), mouthAmount);
    }
  }
  // The existing mouth surface becomes the cavity as its lip bones form an O; teeth return with the smug grin.
  const mouthMaterial = stage.slug.getObjectByName('InfernoMouth').material;
  const cavity = soft((mouthAmount - .36) / .64);
  mouthMaterial.color.setRGB(1 - .87 * cavity, 1 - .972 * cavity, 1 - .988 * cavity);
  const inkAmount=soft(mouthAmount);
  const inkPosition=stage.inkMesh.geometry.attributes.position;
  for(let i=0;i<inkPosition.array.length;i++)inkPosition.array[i]=T.MathUtils.lerp(stage.inkRest[i],stage.inkThin[i],inkAmount);
  inkPosition.needsUpdate=true;
  stage.inkMesh.material.color.set(0x291b17).lerp(new T.Color(0x74391e),inkAmount);
  // Seat the actual deformed sole on the rear inner cap. Only the airborne phase lifts it off that surface.
  gunRig.updateMatrixWorld(true); stage.body.skeleton.update();
  let footZ=-Infinity;const footPoint=new T.Vector3();
  for(const i of stage.feet){stage.body.getVertexPosition(i,footPoint);stage.body.localToWorld(footPoint);gunRig.worldToLocal(footPoint);footZ=Math.max(footZ,footPoint.z);}
  const support=centre.z+size.z*.43;
  const clearance=.085*fit*lift;
  bodyPivot.position.z+=support-footZ-clearance;
  stage.groundGap=clearance; stage.support=support;
  gunRig.updateMatrixWorld(true);
  stage.body.skeleton.update();
  const mouth = new T.Vector3();
  bones.mouth_t4.node.getWorldPosition(mouth);
  mouth.add(bones.mouth_b4.node.getWorldPosition(new T.Vector3())).multiplyScalar(.5);
  fire.position.copy(gunRig.worldToLocal(mouth));
  const forward = new T.Vector3(0, 0, -1).applyQuaternion(bodyPivot.quaternion).normalize();
  const flameUp = new T.Vector3(0, 1, 0).applyQuaternion(bodyPivot.quaternion).normalize();
  // The breath travels a little toward the holder, then curls sideways across the chamber window. Keeping the
  // curl off the viewing axis lets the designed lobes read rather than reducing the plume to an edge-on strip.
  const direction = forward.clone().multiplyScalar(.42).addScaledVector(new T.Vector3().crossVectors(forward, flameUp), -.91).normalize();
  fire.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(direction, flameUp, new T.Vector3().crossVectors(direction, flameUp)));
  deformFlame(fire, t, index);
  let scale = spec.reach * fit;
  fire.scale.setScalar(scale);
  // Bound the whole connected plume against the real chamber cylinder, not a decorative screen-space box.
  const verts = fire.children[0].geometry.attributes.position, radius = stage.radius * .90;
  let allowed = Infinity;
  for (let i = 0; i < verts.count; i++) {
    const v = new T.Vector3().fromBufferAttribute(verts, i).applyQuaternion(fire.quaternion);
    const o = fire.position.clone().sub(centre), a = v.x * v.x + v.y * v.y, b = 2 * (o.x * v.x + o.y * v.y), c = o.x * o.x + o.y * o.y - radius * radius;
    if (a > 1e-10) allowed = Math.min(allowed, (-b + Math.sqrt(Math.max(0, b * b - 4 * a * c))) / (2 * a));
    if (Math.abs(v.z) > 1e-8) allowed = Math.min(allowed, (Math.sign(v.z) * size.z * .46 - o.z) / v.z);
  }
  scale = Math.max(0, Math.min(scale, allowed)); fire.scale.setScalar(scale);
  stage.light.position.copy(fire.position); stage.light.intensity = .15 * breath;
  stage.containment = Math.max(stage.containment, scale > 0 && Number.isFinite(allowed) ? scale / allowed : 0); stage.samples++; stage.action = action;
  const isFire = state.mode === 'fire';
  stage.gun.visible = !isFire; bodyPivot.visible = !isFire; stage.rings.forEach(o => o.visible = !isFire);
  const target = isFire ? fire.position.clone().addScaledVector(direction, fire.scale.x * .55) : centre.clone();
  const worldTarget = gunRig.localToWorld(target);
  let distance = (isFire ? Math.max(fire.scale.x * 4.8, .12) : Math.max(size.z, size.x) * 2.4) * state.zoom;
  if (state.mode === 'gun') { worldTarget.set(0, .62, -.12); distance = 5.8 * state.zoom; }
  const cameraOffset = new T.Vector3(Math.sin(state.yaw) * Math.cos(state.pitch), Math.sin(state.pitch), Math.cos(state.yaw) * Math.cos(state.pitch)).multiplyScalar(distance);
  if (isFire) cameraOffset.applyQuaternion(fire.quaternion).applyQuaternion(gunRig.quaternion);
  stage.camera.position.copy(worldTarget).add(cameraOffset); stage.camera.lookAt(worldTarget);
  const width = Math.max(stage.canvas.clientWidth, 1), height = Math.max(stage.canvas.clientHeight, 1);
  if (stage.canvas.width !== Math.round(width * stage.renderer.getPixelRatio()) || stage.canvas.height !== Math.round(height * stage.renderer.getPixelRatio())) stage.renderer.setSize(width, height, false);
  stage.camera.aspect = width / height; stage.camera.updateProjectionMatrix();
  stage.phase.textContent = t < 1.48 ? 'Already watching you' : t < spec.start ? 'Smile to O / inhale' : fire.visible ? 'A flowing breath' : t < 4.50 ? 'A smug smile' : action.hopStage !== 'rest' ? 'Compress / spring / cushion' : 'Back in position';
  stage.renderer.render(stage.scene, stage.camera);
}

function renderAll() { for (const stage of stages) if (state.solo < 0 || state.solo === stage.index) update(stage, state.time); }
function setPlaying(value) { state.playing = value; document.querySelector('#play').textContent = value ? 'Pause' : 'Play'; }
function setMode(mode) {
  state.mode = mode; document.querySelectorAll('[data-mode]').forEach(b => b.setAttribute('aria-pressed', b.dataset.mode === mode));
  renderAll();
}
document.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => { setMode(b.dataset.mode); if (state.mode === 'fire') { state.time=2.2; setPlaying(true); } });
document.querySelector('#play').onclick = () => setPlaying(!state.playing);
document.querySelector('#replay').onclick = () => { state.time = 0; setPlaying(true); };
document.querySelector('#scrub').oninput = e => { state.time = +e.target.value; setPlaying(false); renderAll(); };
document.querySelector('#speed').onchange = e => { state.speed = +e.target.value; };
document.querySelectorAll('[data-time]').forEach(b => b.onclick = () => { state.time = +b.dataset.time; setPlaying(false); renderAll(); });
document.querySelector('#quarter').onclick = () => { state.yaw = -.35; state.pitch = .18; state.zoom = 1; };
document.querySelector('#side').onclick = () => { state.yaw = Math.PI / 2; state.pitch = .12; state.zoom = 1; };
document.querySelector('#reset-view').onclick = () => { state.yaw = .08; state.pitch = .18; state.zoom = 1; };
document.querySelectorAll('[data-solo]').forEach(b => b.onclick = () => {
  state.solo = +b.dataset.solo; document.querySelector('.studies').classList.add('focus');
  document.querySelectorAll('article').forEach(a => a.classList.toggle('focused', +a.dataset.version === state.solo)); document.querySelector('#compare').hidden = false;
});
document.querySelector('#compare').onclick = () => { state.solo = -1; document.querySelector('.studies').classList.remove('focus'); document.querySelector('#compare').hidden = true; };
document.addEventListener('keydown', e => { if (e.code === 'Space' && !['INPUT', 'SELECT', 'BUTTON'].includes(e.target.tagName)) { e.preventDefault(); setPlaying(!state.playing); } });
let previous = performance.now();
function frame(now) {
  if (state.playing) state.time = (state.time + Math.min((now - previous) / 1000, .1) * state.speed) % duration;
  if (state.playing && state.mode === 'fire' && (state.time < 2.06 || state.time > 4.34)) state.time=2.06;
  previous = now; renderAll();
  document.querySelector('#time').textContent = `${state.time.toFixed(2)} / 6.80 s`;
  document.querySelector('#scrub').value = state.time;
  requestAnimationFrame(frame);
}
try {
  await Promise.all([...document.querySelectorAll('article')].map((article, i) => makeStage(article, i)));
  stages.sort((a, b) => a.index - b.index);
  window.inspectPreview = {
    ready: true, state, errors,
    sample(t, mode = state.mode) { state.time = t; setPlaying(false); setMode(mode); state.time = t; renderAll(); return this.stats(); },
    stats() { return { models: stages.length, errors, time: state.time, mode: state.mode, containment: stages.map(s => s.containment), triangles: stages.map(s => s.renderer.info.render.triangles), dimensions: stages.map(s => ({ chamber: s.size.toArray(), fit: s.fit, sizeIncrease:s.fit/s.oldFit, groundGap:s.groundGap })), acting: stages.map(s => s.action), flow: stages.map(s => ({visible:s.fire.visible,head:s.fire.userData.head,tail:s.fire.userData.tail})) }; },
    fitMetrics(index) {
      const s=stages[index],p=new T.Vector3();let foot=-Infinity,radial=0,front=Infinity;
      s.body.skeleton.update();
      for(let i=0;i<s.body.geometry.attributes.position.count;i++){
        s.body.getVertexPosition(i,p);s.body.localToWorld(p);s.gunRig.worldToLocal(p);
        radial=Math.max(radial,Math.hypot(p.x-s.centre.x,p.y-s.centre.y));front=Math.min(front,p.z);
      }
      for(const i of s.feet){s.body.getVertexPosition(i,p);s.body.localToWorld(p);s.gunRig.worldToLocal(p);foot=Math.max(foot,p.z);}
      return {radialRatio:radial/s.radius,groundGap:s.support-foot,intendedGap:s.groundGap,frontMargin:front-(s.centre.z-s.size.z*.48),sizeIncrease:s.fit/s.oldFit};
    },
    expression(index) {const s=stages[index];return {leftLid:s.bones.lid_L.node.position.toArray(),rightLid:s.bones.lid_R.node.position.toArray(),head:s.bones.head.node.quaternion.toArray(),mouthColor:s.slug.getObjectByName('InfernoMouth').material.color.toArray(),inkColor:s.inkMesh.material.color.toArray()};},
    geometry(index) { return Array.from(stages[index].fire.children[0].geometry.attributes.position.array); },
    mouth(index) { const b=stages[index].bones; return ['mouth_t4','mouth_b4','mouth_t0','mouth_t8'].map(n=>b[n].node.position.toArray()); },
    capture(index) { return stages[index].canvas.toDataURL('image/png'); },
    gunPose(t) { const p = gunPose(t); return [...p.position.toArray(), ...p.q.toArray()]; },
  };
  setPlaying(state.playing); requestAnimationFrame(frame);
} catch (error) {
  errors.push(String(error)); const label = document.querySelector('#error'); label.hidden = false; label.textContent = 'The preview could not load: ' + error;
  console.error(error);
}

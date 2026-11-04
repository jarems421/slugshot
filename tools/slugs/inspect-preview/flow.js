import * as T from 'three';

const clamp = x => T.MathUtils.clamp(x, 0, 1);
const ease = x => { x = clamp(x); return clamp(x * x * x * (10 - 15 * x + 6 * x * x)); };
export const variants = [
  { name: 'Rolling flame', start: 2.06, end: 3.75, reach: .46, tilt: -.08, rate: 1, curl: .19, arc: 1.28 },
  { name: 'Slow curl', start: 2.06, end: 3.95, reach: .49, tilt: -.13, rate: .78, curl: .23, arc: 1.58 },
  { name: 'Playful flame', start: 2.06, end: 3.65, reach: .44, tilt: .09, rate: 1.17, curl: .17, arc: 1.10 },
];

export function acting(t, index) {
  const spec = variants[index];
  const mouth = ease((t - 1.48) / .55) * (1 - ease((t - spec.end) / .32));
  const exhale = ease((t - spec.start) / .25) * (1 - ease((t - spec.end) / .30));
  const inhale = Math.sin(Math.PI * clamp((t - 1.40) / .60)) ** 2;
  // Same four-stage timing as the current grove hop, compressed to fit before the unchanged gun lowering.
  const elapsed = t - 4.50, windup = .30, hold = .10, air = .58, land = .38;
  let press = 0, lift = 0, turn = 0, hopStage = 'rest';
  if (elapsed >= 0 && elapsed < windup) { press = .36 * ease(elapsed / windup); hopStage = 'windup'; }
  else if (elapsed >= windup && elapsed < windup + hold) { press = .36; hopStage = 'hold'; }
  else if (elapsed >= windup + hold && elapsed < windup + hold + air) {
    const u = (elapsed - windup - hold) / air;
    lift = 4 * u * (1 - u);
    press = .36 * (1 - ease(u / .14)) - .18 * Math.sin(Math.PI * Math.min(u / .5, 1)) + .05 * ease((u - .88) / .12);
    turn = ease((u - .08) / .79); hopStage = 'air';
  } else if (elapsed >= windup + hold + air && elapsed < windup + hold + air + land) {
    const u = (elapsed - windup - hold - air) / land;
    press = u < .18 ? .05 + .45 * ease(u / .18) : .50 * (1 - ease((u - .18) / .82));
    turn = 1; hopStage = 'land';
  } else if (elapsed >= windup + hold + air + land) turn = 1;
  const smug = ease((t - spec.end - .12) / .25) * (1 - ease((t - 4.50) / .20));
  return { mouth, exhale, inhale, press, lift, turn, smug, hopStage, looking: 1 - turn };
}

export function makeFlame(index) {
  const length = 56, sides = 20, positions = [], uv = [], indices = [];
  for (let i = 0; i <= length; i++) for (let j = 0; j <= sides; j++) {
    positions.push(0, 0, 0); uv.push(i / length, j / sides);
    if (i < length && j < sides) {
      const a = i * (sides + 1) + j, b = a + sides + 1;
      indices.push(a, b, a + 1, a + 1, b, b + 1);
    }
  }
  const geometry = new T.BufferGeometry();
  geometry.setAttribute('position', new T.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new T.Float32BufferAttribute(uv, 2)); geometry.setIndex(indices);
  const material = new T.ShaderMaterial({
    side: T.DoubleSide, transparent: true, uniforms: { clock: { value: 0 }, fade: { value: 1 } },
    vertexShader: `varying vec2 flowUV; varying vec3 surfaceNormal; varying vec3 view;
      void main(){flowUV=uv;surfaceNormal=normalize(normalMatrix*normal);vec4 mv=modelViewMatrix*vec4(position,1.);view=-mv.xyz;gl_Position=projectionMatrix*mv;}`,
    fragmentShader: `uniform float clock;uniform float fade;varying vec2 flowUV;varying vec3 surfaceNormal;varying vec3 view;
      void main(){float u=flowUV.x,theta=flowUV.y*6.283185;
        float roll=sin(u*23.-clock*11.+sin(theta*3.+u*5.-clock*4.)*.9);
        float ribbon=sin(theta*2.-u*14.+clock*7.);
        float heat=.32+.21*roll+.12*ribbon+.11*(1.-u);
        vec3 c=mix(vec3(.88,.045,.008),vec3(1.,.24,.012),smoothstep(.10,.38,heat));
        c=mix(c,vec3(1.,.62,.065),smoothstep(.38,.61,heat));
        c=mix(c,vec3(1.,.89,.42),smoothstep(.64,.79,heat));
        float facing=abs(dot(normalize(surfaceNormal),normalize(view)));
        c=mix(vec3(.45,.055,.018),c,smoothstep(.035,.32,facing));
        gl_FragColor=vec4(c,fade);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  const fire = new T.Group(), mesh = new T.Mesh(geometry, material);
  mesh.frustumCulled = false; fire.add(mesh); fire.userData = { index, length, sides, head: 0, tail: 0 };
  return fire;
}

export function deformFlame(fire, t, index) {
  const spec = variants[index], { length, sides } = fire.userData;
  const head = ease((t - spec.start) / .34), tail = ease((t - spec.end) / .38);
  fire.userData.head = head; fire.userData.tail = tail;
  const mesh = fire.children[0], position = mesh.geometry.attributes.position;
  const clock = t * spec.rate;
  const centre = u => {
    if (u < .64) return [.94 * u, .045 * Math.sin(u * 9 - clock * 5) * u * u];
    const q = (u - .64) / .36;
    const a = -Math.PI / 2 + q * Math.PI * spec.arc + .08 * q * Math.sin(clock * 5 - u * 11);
    const curl = spec.curl * (1 + .07 * q * Math.sin(clock * 5 - u * 8));
    const joinY = .045 * Math.sin(.64 * 9 - clock * 5) * .64 * .64;
    return [.6016 + curl * Math.cos(a), joinY + curl * (1 + Math.sin(a)) + .015 * q * Math.sin(clock * 6 + u * 4)];
  };
  for (let i = 0; i <= length; i++) {
    const s = i / length, u = tail + (head - tail) * s, p = centre(u), next = centre(Math.min(u + .001, 1));
    let dx = next[0] - p[0], dy = next[1] - p[1], mag = Math.hypot(dx, dy);
    if (mag < 1e-7) { dx = .001; dy = 0; mag = .001; }
    const end = Math.sin(Math.PI * s) ** .55;
    const base = (.022 + .18 * Math.max(0, Math.sin(Math.PI * u)) ** .85) * end;
    for (let j = 0; j <= sides; j++) {
      const theta = j / sides * Math.PI * 2;
      const ripple = 1 + .14 * Math.sin(theta * 3 + u * 20 - clock * 10) + .065 * Math.sin(theta * 5 - u * 17 + clock * 13);
      const r = Math.max(.0006, base * ripple), wave = .030 * u * Math.sin(u * 16 - clock * 7) * end;
      position.setXYZ(i * (sides + 1) + j, p[0] - dy / mag * Math.cos(theta) * r, p[1] + dx / mag * Math.cos(theta) * r + wave, Math.sin(theta) * r * .86);
    }
  }
  position.needsUpdate = true; mesh.geometry.computeVertexNormals();
  mesh.material.uniforms.clock.value = clock;
  mesh.material.uniforms.fade.value = 1 - ease((t - spec.end - .22) / .16);
  fire.visible = head - tail > .001 && t >= spec.start;
}

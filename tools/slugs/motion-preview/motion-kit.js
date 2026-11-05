// The browser twin of experiments/creatures/shared/MotionKit.luau. Keep the two line for line;
// tests/slugs/test_motion_kit.py holds both to the same golden numbers.
const TAU = 2 * Math.PI;
const clamp01 = x => Math.min(1, Math.max(0, x));

export const TIME_STEP = 1 / 120;
export const fromStiffness = (stiffness, damping) => ({ freq: stiffness / TAU, damp: damping });
export const spring = (tune, start = 0) => ({ x: start, v: 0, target: start, freq: tune.freq, damp: tune.damp });

export function stepSpring(s, dt) {
  const w = TAU * s.freq;
  s.v += (w * w * (s.target - s.x) - 2 * s.damp * w * s.v) * dt;
  s.x += s.v * dt;
}

export const kick = (s, speed) => { s.v += speed; };
export const clock = () => ({ leftover: 0 });

export function advance(c, dt, step) {
  let owed = Math.min(dt, 0.1) + c.leftover;
  while (owed >= TIME_STEP) { owed -= TIME_STEP; step(TIME_STEP); }
  c.leftover = owed;
}

export function stepChain(chain, target, dt) {
  let lead = target;
  for (const s of chain) { s.target = lead; stepSpring(s, dt); lead = s.x; }
}

export const ease = share => { const t = clamp01(share); return t * t * (3 - 2 * t); };
export const soft = share => { const t = clamp01(share); return t * t * t * (10 - 15 * t + 6 * t * t); };
export const arc = share => Math.sin(clamp01(share) * Math.PI);
export const pulse = (t, at, length) => Math.sin(Math.PI * clamp01((t - at) / length)) ** 2;
export const windowed = (t, start, finish, fade) => ease((t - start) / fade) * (1 - ease((t - finish) / fade));
export const ballistic = u => { const t = clamp01(u); return 4 * t * (1 - t); };
export const hopLength = h => h.windup + h.hold + h.air + h.land;

export function hop(elapsed, h) {
  const air = elapsed - h.windup - h.hold;
  if (elapsed < 0) return { stage: 'rest', press: 0, lift: 0, air: 0 };
  if (elapsed < h.windup) return { stage: 'windup', press: h.press * ease(elapsed / h.windup), lift: 0, air: 0 };
  if (air < 0) return { stage: 'hold', press: h.press, lift: 0, air: 0 };
  if (air < h.air) {
    const u = air / h.air;
    return { stage: 'air', press: h.press * (1 - ease(u / 0.14)) - h.stretch * Math.sin(Math.PI * Math.min(u / 0.5, 1)), lift: ballistic(u), air: u };
  }
  if (air < h.air + h.land) {
    const u = (air - h.air) / h.land;
    return { stage: 'land', press: u < 0.18 ? h.landPress * ease(u / 0.18) : h.landPress * (1 - ease((u - 0.18) / 0.82)), lift: 0, air: 1 };
  }
  return { stage: 'rest', press: 0, lift: 0, air: 1 };
}

export const tunes = {
  floppySquash: { freq: 5, damp: 0.26 },
  floppySway: { freq: 3.4, damp: 0.42 },
  floppyLag: { freq: 2.6, damp: 0.34 },
  floppyTip: { freq: 2.2, damp: 0.4 },
  floppyPitch: { freq: 1.8, damp: 0.8 },
  floppyFlop: { freq: 2.4, damp: 0.5 },
  floppyStand: { freq: 2.2, damp: 0.8 },
  infernoLook: fromStiffness(6, 0.8),
  infernoRise: fromStiffness(20, 0.8),
  infernoCrouch: fromStiffness(18, 0.6),
  infernoFlip: fromStiffness(26, 0.9),
  infernoChin: fromStiffness(12, 0.6),
  infernoWhip: fromStiffness(9, 0.35),
  infernoWhipTip: fromStiffness(7, 0.4),
  infernoMood: fromStiffness(5.5, 1),
};

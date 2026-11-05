// Prints the kit's golden numbers as JSON, so the Python test can hold the Luau spec to the same values.
import { advance, arc, ballistic, clock, ease, hop, kick, pulse, soft, spring, stepChain, stepSpring, tunes, windowed } from './motion-preview/motion-kit.js';

const round = x => +x.toFixed(6);

function settle(tune, seconds, frameRate) {
  const s = spring(tune), c = clock();
  s.target = 1;
  let peak = 0;
  for (let i = 0; i < Math.round(seconds * frameRate); i++) advance(c, 1 / frameRate, dt => { stepSpring(s, dt); peak = Math.max(peak, s.x); });
  return { x: round(s.x), peak: round(peak) };
}

function chain() {
  const a = [spring(tunes.floppyLag), spring(tunes.floppyTip)];
  for (let i = 0; i < 60; i++) stepChain(a, 1, 1 / 120);
  return a.map(s => round(s.x));
}

function kicked() {
  const s = spring(tunes.floppySquash);
  kick(s, 3);
  for (let i = 0; i < 6; i++) stepSpring(s, 1 / 120);
  return round(s.x);
}

const shape = { windup: 0.3, hold: 0.1, air: 0.58, land: 0.38, press: 0.36, stretch: 0.18, landPress: 0.5 };
const hopAt = t => { const h = hop(t, shape); return [h.stage, round(h.press), round(h.lift)]; };

console.log(JSON.stringify({
  squash60: settle(tunes.floppySquash, 0.5, 60),
  squash30: settle(tunes.floppySquash, 0.5, 30),
  flip60: settle(tunes.infernoFlip, 0.25, 60),
  chain: chain(),
  kick: kicked(),
  ease: round(ease(0.3)),
  soft: round(soft(0.3)),
  arc: round(arc(0.25)),
  pulse: round(pulse(1.2, 1, 0.5)),
  window: round(windowed(0.5, 0.4, 1, 0.25)),
  ballistic: round(ballistic(0.25)),
  hop: [-0.1, 0.15, 0.35, 0.5, 0.9, 1.0, 1.2, 1.5].map(hopAt),
}, null, 1));

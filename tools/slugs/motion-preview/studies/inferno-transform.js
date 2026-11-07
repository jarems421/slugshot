// A tool demonstration at real combat timing. Concept A is the game's numbers (Combat.Slugs.Inferno, TransformationStyles
// and SlugTransformation); B and C only show what a different timing does. Neither is a proposal.
const SPEED = 500, CRUISE = 0.4, SLOWDOWN = 0.04, RANGE = 120, FORM_SCALE = 2.6;
const flight = t => SPEED * (CRUISE * t + (1 - CRUISE) * SLOWDOWN * (1 - Math.exp(-t / SLOWDOWN)));
const position = t => [0, 3, -2 - flight(t)];
const hitAt = (() => { let t = 0; while (flight(t) < RANGE) t += 1 / 240; return t; })();
const GLOW = 0xff7a1c, TAU = 2 * Math.PI;

function concept(letter, name, note, m) {
  return {
    letter, name, note,
    beatLabel: t => t >= hitAt ? 'Hit' : t < m.spin ? 'Twirl and glow' : t < m.spin + m.reveal ? 'Swap and reveal' : 'Final form in flight',
    pose(rig, t) {
      const at = position(Math.min(t, hitAt)), into = t / m.spin;
      if (into < 1) {
        const angle = TAU * m.turns * into * into;
        rig.show('base');
        rig.place('base', at, [-Math.PI / 2, Math.PI, angle], 1 - (1 - 0.68) * Math.max(into - 0.5, 0) * 2);
        rig.glow(0.8 * into * into, 3 + 9 * into, GLOW, at);
        return;
      }
      const since = t - m.spin, reveal = kit.ease(since / m.reveal);
      const fold = 1 - kit.ease(since / (m.reveal * 1.3));
      rig.show('dragon');
      rig.place('dragon', at, [0, 0, m.roll * (1 - reveal) + 0.08 * Math.sin(since * 7) * reveal], FORM_SCALE * (0.72 + 0.28 * reveal));
      const beat = 0.14 * Math.sin(t * 9 * TAU / 2);
      for (const [s, tag] of [[-1, 'L'], [1, 'R']]) {
        rig.drive('dragon', `wing_${tag}`, null, 0, 0, -s * (beat - 1.1 * fold));
        rig.drive('dragon', `wing_tip_${tag}`, null, 0, 0, -s * (0.9 * beat - 1.1 * fold));
      }
      rig.glow(0.8 * (1 - kit.ease(since / 0.12)), 12, GLOW, at);
      if (t >= hitAt) rig.show('none');
    },
  };
}

export default {
  id: 'inferno-transform',
  title: 'Inferno transformation',
  eyebrow: 'MOTION STUDY / TOOL DEMONSTRATION',
  brief: 'A full-charge shot at 500 studs/s to a target 120 studs away, seen from the shooter. Watch at 1× first: the swap happens more than 40 studs from the camera.',
  status: 'Shows the tool working. A is the game’s current timing; B and C are illustrations, not proposals.',
  note: 'Browser approximation: no arms, gun, wing fire or aura image. The shared transformation still needs the owner’s verdict in Studio, which is where feel is judged.',
  duration: 0.8,
  frame: 18,
  snapLimit: 0.5,
  forms: {
    base: { model: 'inferno-base', size: 2, spacing: { bones: ['antenna_L', 'antenna_R'], units: 0.72 }, hide: ['InfernoMouthLine'] },
    dragon: { model: 'inferno-dragon', size: 2, turn: Math.PI, spacing: { bones: ['antenna_L', 'antenna_R'], units: 0.6 }, hide: ['InfernoDragonMouthLine'] },
  },
  beats: [
    { t: 0, label: 'Launch' },
    { t: 0.15, label: 'Swap (A, B)' },
    { t: 0.25, label: 'Reveal done (A)' },
    { t: +hitAt.toFixed(3), label: 'Hit' },
  ],
  swaps: [i => [0.15, 0.15, 0.08][i]],
  focus: t => { const p = position(Math.min(t, hitAt)); return [p[0], p[1] + 1, p[2]]; },
  // The shooter's eye, a little behind and above the muzzle, looking down the shot.
  gameplayCamera: () => ({ position: [0.6, 4.5, 2], target: [0, 3.2, -60], fov: 70 }),
  concepts: [
    concept('A', 'Current game timing', 'The numbers in the game: 1.75 turns, swap at 0.15 s, 0.1 s reveal from 72% scale.', { spin: 0.15, turns: 1.75, reveal: 0.1, roll: 0.45 }),
    concept('B', 'Slower reveal', 'The same swap with a 0.22 s reveal and more roll, so the unfold takes longer to play.', { spin: 0.15, turns: 1.75, reveal: 0.22, roll: 0.9 }),
    concept('C', 'Earlier swap', 'Swap at 0.08 s, when the slug is still close to the shooter, with a 0.16 s reveal.', { spin: 0.08, turns: 1.25, reveal: 0.16, roll: 0.45 }),
  ],
};

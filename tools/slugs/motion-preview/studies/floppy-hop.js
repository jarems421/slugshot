// A tool demonstration on a grounded rig: one kit hop, three personalities. Not a proposal for Floppy's approved acting.
const SQUASH_UPPER = 0.38, SQUASH_HEAD = 0.03, PITCH_HEAD = 0.38;
const HOP_HEIGHT = 0.38 * 2;

function concept(letter, name, note, shape, tunes, landKick) {
  const start = 0.35, landAt = start + shape.windup + shape.hold + shape.air;
  return {
    letter, name, note,
    springs: { squash: tunes.squash, lag: tunes.lag, tip: tunes.tip, pitch: kit.tunes.floppyPitch },
    beatLabel: t => { const stage = kit.hop(t - start, shape).stage; return stage === 'rest' ? (t < start ? 'Resting' : 'Settling') : stage; },
    step(t, s, first) {
      const h = kit.hop(t - start, shape);
      s.squash.target = h.press;
      s.lag.target = s.squash.x;
      s.tip.target = s.lag.x;
      s.pitch.target = h.stage === 'windup' || h.stage === 'hold' ? -0.35 : 0.1 * h.lift;
      if (!first && Math.abs(t - landAt) < kit.TIME_STEP / 2) kit.kick(s.squash, landKick);
    },
    pose(rig, t, c) {
      const h = kit.hop(t - start, shape);
      rig.show('floppy');
      rig.place('floppy', [0, HOP_HEIGHT * h.lift, 0]);
      rig.drive('floppy', 'body_upper', [0, -SQUASH_UPPER * c.squash, 0]);
      rig.drive('floppy', 'head', [0, -SQUASH_HEAD * c.squash, 0], -PITCH_HEAD * c.pitch);
      rig.drive('floppy', 'antenna_L', null, 0.4 * c.lag, 0, -0.5 * c.tip);
      rig.drive('floppy', 'antenna_R', null, 0.4 * c.lag, 0, 0.5 * c.tip);
    },
  };
}

export default {
  id: 'floppy-hop',
  title: 'Floppy hop',
  eyebrow: 'MOTION STUDY / TOOL DEMONSTRATION',
  brief: 'One hop built from the shared motion kit, with three different timings on Floppy’s rig. The point is that the same technique can give clearly different personalities.',
  status: 'Shows the tool working on a second rig. None of these is a proposal for Floppy.',
  note: 'Browser approximation of the rig only: no face driver, eye rings or chamber. A slug’s inspect is judged from the real first-person camera in Studio.',
  duration: 2.4,
  frame: 6,
  snapLimit: 0.12,
  forms: {
    floppy: { model: 'floppy', size: 2, spacing: { bones: ['eye_L', 'eye_R'], units: 0.74 } },
  },
  beats: [
    { t: 0, label: 'Rest' },
    { t: 0.35, label: 'Gather' },
    { t: 0.75, label: 'Leave the floor' },
    { t: 1.3, label: 'Landing and settle' },
  ],
  focus: () => [0, 1.1, 0],
  gameplayCamera: () => ({ position: [2.5, 5, 9], target: [0, 1, 0], fov: 70 }),
  concepts: [
    concept('A', 'Drowsy flop', 'Slow gather, floaty air, a long jelly wobble on landing. The springs are Floppy’s own.',
      { windup: 0.3, hold: 0.1, air: 0.58, land: 0.38, press: 0.8, stretch: 0.4, landPress: 0.7 },
      { squash: kit.tunes.floppySquash, lag: kit.tunes.floppyLag, tip: kit.tunes.floppyTip }, 3),
    concept('B', 'Spring-loaded', 'A sharp snap off the floor and a tight stop. Same technique, Inferno’s stiffer springs.',
      { windup: 0.14, hold: 0.04, air: 0.34, land: 0.2, press: 1, stretch: 0.7, landPress: 0.6 },
      { squash: kit.tunes.infernoCrouch, lag: kit.tunes.infernoChin, tip: kit.tunes.infernoWhip }, 1),
    concept('C', 'Reluctant', 'A long, doubtful crouch, a small hop and very little follow-through.',
      { windup: 0.55, hold: 0.25, air: 0.3, land: 0.3, press: 0.5, stretch: 0.15, landPress: 0.3 },
      { squash: kit.tunes.floppyStand, lag: kit.tunes.floppyPitch, tip: kit.tunes.floppyPitch }, 0.5),
  ],
};

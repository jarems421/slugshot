"""Author exactly five original procedural sound sketches for owner review.

No recordings, downloaded samples, model service, asset IDs or runtime changes.
Requires the existing NumPy installation. Outputs mono PCM16 WAV at 48 kHz.
"""
from pathlib import Path
import hashlib
import json
import math
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/source/audio/style-test-v1"
RATE = 48000
RNG = np.random.default_rng(20261102)


def clock(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def noise(t, low, high):
    # Smooth spectral shoulders avoid a brittle brick-wall noise band.
    n = RNG.normal(size=len(t))
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    shape = 1 / np.sqrt(1 + (frequencies / high) ** 8)
    if low:
        shape *= 1 - 1 / np.sqrt(1 + (frequencies / low) ** 8)
    n = np.fft.irfft(np.fft.rfft(n) * shape, n=len(t))
    return n / max(np.std(n), 1e-9)


def decay(t, attack, tail):
    return (1 - np.exp(-t / attack)) * np.exp(-t / tail)


def sweep(t, start, end, rate):
    # Integral of an exponential pitch envelope, continuous in phase.
    phase = end * t + (start - end) * rate * (1 - np.exp(-t / rate))
    return np.sin(2 * math.pi * phase)


def modes(t, fundamental, tail, ratios=(1, 2.13, 3.71, 5.43)):
    result = np.zeros_like(t)
    for i, ratio in enumerate(ratios):
        frequency = fundamental * ratio * RNG.uniform(0.995, 1.005)
        result += np.sin(2 * math.pi * frequency * t) * decay(t, 0.0008, tail / (1 + i * 0.7)) / (1 + i) ** 1.4
    return result


def place(target, at, sound, gain=1):
    start = round(at * RATE)
    count = min(len(sound), len(target) - start)
    target[start:start + count] += sound[:count] * gain


def shot():
    t = clock(0.62)
    # Pneumatic snap, chunky body and a small resonant fantasy accent.
    result = 0.35 * noise(t, 600, 6500) * decay(t, 0.0005, 0.018)
    result += 0.57 * sweep(t, 190, 68, 0.018) * decay(t, 0.001, 0.065)
    result += 0.15 * noise(t, 100, 1600) * decay(t, 0.001, 0.075)
    result += 0.14 * modes(t, 530, 0.105)
    tail = noise(t, 350, 3200) * decay(t, 0.006, 0.058)
    place(result, 0.035, tail, 0.07)
    return result


def charge():
    t = clock(1.65)
    # Mechanical air/motor texture, three tactile catches, then a brief full-charge hold.
    progress = np.minimum(t / 1.05, 1)
    frequency = 96 + 110 * progress ** 0.7
    phase = np.cumsum(frequency) / RATE
    hum = np.sin(2 * math.pi * phase) + 0.28 * np.sin(2 * math.pi * phase * 2.11)
    envelope = np.minimum(t / 0.09, 1) * np.clip((1.5 - t) / 0.25, 0, 1)
    result = 0.13 * hum * envelope * (0.45 + 0.55 * progress)
    result += 0.038 * noise(t, 400, 2900) * envelope * (0.65 + 0.35 * np.sin(2 * math.pi * 19 * t))
    for index, at in enumerate((0.32, 0.64, 0.96)):
        tc = clock(0.36)
        catch = 0.15 * noise(tc, 1100, 5000) * decay(tc, 0.0005, 0.013)
        catch += 0.19 * modes(tc, 270 + 85 * index, 0.055)
        catch += 0.1 * sweep(tc, 150, 80, 0.01) * decay(tc, 0.001, 0.028)
        place(result, at, catch, 0.8 + 0.15 * index)
    tc = clock(0.45)
    place(result, 1.0, modes(tc, 890, 0.1), 0.07)
    return result


def damage():
    t = clock(0.43)
    result = 0.38 * sweep(t, 140, 57, 0.025) * decay(t, 0.001, 0.048)
    result += 0.29 * noise(t, 180, 2600) * decay(t, 0.0008, 0.035)
    result += 0.10 * modes(t, 175, 0.038, (1, 1.51, 2.7))
    place(result, 0.025, noise(t, 650, 3600) * decay(t, 0.003, 0.035), 0.055)
    return result


def footstep():
    t = clock(0.40)
    # Boot/cloth friction, broad sole contact and a few tiny stone grains.
    result = 0.16 * noise(t, 450, 5200) * decay(t, 0.004, 0.025)
    result += 0.30 * sweep(t, 105, 61, 0.018) * decay(t, 0.002, 0.035)
    place(result, 0.012, noise(t, 200, 2100) * decay(t, 0.003, 0.042), 0.13)
    for at in (0.020, 0.033, 0.055):
        place(result, at, modes(t, RNG.uniform(1600, 2300), 0.008), 0.025)
    return result


def menu_click():
    t = clock(0.24)
    result = 0.22 * modes(t, 410, 0.027, (1, 2.41, 4.1))
    result += 0.11 * noise(t, 1000, 5700) * decay(t, 0.0005, 0.006)
    place(result, 0.009, modes(t, 1230, 0.024), 0.035)
    return result


def master(signal, gain):
    assert np.isfinite(signal).all()
    signal -= signal.mean()
    signal = np.tanh(signal * 1.35)
    signal *= gain / max(np.max(np.abs(signal)), 1e-9)
    fade = round(0.006 * RATE)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade:] *= np.linspace(1, 0, fade)
    return signal


def write_wav(path, signal):
    samples = np.rint(signal * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(samples.tobytes())
    return samples


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    specs = [
        ("01-blaster-shot", "Blaster shot", shot, 0.70, "Dry pressure snap, weight, short crystal-metal tail."),
        ("02-charge-three-stages", "Charge: three stages", charge, 0.54, "Air/motor bed with catches at 0.32, 0.64 and 0.96 seconds; short full hold. This is a review phrase, not a seamless runtime loop."),
        ("03-taking-damage", "Taking damage", damage, 0.60, "A dense body/cloth impact; distinct from the shooter's future hit-confirmation tick."),
        ("04-stone-footstep", "Stone footstep", footstep, 0.39, "One boot contact with stone grain and cloth friction; a single sketch, not a walk sequence."),
        ("05-menu-click", "Menu click", menu_click, 0.21, "A short tactile ceramic-wood click with a trace of crystal."),
    ]
    manifest = {"status": "Considering: owner review only", "sample_rate": RATE, "channels": 1,
                "encoding": "PCM16", "provenance": "Original procedural synthesis from tools/audio/build_style_test.py; no external samples or franchise audio.",
                "seed": 20261102, "files": []}
    reel = [np.zeros(round(0.4 * RATE))]
    reel_time = 0.4
    for name, title, builder, gain, description in specs:
        signal = master(builder(), gain)
        path = OUT / (name + ".wav")
        samples = write_wav(path, signal)
        entry = {"file": path.name, "title": title, "description": description,
                 "seconds": round(len(signal) / RATE, 3), "reel_start_seconds": round(reel_time, 3),
                 "sample_peak_dbfs": round(20 * math.log10(np.max(np.abs(samples.astype(float))) / 32768), 2),
                 "rms_dbfs": round(20 * math.log10(np.sqrt(np.mean((samples.astype(float) / 32768) ** 2))), 2),
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        assert np.max(np.abs(samples.astype(float))) < 32767, "Clipping"
        assert samples[0] == samples[-1] == 0, "Boundary discontinuity"
        manifest["files"].append(entry)
        reel += [signal, np.zeros(round(0.7 * RATE))]
        reel_time += len(signal) / RATE + 0.7
    write_wav(OUT / "00-review-reel.wav", np.concatenate(reel))
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    audio_root = "../../assets/source/audio/style-test-v1/"
    cards = "\n".join(f'<article><h2>{e["title"]}</h2><p>{e["description"]}</p><audio controls preload="none" src="{audio_root}{e["file"]}"></audio><p class="meta">{e["seconds"]} s · mono 48 kHz · peak {e["sample_peak_dbfs"]} dBFS</p></article>' for e in manifest["files"])
    html = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Slugshot sound style test 1</title>
<style>body{{margin:40px auto;padding:0 20px;max-width:820px;background:#151a24;color:#e6ebef;font:17px/1.5 system-ui}}h1{{font-size:32px}}h2{{font-size:21px}}article{{padding:14px 22px;margin:16px 0;background:#222c37;border:2px solid #091019;border-radius:14px}}audio{{width:100%}}.meta{{color:#a5b9c1;font-size:14px}}a{{color:#b3ddc7}}</style>
<h1>Slugshot: sound direction, test 1</h1><p>Five original authored sketches. Chunky tactile attacks, soft organic body, restrained crystal colour. Start at a comfortable listening volume. Compare character and relative weight; these are dry previews, before the game mix.</p>
<article><h2>All five, in order</h2><audio controls preload="none" src="{audio_root}00-review-reel.wav"></audio><p>Shot → charge → damage → footstep → menu click. Each separated by 0.7 seconds.</p></article>
{cards}<p>No uploads or game integration. Approval requested for the <a href="sound-plan.md">event list and sound direction</a> before creating any more sounds. Numeric checks passed; auditory taste and Roblox playback remain unverified.</p></html>'''
    (ROOT / "docs/audio/style-test-v1.html").write_text(html, encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()

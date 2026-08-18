# Les sons de la DÉCOUPE (passe 3), méthode maison sans couture.
#
# braise-eparse / braise-dense (2,25 s chacune) — le crépitement qui suit
#   le doigt : lit de souffle de feu (bruit rose spectral, donc périodique)
#   + claquements de Poisson sur timeline CIRCULAIRE (éparse ~15/s, dense
#   ~55/s), fondues l'une vers l'autre selon la vitesse du geste.
# feerie-carillon (one-shot ~2,7 s) — l'arpège pentatonique ascendant de
#   l'ouverture : cloches détunées ±4 cents, poussière de grains glissants,
#   réverbe longue (pas de contrainte de boucle : c'est un one-shot).
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(31)


def write(path, mix, peak_db):
    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 10 ** (peak_db / 20)
    pcm = (mix * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", path)


def crackle(path, pops_per_s):
    L = 2.25
    N = int(SR * L)
    # Le lit : souffle de feu — bruit façonné en spectre (périodique),
    # bande 500 Hz – 4,5 kHz, modulation lente.
    freqs = np.fft.rfftfreq(N, 1 / SR)
    shape = np.where((freqs > 500) & (freqs < 4500),
                     1.0 / np.sqrt(np.maximum(freqs, 500)), 0)
    t = np.arange(N) / SR
    bed = np.zeros((N, 2))
    for ch in range(2):
        spec = shape * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
        s = np.fft.irfft(spec, N)
        s /= np.max(np.abs(s))
        am = 1.0 + 0.35 * np.sin(2 * np.pi * (2 / L) * t
                                 + rng.uniform(0, 6.28))
        bed[:, ch] = s * am
    bed *= 0.05
    # Les claquements : Poisson circulaire, décroissances exponentielles.
    pops = np.zeros((N, 2))
    n_pops = int(pops_per_s * L)
    for _ in range(n_pops):
        tau = rng.uniform(0.003, 0.012)
        ln = int(6 * tau * SR)
        tt = np.arange(ln) / SR
        if rng.random() < 0.3:
            f = rng.uniform(2000, 5000)
            burst = np.sin(2 * np.pi * f * tt) * np.exp(-tt / (tau * 1.8))
        else:
            burst = rng.standard_normal(ln) * np.exp(-tt / tau)
            # bande aléatoire ~1,5-6 kHz : différence de deux moyennes
            k = max(2, int(SR / rng.uniform(1500, 6000)))
            burst = burst - np.convolve(burst, np.ones(k) / k, mode="same")
        amp = 10 ** (rng.uniform(-18, 0) / 20) * 0.9
        idx = (int(rng.uniform(0, L) * SR) + np.arange(ln)) % N
        pan = rng.uniform(0.2, 0.8)
        pops[idx, 0] += burst * amp * np.cos(pan * np.pi / 2)
        pops[idx, 1] += burst * amp * np.sin(pan * np.pi / 2)
    pops /= max(np.max(np.abs(pops)), 1e-9)
    # Le grondement sous la braise, très bas.
    shape_low = np.where(freqs < 120, 1.0 / np.maximum(freqs, 25) ** 1.4, 0)
    rum = np.zeros((N, 2))
    for ch in range(2):
        spec = shape_low * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
        s = np.fft.irfft(spec, N)
        rum[:, ch] = s / np.max(np.abs(s))
    mix = bed + pops * 0.55 + rum * 0.035
    write(path, mix, -8)


crackle("/tmp/braise-eparse.wav", 15)
crackle("/tmp/braise-dense.wav", 55)

# ---------------- le carillon féérique (one-shot) ------------------------
DUR = 2.7
N = int(SR * DUR)
t = np.arange(N) / SR
notes = [1318.51, 1479.98, 1661.22, 1975.53, 2217.46, 2637.02]  # E6→E7 penta
onsets = [0.0, 0.06, 0.115, 0.165, 0.21, 0.25]
car = np.zeros((N, 2))
for i, (f0, pos) in enumerate(zip(notes, onsets)):
    ln = N - int(pos * SR)
    tt = np.arange(ln) / SR
    tone = np.zeros(ln)
    for r, a, tau in ((1.0, 1.0, 0.6), (2.76, 0.35, 0.3),
                      (4.07, 0.18, 0.18), (5.40, 0.10, 0.12)):
        for det in (1.00231, 0.99770):
            tone += a * 0.5 * np.sin(2 * np.pi * f0 * r * det * tt) \
                * np.exp(-tt / tau)
    tone *= np.minimum(tt / 0.003, 1)
    amp = 1.0 if i < 5 else 1.26  # la dernière note porte
    idx = int(pos * SR) + np.arange(ln)
    pan = 0.5 + (i - 2.5) * 0.06
    car[idx, 0] += tone * amp * np.cos(pan * np.pi / 2)
    car[idx, 1] += tone * amp * np.sin(pan * np.pi / 2)
# La poussière de fée : grains courts qui GLISSENT vers l'aigu.
for _ in range(90):
    ln = int(rng.uniform(0.03, 0.08) * SR)
    tt = np.arange(ln) / SR
    f0 = rng.uniform(2000, 6000)
    octaves = rng.uniform(0.5, 1.5)
    phase = 2 * np.pi * f0 * (2 ** (octaves * tt / tt[-1]) - 1) \
        / (np.log(2) * octaves / tt[-1])
    g = np.sin(phase) * np.hanning(ln)
    pos = rng.uniform(0, 1.2) ** 1.5  # densité qui culmine tôt
    idx = int(pos * SR) + np.arange(ln)
    idx = idx[idx < N]
    pan = rng.uniform(0.1, 0.9)
    car[idx, 0] += g[: len(idx)] * 0.07 * np.cos(pan * np.pi / 2)
    car[idx, 1] += g[: len(idx)] * 0.07 * np.sin(pan * np.pi / 2)
# Réverbe (convolution pleine, pas circulaire : one-shot, la queue meurt).
rt60 = 1.6
ir_len = int(1.4 * rt60 * SR)
out = np.zeros((N + ir_len, 2))
for ch in range(2):
    ir = rng.standard_normal(ir_len) * np.exp(-6.91 * np.arange(ir_len) / SR / rt60)
    ir = np.convolve(ir, np.ones(5) / 5, mode="same")
    wet = np.convolve(car[:, ch], ir)
    wet = np.pad(wet, (0, max(0, N + ir_len - len(wet))))[: N + ir_len]
    wet /= np.max(np.abs(wet)) + 1e-9
    dry = np.concatenate([car[:, ch], np.zeros(ir_len)])
    out[:, ch] = dry * 0.65 + wet * 0.35
write("/tmp/feerie-carillon.wav", out, -6)

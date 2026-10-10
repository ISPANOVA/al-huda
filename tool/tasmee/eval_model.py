"""Runs the Tasmee model on real recitations (everyayah.com) the way the app
does (16 kHz, 480 ms chunks, pauses end an utterance) and writes what it
heard, step by step, for the Dart tests (test/tasmee_model_test.dart).

Usage: python3 eval_model.py <model dir> <cache dir> <out.json>
"""
import json
import os
import subprocess
import sys
import time

import numpy as np
import sherpa_onnx

MODEL_DIR, CACHE, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
RATE = 16000
CHUNK = RATE * 480 // 1000

# (reciter folder on everyayah.com, surah, first ayah, last ayah)
SETS = [
    ("Husary_128kbps", 2, 1, 5),
    ("Husary_128kbps", 36, 1, 8),
    ("Minshawy_Murattal_128kbps", 18, 1, 5),
    ("Minshawy_Murattal_128kbps", 55, 1, 12),
    ("Alafasy_128kbps", 1, 1, 7),
    ("Alafasy_128kbps", 67, 1, 6),
    ("Abdul_Basit_Murattal_192kbps", 19, 1, 6),
    ("Ghamadi_40kbps", 12, 1, 6),
    ("Hudhaify_128kbps", 3, 190, 194),
    ("Muhammad_Ayyoub_128kbps", 24, 35, 36),
    ("Ayman_Sowaid_64kbps", 78, 1, 12),
    ("Abdullah_Basfar_192kbps", 2, 255, 257),
    ("Saood_ash-Shuraym_128kbps", 89, 1, 14),
    ("Maher_AlMuaiqly_64kbps", 112, 1, 4),
]


def audio(reciter: str, surah: int, ayah: int) -> np.ndarray:
    os.makedirs(CACHE, exist_ok=True)
    name = f"{surah:03d}{ayah:03d}"
    mp3 = f"{CACHE}/{reciter}_{name}.mp3"
    if not os.path.exists(mp3):
        url = f"https://everyayah.com/data/{reciter}/{name}.mp3"
        subprocess.run(["curl", "-sSfL", "--retry", "3", "-o", mp3, url], check=True)
    raw = subprocess.run(
        ["ffmpeg", "-v", "quiet", "-i", mp3, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def phone(x: np.ndarray, seed: int) -> np.ndarray:
    """A phone in a room: narrow band (8 kHz), quieter, some noise."""
    tmp_in = f"{CACHE}/_in.raw"
    (x * 32767).astype(np.int16).tofile(tmp_in)
    raw = subprocess.run(
        ["ffmpeg", "-v", "quiet", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", tmp_in,
         "-af", "aresample=8000,aresample=16000,highpass=f=120,volume=0.5", "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    y = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    rng = np.random.default_rng(seed)
    power = float(np.mean(y ** 2)) + 1e-9
    noise = rng.normal(0, np.sqrt(power / (10 ** (22 / 10))), size=y.shape).astype(np.float32)
    return y + noise


def recognizer():
    return sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(
        tokens=f"{MODEL_DIR}/tokens.txt",
        model=f"{MODEL_DIR}/model.int8.onnx",
        num_threads=2,
        sample_rate=RATE,
        feature_dim=80,
        enable_endpoint_detection=False,
        decoding_method="greedy_search",
    )


class PauseDetector:
    """Same rules as lib/features/tasmee/phonetic/pause_detector.dart."""
    FRAME = 480
    PAUSE_MS = 1100

    def __init__(self):
        self.noise = 0.003
        self.silent = 0
        self.speech = False

    def feed(self, x: np.ndarray) -> bool:
        paused = False
        for o in range(0, len(x) - self.FRAME + 1, self.FRAME):
            rms = float(np.sqrt(np.mean(x[o:o + self.FRAME].astype(np.float64) ** 2)))
            if rms < self.noise:
                self.noise = max(0.0003, 0.9 * rms + 0.1 * self.noise)
            elif rms < self.noise * 2:
                self.noise = 0.99 * self.noise + 0.01 * rms
            if rms > max(0.0015, self.noise * 3):
                self.speech = True
                self.silent = 0
            elif self.speech:
                self.silent += 1
                if self.silent * 30 >= self.PAUSE_MS:
                    self.speech = False
                    self.silent = 0
                    paused = True
        return paused


def run(rec, samples: np.ndarray):
    """Events as the app receives them: (text, is_final)."""
    events = []
    pauses = PauseDetector()

    def new_stream():
        # Primed with half a second of silence (the model's first chunk), so
        # the first sound said after a pause isn't lost.
        st = rec.create_stream()
        st.accept_waveform(RATE, np.zeros(CHUNK, dtype=np.float32))
        while rec.is_ready(st):
            rec.decode_stream(st)
        return st

    stream = new_stream()
    last = ""
    for o in range(0, len(samples), CHUNK):
        chunk = samples[o:o + CHUNK]
        stream.accept_waveform(RATE, chunk)
        while rec.is_ready(stream):
            rec.decode_stream(stream)
        text = rec.get_result(stream)
        if pauses.feed(chunk):
            # The last frames are decoded only when the stream is finished:
            # finish it and start a new one (as the app does).
            stream.input_finished()
            while rec.is_ready(stream):
                rec.decode_stream(stream)
            text = rec.get_result(stream)
            if text:
                events.append([text, True])
            stream = new_stream()
            last = ""
        elif text != last:
            last = text
            events.append([text, False])
    stream.accept_waveform(RATE, np.zeros(RATE // 2, dtype=np.float32))
    stream.input_finished()
    while rec.is_ready(stream):
        rec.decode_stream(stream)
    text = rec.get_result(stream)
    if text:
        events.append([text, True])
    return events


def main() -> None:
    rec = recognizer()
    out = []
    total_audio = total_time = 0.0
    for n, (reciter, surah, a1, a2) in enumerate(SETS):
        try:
            parts = [audio(reciter, surah, a) for a in range(a1, a2 + 1)]
        except subprocess.CalledProcessError as e:
            print("skip", reciter, surah, e)
            continue
        for variant in ("clean", "phone"):
            for gap in (0.3, 1.6):
                pieces = []
                for p in parts:
                    pieces.append(p)
                    pieces.append(np.zeros(int(RATE * gap), dtype=np.float32))
                x = np.concatenate(pieces)
                if variant == "phone":
                    x = phone(x, n)
                t0 = time.time()
                events = run(rec, x)
                dt = time.time() - t0
                total_audio += len(x) / RATE
                total_time += dt
                out.append({
                    "name": f"{reciter} {surah}:{a1}-{a2} {variant} gap{gap}",
                    "surah": surah, "from": a1, "to": a2,
                    "events": events,
                })
                print(f"{reciter} {surah}:{a1}-{a2} {variant} gap{gap}: {len(events)} events, "
                      f"rtf {dt / (len(x) / RATE):.3f}", flush=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(f"real-time factor overall: {total_time / max(total_audio, 1):.3f} (CI CPU, 2 threads)")


main()

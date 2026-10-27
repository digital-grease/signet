"""Synthetic speakers for the listening pipeline (plan Task 2.3).

Apache-2.0 models only, via sherpa-onnx:
- Kokoro-82M v1.1 multi-lang: speakers 3-102 are Chinese (0-2 are English).
- VITS AISHELL-3 (icefall): 174 speakers recorded with mixed native accents.
"""

import subprocess
from pathlib import Path

import numpy as np
import sherpa_onnx

MODELS = Path(__file__).resolve().parent.parent / ".cache" / "models"
KOKORO_ZH = range(3, 103)


def kokoro(threads: int = 2):
    m = MODELS / "kokoro-multi-lang-v1_1"
    cfg = sherpa_onnx.OfflineTtsKokoroModelConfig(
        model=str(m / "model.onnx"), voices=str(m / "voices.bin"), tokens=str(m / "tokens.txt"),
        data_dir=str(m / "espeak-ng-data"), dict_dir=str(m / "dict"),
        lexicon=f"{m / 'lexicon-us-en.txt'},{m / 'lexicon-zh.txt'}")
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(kokoro=cfg, num_threads=threads)))


def aishell3(threads: int = 2):
    m = MODELS / "vits-icefall-zh-aishell3"
    cfg = sherpa_onnx.OfflineTtsVitsModelConfig(
        model=str(m / "model.onnx"), lexicon=str(m / "lexicon.txt"), tokens=str(m / "tokens.txt"))
    fsts = ",".join(str(m / f) for f in ("phone.fst", "date.fst", "number.fst", "new_heteronym.fst"))
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(vits=cfg, num_threads=threads),
        rule_fsts=fsts, rule_fars=str(m / "rule.far")))


def to_16k(samples, rate: int) -> np.ndarray:
    a = np.asarray(samples, dtype=np.float32)
    if rate == 16000:
        return a
    out = subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(rate), "-ac", "1",
                          "-i", "pipe:0", "-ar", "16000", "-f", "f32le", "pipe:1"],
                         input=a.tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).copy()


def say(tts, text: str, sid: int) -> np.ndarray:
    g = tts.generate(text, sid=sid, speed=1.0)
    return to_16k(g.samples, g.sample_rate)

"""Phone-channel simulation with ffmpeg (plan Task 2.3).

Each condition takes 16 kHz mono float32 audio and returns 16 kHz mono
float32 audio as a recognizer would receive it after the call. ffmpeg's
AMR-NB encoder is libopencore_amrnb; decoding with the same library keeps
the length.
"""

import subprocess

import numpy as np

RATE = 16000

# name -> (bitrate or codec, SNR of added noise in dB or None)
CONDITIONS = {
    "wideband": None,               # reference: no phone channel
    "amr12k2": ("amr", 12200, None),
    "amr4k75": ("amr", 4750, None),  # worst AMR-NB mode
    "amr7k4-snr15": ("amr", 7400, 15),
    "g711-snr10": ("mulaw", None, 10),
}


def _ffmpeg(audio: np.ndarray, rate_in: int, args_out: list, rate_out: int, fmt_out: str,
            decode_args=()) -> bytes:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(rate_in),
           "-ac", "1", "-i", "pipe:0", *args_out, "pipe:1"]
    return subprocess.run(cmd, input=audio.astype(np.float32).tobytes(), capture_output=True,
                          check=True).stdout


def _decode(data: bytes, fmt: str, codec_args=()) -> np.ndarray:
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", *codec_args, "-f", fmt, "-i", "pipe:0",
           "-ar", str(RATE), "-ac", "1", "-f", "f32le", "pipe:1"]
    out = subprocess.run(cmd, input=data, capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype=np.float32).copy()


def add_noise(audio: np.ndarray, snr_db: float, seed: int) -> np.ndarray:
    """White noise at an SNR measured over the whole clip."""
    rng = np.random.default_rng(seed)
    power = float(np.mean(audio ** 2)) or 1e-12
    noise = rng.standard_normal(len(audio)).astype(np.float32)
    noise *= np.sqrt(power / (10 ** (snr_db / 10)) / float(np.mean(noise ** 2)))
    return audio + noise


def apply(audio: np.ndarray, condition: str, seed: int = 0) -> np.ndarray:
    spec = CONDITIONS[condition]
    if spec is None:
        return audio
    kind, bitrate, snr = spec
    x = add_noise(audio, snr, seed) if snr is not None else audio
    # Telephone band first: 300-3400 Hz, 8 kHz.
    band = ["-af", "highpass=f=300,lowpass=f=3400", "-ar", "8000", "-ac", "1"]
    if kind == "amr":
        data = _ffmpeg(x, RATE, band + ["-c:a", "libopencore_amrnb", "-b:a", str(bitrate), "-f", "amr"],
                       8000, "amr")
        return _decode(data, "amr", ["-c:a", "libopencore_amrnb"])
    data = _ffmpeg(x, RATE, band + ["-c:a", "pcm_mulaw", "-f", "mulaw"], 8000, "mulaw")
    return _decode(data, "mulaw", ["-ar", "8000", "-ac", "1"])

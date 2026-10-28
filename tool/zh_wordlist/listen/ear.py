"""Forced-choice listening with a CTC recognizer (plan Task 2.3).

Given audio of one spoken word, score every candidate word by its CTC
log-likelihood under the recognizer and return a posterior over the
candidates: P(the listener picks j | audio of i). This matches the app,
where autocomplete restricts typing to list words.

Ear: sherpa-onnx zipformer CTC zh int8 (2025-07-03), byte-level BPE.
"""

import importlib.util
from pathlib import Path

import kaldi_native_fbank as knf
import numpy as np
import onnxruntime as ort
import sentencepiece as spm

CACHE = Path(__file__).resolve().parent.parent / ".cache"
MODEL = CACHE / "models" / "sherpa-onnx-zipformer-ctc-zh-int8-2025-07-03"
NEG = -1e30


def _byte_utils():
    spec = importlib.util.spec_from_file_location("icefall_byte_utils", CACHE / "icefall_byte_utils.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class ZipformerCtc:
    def __init__(self, threads: int = 1):
        so = ort.SessionOptions()
        so.intra_op_num_threads = threads
        so.inter_op_num_threads = 1
        so.log_severity_level = 3
        self.session = ort.InferenceSession(str(MODEL / "model.int8.onnx"), so)
        self.sp = spm.SentencePieceProcessor(model_file=str(MODEL / "bbpe.model"))
        self.bu = _byte_utils()
        self.tokens = [line.split()[0] for line in (MODEL / "tokens.txt").read_text(encoding="utf-8").splitlines()]

    def features(self, audio: np.ndarray, rate: int = 16000) -> np.ndarray:
        opts = knf.FbankOptions()
        opts.frame_opts.dither = 0
        opts.frame_opts.snip_edges = False
        opts.frame_opts.samp_freq = rate
        opts.mel_opts.num_bins = 80
        fb = knf.OnlineFbank(opts)
        fb.accept_waveform(rate, audio.tolist())
        fb.input_finished()
        return np.stack([fb.get_frame(i) for i in range(fb.num_frames_ready)]).astype(np.float32)

    def log_probs(self, audio: np.ndarray) -> np.ndarray:
        x = self.features(audio)[None]
        lp, n = self.session.run(None, {"x": x, "x_lens": np.array([x.shape[1]], dtype=np.int64)})
        return lp[0, : int(n[0])]

    def encode(self, text: str) -> list:
        # The model was trained on transcripts with a space between Chinese
        # characters (its greedy output reads "医 生 钥 匙"), so score the
        # same spelling.
        return self.sp.encode(self.bu.byte_encode(" ".join(text.replace(" ", ""))))

    def greedy(self, lp: np.ndarray) -> str:
        ids, prev = [], 0
        for i in lp.argmax(axis=1):
            if i != prev and i != 0:
                ids.append(int(i))
            prev = i
        return self.bu.smart_byte_decode(self.sp.decode(ids)) if ids else ""


class Candidates:
    """Token sequences of a fixed candidate set, padded for batched CTC."""

    def __init__(self, ear: ZipformerCtc, words: list):
        self.words = words
        seqs = [ear.encode(w) for w in words]
        lmax = max(len(s) for s in seqs)
        smax = 2 * lmax + 1
        self.ext = np.zeros((len(words), smax), dtype=np.int64)  # blank-interleaved labels
        self.length = np.array([2 * len(s) + 1 for s in seqs])
        self.skip = np.zeros((len(words), smax), dtype=bool)      # may jump from s-2
        for c, s in enumerate(seqs):
            for k, tok in enumerate(s):
                self.ext[c, 2 * k + 1] = tok
                if k > 0 and s[k - 1] != tok:
                    self.skip[c, 2 * k + 1] = True
        pos = np.arange(smax)[None, :]
        self.valid = pos < self.length[:, None]

    def loglik(self, lp: np.ndarray) -> np.ndarray:
        """CTC log-likelihood of every candidate given one clip's log-probs."""
        c, smax = self.ext.shape
        emit = lp[:, self.ext]                     # [T, C, S]
        emit = np.where(self.valid[None], emit, NEG)
        alpha = np.full((c, smax), NEG)
        alpha[:, 0] = emit[0, :, 0]
        alpha[:, 1] = emit[0, :, 1]
        for t in range(1, lp.shape[0]):
            a1 = np.concatenate([np.full((c, 1), NEG), alpha[:, :-1]], axis=1)
            a2 = np.concatenate([np.full((c, 2), NEG), alpha[:, :-2]], axis=1)
            a2 = np.where(self.skip, a2, NEG)
            alpha = np.logaddexp(np.logaddexp(alpha, a1), a2) + emit[t]
        rows = np.arange(c)
        return np.logaddexp(alpha[rows, self.length - 1], alpha[rows, self.length - 2])

    def posterior(self, lp: np.ndarray) -> np.ndarray:
        ll = self.loglik(lp)
        p = np.exp(ll - ll.max())
        return p / p.sum()

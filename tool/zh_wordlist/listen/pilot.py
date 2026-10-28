"""Listening pilot (plan Task 2.3): is the synthetic pipeline sharp enough to trust?

Usage: uv run --group listen listen/pilot.py [--words 50] [--pairs 40] [--voices 8]

Calibration: generate.py's `sound` rejections are pairs (j, i) where j was
dropped because it shares a sound key with a listed word i. For each such i,
the pipeline should give its partner j far more probability than an average
other word. If it does not, the voices are too clean to show accent-level
confusions, and the pipeline's "no confusion" results are not evidence.

Each trial: a 4-word code (target in a random slot, three random list words
around it) spoken by one voice, passed through one channel condition, then
forced choice for the target slot over the choice set (the top candidates
plus the calibration partners). Writes out/listen/pilot.tsv and prints a
summary per voice family and channel.
"""

import argparse
import csv
import random
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import channel  # noqa: E402
import voices  # noqa: E402
from ear import Candidates, ZipformerCtc  # noqa: E402

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "out" / "listen"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=2560)
    ap.add_argument("--words", type=int, default=50)
    ap.add_argument("--pairs", type=int, default=40)
    ap.add_argument("--voices", type=int, default=8, help="per voice family")
    ap.add_argument("--threads", type=int, default=8)
    args = ap.parse_args()
    rng = random.Random(1)

    rows = list(csv.DictReader((HERE / "out" / "candidates.tsv").open(encoding="utf-8"), delimiter="\t"))
    listed = [r["simplified"] for r in rows[: args.top]]
    listed_set = set(listed)
    pairs = []
    for r in csv.DictReader((HERE / "out" / "rejected.tsv").open(encoding="utf-8"), delimiter="\t"):
        if r["gate"] == "sound" and " ~ " in r["detail"]:
            partner = r["detail"].split(" ~ ")[1]
            if partner in listed_set:
                pairs.append((partner, r["word"]))
    rng.shuffle(pairs)
    pairs = pairs[: args.pairs]
    partner_of = {i: j for i, j in pairs}
    choice = listed + sorted({j for _, j in pairs} - listed_set)
    targets = rng.sample(listed, args.words) + [i for i, _ in pairs]

    ear = ZipformerCtc(threads=args.threads)
    families = {"kokoro": (voices.kokoro(args.threads), rng.sample(list(voices.KOKORO_ZH), args.voices)),
                "aishell3": (voices.aishell3(args.threads), rng.sample(range(174), args.voices))}
    OUT.mkdir(parents=True, exist_ok=True)
    out = (OUT / "pilot.tsv").open("w", encoding="utf-8", newline="")
    w = csv.writer(out, delimiter="\t", lineterminator="\n")
    w.writerow(["family", "sid", "channel", "target", "kind", "p_true", "p_partner", "top", "p_top", "greedy"])
    index = {word: n for n, word in enumerate(choice)}
    t0, n = time.time(), 0
    for fam, (tts, sids) in families.items():
        for sid in sids:
            for target in targets:
                others = rng.sample([x for x in listed if x != target], 3)
                slot = rng.randrange(4)
                code = others[:slot] + [target] + others[slot:]
                audio = voices.say(tts, "，".join(code), sid)
                cand = Candidates(ear, ["".join(code[:slot] + [c] + code[slot + 1:]) for c in choice])
                for cond in channel.CONDITIONS:
                    lp = ear.log_probs(channel.apply(audio, cond, seed=n))
                    p = cand.posterior(lp)
                    top = int(np.argmax(p))
                    partner = partner_of.get(target)
                    w.writerow([fam, sid, cond, target, "calib" if partner else "list",
                                f"{p[index[target]]:.4f}", f"{p[index[partner]]:.4f}" if partner else "",
                                choice[top], f"{p[top]:.4f}", ear.greedy(lp)])
                    n += 1
            print(f"{fam} sid {sid} done, {n} trials, {time.time() - t0:.0f}s", flush=True)
    out.close()
    summarize(OUT / "pilot.tsv", len(choice))
    return 0


def summarize(path: Path, n_choice: int) -> None:
    rows = list(csv.DictReader(path.open(encoding="utf-8"), delimiter="\t"))
    print(f"\nchoice set {n_choice}; chance per word {1 / n_choice:.5f}")
    print("family    channel        list: P(true) acc | calib: P(true) P(partner) acc partner-wins")
    for fam in sorted({r["family"] for r in rows}):
        for cond in channel.CONDITIONS:
            sel = [r for r in rows if r["family"] == fam and r["channel"] == cond]
            li = [r for r in sel if r["kind"] == "list"]
            ca = [r for r in sel if r["kind"] == "calib"]

            def mean(xs):
                return sum(xs) / len(xs) if xs else float("nan")

            print(f"{fam:9} {cond:14} {mean([float(r['p_true']) for r in li]):.3f} "
                  f"{mean([r['top'] == r['target'] for r in li]):.3f} | "
                  f"{mean([float(r['p_true']) for r in ca]):.3f} {mean([float(r['p_partner']) for r in ca]):.4f} "
                  f"{mean([r['top'] == r['target'] for r in ca]):.3f} "
                  f"{sum(1 for r in ca if float(r['p_partner']) > float(r['p_true']))}/{len(ca)}")


if __name__ == "__main__":
    sys.exit(main())

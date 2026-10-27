"""Full listening run (plan Task 2.3): which list words get heard as other list words?

Usage: uv run --group listen listen/run.py [--voices 10] [--workers 4] [--threads 2]
       uv run --group listen listen/run.py --analyze
       uv run --group listen listen/run.py --targets out/listen/recheck.txt --out run-recheck.tsv
       uv run --group listen listen/run.py --analyze --out run.tsv,run-recheck.tsv

A resumed run scores only targets missing from the results file, so words
already scored are not tested against words that joined the list later;
--targets with a fresh --out reruns chosen words against the current list.

Choice set: the current candidates that every reviewer has kept. Each word
is the target of one 4-word code per voice (three random choice-set words
around it, target in a random slot), spoken by a Kokoro Chinese voice,
passed through each channel in CHANNELS, and scored by forced choice over
the whole choice set. Kokoro only: the AISHELL-3 VITS voices scored about
50% on clean audio in the pilot, so their errors are mostly noise.

--analyze reads out/listen/run.tsv and writes out/listen/confusable.tsv:
pairs (target, heard) where the heard word won in at least MIN_VOICES
different voices and the two words sound close (see `close`), and a
suggested reject for each pair: a word in several pairs goes once in place
of its partners, otherwise the lower-ranked word goes. Pairs that are not
close (留言簿 heard as 油布, 松果 as 中学) are the recognizer's own biases
towards words common in its training data, not channel confusions; they
are listed in out/listen/biased.tsv for reference.
`uv run listen/run.py --analyze --apply` appends those rejects to
denylist.tsv with reviewer `pipeline` and reason `confusable`.
"""

import argparse
import collections
import csv
import multiprocessing as mp
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "out" / "listen"
CHANNELS = ("wideband", "amr4k75", "g711-snr10")
MIN_VOICES = 2

_w = {}


def _init(threads: int, choice: list):
    import voices
    from ear import ZipformerCtc

    _w["tts"] = voices.kokoro(threads)
    _w["ear"] = ZipformerCtc(threads=threads)
    _w["choice"] = choice
    _w["index"] = {w: i for i, w in enumerate(choice)}


def _trial(job):
    import numpy as np

    import channel
    import voices
    from ear import Candidates

    target, sid, others, slot, seed = job
    choice, ear = _w["choice"], _w["ear"]
    code = others[:slot] + [target] + others[slot:]
    audio = voices.say(_w["tts"], "，".join(code), sid)
    cand = Candidates(ear, ["".join(code[:slot] + [c] + code[slot + 1:]) for c in choice])
    rows = []
    for cond in CHANNELS:
        p = cand.posterior(ear.log_probs(channel.apply(audio, cond, seed=seed)))
        order = np.argsort(-p)[:3]
        rows.append([target, sid, cond, choice[order[0]], f"{p[order[0]]:.4f}",
                     f"{p[_w['index'][target]]:.4f}",
                     " ".join(f"{choice[i]}:{p[i]:.3f}" for i in order)])
    return rows


def close(a: str, b: str) -> bool:
    """Same syllable count, exactly one syllable differs, and that pair shares its initial or its final."""
    from pypinyin import Style, lazy_pinyin

    def parts(w):
        return list(zip(lazy_pinyin(w, style=Style.INITIALS, strict=True),
                        lazy_pinyin(w, style=Style.FINALS, strict=True)))

    pa, pb = parts(a), parts(b)
    if len(pa) != len(pb):
        return False
    diff = [(x, y) for x, y in zip(pa, pb) if x != y]
    return len(diff) == 1 and (diff[0][0][0] == diff[0][1][0] or diff[0][0][1] == diff[0][1][1])


def kept_candidates() -> list:
    by = collections.defaultdict(set)
    for r in csv.DictReader((HERE / "review" / "decisions.tsv").open(encoding="utf-8"), delimiter="\t"):
        by[r["word"]].add(r["decision"])
    kept = {w for w, d in by.items() if d == {"keep"}}
    rows = csv.DictReader((HERE / "out" / "candidates.tsv").open(encoding="utf-8"), delimiter="\t")
    return [r["simplified"] for r in rows if r["simplified"] in kept]


def run(args) -> int:
    import voices

    choice = kept_candidates()
    rng = random.Random(7)
    sids = rng.sample(list(voices.KOKORO_ZH), args.voices)
    jobs = []
    targets = choice[: args.limit] if args.limit else choice
    if args.targets:
        wanted = set(Path(args.targets).read_text(encoding="utf-8").split())
        targets = [t for t in targets if t in wanted]
    for n, (target, sid) in enumerate((t, s) for s in sids for t in targets):
        others = rng.sample([x for x in choice if x != target], 3)
        jobs.append((target, sid, others, rng.randrange(4), n))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / args.out
    done = set()
    if path.exists():
        done = {(r["target"], int(r["sid"])) for r in csv.DictReader(path.open(encoding="utf-8"), delimiter="\t")}
    else:
        path.write_text("target\tsid\tchannel\ttop\tp_top\tp_true\ttop3\n", encoding="utf-8")
    jobs = [j for j in jobs if (j[0], j[1]) not in done]
    print(f"choice set {len(choice)}, voices {len(sids)}, {len(jobs)} codes to run", flush=True)
    t0 = time.time()
    with mp.get_context("spawn").Pool(args.workers, _init, (args.threads, choice)) as pool, \
            path.open("a", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        for i, rows in enumerate(pool.imap_unordered(_trial, jobs, chunksize=4), 1):
            w.writerows(rows)
            if i % 200 == 0:
                f.flush()
                rate = i / (time.time() - t0)
                print(f"{i}/{len(jobs)} codes, {rate:.2f}/s, eta {(len(jobs) - i) / rate / 60:.0f} min", flush=True)
    return analyze(apply=False, name="run.tsv" if args.out == "run.tsv" else f"run.tsv,{args.out}")


def analyze(apply: bool, name: str = "run.tsv") -> int:
    rows = [r for n in name.split(",") for r in csv.DictReader((OUT / n).open(encoding="utf-8"), delimiter="\t")]
    rank = {w: i for i, w in enumerate(kept_candidates())}
    trials = collections.Counter((r["target"], r["channel"]) for r in rows)
    wins = collections.defaultdict(set)   # (target, heard) -> voices where heard won
    count = collections.Counter()
    for r in rows:
        if r["top"] != r["target"]:
            wins[(r["target"], r["top"])].add(r["sid"])
            count[(r["target"], r["top"])] += 1
    by_channel = collections.defaultdict(list)
    for r in rows:
        by_channel[r["channel"]].append(r["top"] == r["target"])
    for ch, ok in sorted(by_channel.items()):
        print(f"{ch:12} accuracy {sum(ok) / len(ok):.3f} over {len(ok)} trials")
    repeated = sorted(((t, h, len(v), count[(t, h)]) for (t, h), v in wins.items()
                       if len(v) >= MIN_VOICES and t in rank and h in rank), key=lambda x: (-x[2], -x[3]))
    flagged = [x for x in repeated if close(x[0], x[1])]
    with (OUT / "biased.tsv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["target", "heard", "voices", "trials"])
        w.writerows(x for x in repeated if not close(x[0], x[1]))
    with (OUT / "confusable.tsv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["target", "heard", "voices", "trials", "drop"])
        # Cover every pair with as few drops as possible: a word heard in
        # several pairs goes once instead of taking each partner with it.
        # Otherwise the lower-ranked word of the pair goes.
        drops, by_pair, left = {}, {}, list(flagged)
        while left:
            deg = collections.Counter(x for t, h, *_ in left for x in (t, h))
            drop = max(deg, key=lambda x: (deg[x], rank[x]))
            for t, h, *_ in left:
                if drop in (t, h):
                    by_pair[(t, h)] = drop
                    drops.setdefault(drop, (t, h))
            left = [x for x in left if drop not in x[:2]]
        for t, h, nv, nt in flagged:
            w.writerow([t, h, nv, nt, by_pair[(t, h)]])
    print(f"{len(flagged)} confusable pairs (close, heard as each other in >= {MIN_VOICES} voices; "
          f"{len(repeated) - len(flagged)} not close, see biased.tsv); "
          f"{len(drops)} words to drop; see {OUT / 'confusable.tsv'}")
    if apply:
        with (HERE / "denylist.tsv").open("a", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter="\t", lineterminator="\n")
            for drop, (t, h) in drops.items():
                w.writerow([drop, "pipeline", "confusable", f"{t} heard as {h}"])
        print(f"appended {len(drops)} rejects to denylist.tsv; rerun generate.py")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--voices", type=int, default=10)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--threads", type=int, default=2)
    ap.add_argument("--analyze", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--limit", type=int, default=0, help="only the first N targets (smoke test)")
    ap.add_argument("--targets", help="file of words: only these targets (rechecks)")
    ap.add_argument("--out", default="run.tsv", help="results file; --analyze takes a comma-separated list")
    args = ap.parse_args()
    if args.analyze:
        return analyze(args.apply, args.out)
    return run(args)


if __name__ == "__main__":
    sys.exit(main())

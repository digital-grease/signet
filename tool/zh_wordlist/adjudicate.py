"""Adjudication of one reviewer's rejections (owner decision 2026-10-25).

  uv run adjudicate.py build <reviewer> [--size S]
      Collect every lone reject in <reviewer>'s unmerged answer files (words
      no other reviewer has rejected in review/decisions.tsv) and write
      out/review/adjudicate/round-K/<adjudicator>/batch-NN.tsv for each
      adjudicator in ADJUDICATORS (K is the next round), with a few known-bad
      seed words posing as correct rejects.
      Give each batch, with review/ADJUDICATE.md and review/PROMPT.md, to the
      adjudicator, and save its answer next to it as batch-NN.answer.tsv.

  uv run adjudicate.py apply <reviewer> [--round K]
      Read the adjudicators' answers (latest round unless --round). A reject stands if ANY adjudicator
      upholds it; otherwise it becomes a keep. The reviewer's answer files are
      rewritten (originals kept as *.answer.raw.tsv) and every row is logged
      in review/adjudication.tsv (checked in). Then run review.py merge.

  uv run adjudicate.py build splits [--only FILE]
  uv run adjudicate.py apply splits
      The same for merged words where the two Opus reviewers split (one kept,
      the other rejected), every other reviewer kept, and no adjudication
      has seen yet: an overruled reject
      becomes a keep in review/decisions.tsv and leaves denylist.tsv. --only
      limits the batch to the words listed in FILE (for example those that
      would pass every other gate).

  uv run adjudicate.py build tiebreak
  uv run adjudicate.py apply tiebreak
      A third adjudicator (TIEBREAKER) judges every reject the two
      adjudicators split on (one upheld, one overruled) whose word no other
      reviewer or gate has rejected. Two upholds of three keep the reject;
      otherwise it becomes a keep as above. Logged in review/tiebreak.tsv.

Why: the third reviewer (Sonnet) rejected about half the words the two Opus
reviewers kept, mixing real catches (regional splits, slang, variant
characters) with overcautious calls. Applying every reject would leave about
1,100 words; applying none would throw the catches away. The two Opus
reviewers' split decisions get the same check (owner, 2026-10-26), so every
reviewer's lone reject is treated alike. The tie-break (owner, 2026-10-26)
settles the split adjudications by majority once the list fell short.
"""

import argparse
import csv
import random
import sys
from pathlib import Path

from review import COLS, DECISIONS, DENYLIST, OUT, SEEDS, read_tsv, seed_row

HERE = Path(__file__).resolve().parent
ADJ = OUT / "adjudicate"
LOG = HERE / "review" / "adjudication.tsv"
ADJUDICATORS = ("adj-a", "adj-b")
TIEBREAKER = "adj-c"
TIE_LOG = HERE / "review" / "tiebreak.tsv"
SPLIT_REVIEWERS = ("claude-a", "claude-b")
ADJ_COLS = COLS + ["reason", "note"]

# Reasons the seeds pose with; every seed rejection is correct, so an
# adjudicator must uphold them.
SEED_REASONS = {"骗子": "alarming", "谢谢": "conversational", "配合": "alarming", "完了": "conversational",
                "死亡": "alarming", "小偷": "alarming", "妈妈": "conversational", "没有": "conversational",
                "觉得": "abstract", "混蛋": "vulgar", "警察": "alarming", "转账": "alarming",
                "抢劫": "alarming", "毒品": "alarming", "尸体": "alarming", "欠债": "alarming",
                "癌症": "alarming", "监狱": "alarming", "政府": "political", "宗教": "political"}


def answers_of(reviewer: str) -> list:
    return sorted((OUT / reviewer).glob("round-*/batch-*.answer.tsv"))


def rounds() -> list:
    return sorted(int(p.name.split("-")[1]) for p in ADJ.glob("round-*")) if ADJ.exists() else []


def rejected_by_others(reviewer: str) -> set:
    """Words some other reviewer already rejected: a reject from `reviewer`
    there is not a lone reject, so it stands without adjudication."""
    return {r["word"] for r in read_tsv(DECISIONS) if r["reviewer"] != reviewer and r["decision"] == "reject"}


def splits() -> dict:
    """word -> (rejecting reviewer, reason, note) for merged Opus split decisions
    that every other reviewer kept."""
    by = {}
    for r in read_tsv(DECISIONS):
        by.setdefault(r["word"], {})[r["reviewer"]] = r
    out = {}
    for w, d in by.items():
        opus = [d.get(x, {}).get("decision") for x in SPLIT_REVIEWERS]
        others = [v["decision"] for k, v in d.items() if k not in SPLIT_REVIEWERS]
        if sorted(opus) == ["keep", "reject"] and all(o == "keep" for o in others):
            rej = next(x for x in SPLIT_REVIEWERS if d[x]["decision"] == "reject")
            out[w] = (rej, d[rej]["reason"], d[rej]["note"])
    return out


def tied() -> dict:
    """word -> adjudication log row for rejects the two adjudicators split on,
    not yet tie-broken, that no other reviewer rejected and whose only
    denylist row is that reviewer's. A freed word that some reviewer has not
    seen yet still goes to that reviewer."""
    done = {(r["reviewer"], r["word"]) for r in read_tsv(TIE_LOG)} if TIE_LOG.exists() else set()
    rejects = {}
    for r in read_tsv(DECISIONS):
        if r["decision"] == "reject":
            rejects.setdefault(r["word"], set()).add(r["reviewer"])
    deny = {}
    for line in DENYLIST.read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) > 1:
            deny.setdefault(parts[0], set()).add(parts[1])
    return {r["word"]: r for r in read_tsv(LOG)
            if r["outcome"] == "reject" and (r["reviewer"], r["word"]) not in done
            and sorted(r[f"{a}-verdict"] for a in ADJUDICATORS) == ["overrule", "uphold"]
            and deny.get(r["word"]) == {r["reviewer"]}
            and rejects.get(r["word"], set()) <= {r["reviewer"]}}


def write_batches(rejects: list, size: int, adjs: tuple = ADJUDICATORS) -> None:
    folder_round = ADJ / f"round-{(rounds() or [0])[-1] + 1}"
    for adj in adjs:
        folder = folder_round / adj
        folder.mkdir(parents=True)
        rng = random.Random(f"{adj}-{len(rejects)}")
        n = 0
        for n, start in enumerate(range(0, len(rejects), size), 1):
            rows = rejects[start:start + size]
            for seed in rng.sample(SEEDS, 3):
                rows.insert(rng.randrange(len(rows) + 1), dict(seed_row(seed), reason=SEED_REASONS[seed], note=""))
            with (folder / f"batch-{n:02d}.tsv").open("w", encoding="utf-8", newline="") as f:
                w = csv.DictWriter(f, ADJ_COLS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
                w.writeheader()
                w.writerows(rows)
        print(f"{adj}: {len(rejects)} rejects in {n} batches under {folder}")


def build(reviewer: str, size: int, only: str = "") -> None:
    cands = {r["simplified"]: r for r in read_tsv(HERE / "out" / "candidates.tsv")}
    rejects = []

    def add(word, reason, note):
        row = dict(cands.get(word) or seed_row(word))
        row.update(reason=reason, note=note)
        rejects.append(row)

    if reviewer == "tiebreak":
        for w, r in sorted(tied().items()):
            add(w, r["reason"], r["note"])
        write_batches(rejects, size, (TIEBREAKER,))
        return
    if reviewer == "splits":
        wanted = set(Path(only).read_text(encoding="utf-8").split()) if only else None
        done = {r["word"] for r in read_tsv(LOG)} if LOG.exists() else set()
        for w, (_, reason, note) in sorted(splits().items()):
            if w not in done and (wanted is None or w in wanted):
                add(w, reason, note)
    else:
        others = rejected_by_others(reviewer)
        for answer in answers_of(reviewer):
            for r in read_tsv(answer):
                if r["decision"] == "reject" and r["word"] not in SEEDS and r["word"] not in others:
                    add(r["word"], r["reason"], r["note"])
    write_batches(rejects, size)


def verdicts_of(folder: Path, adjs: tuple = ADJUDICATORS) -> tuple:
    verdicts, problems = {}, []
    for adj in adjs:
        hits = total = 0
        for batch in sorted((folder / adj).glob("batch-[0-9][0-9].tsv")):
            answer = batch.with_name(batch.name.replace(".tsv", ".answer.tsv"))
            if not answer.exists():
                problems.append(f"{answer}: missing")
                continue
            got = {r["word"].strip(): (r["verdict"].strip(), (r.get("note") or "").strip()) for r in read_tsv(answer)}
            for r in read_tsv(batch):
                v = got.get(r["simplified"])
                if not v or v[0] not in ("uphold", "overrule"):
                    problems.append(f"{answer}: bad or missing row for {r['simplified']}")
                elif r["simplified"] in SEEDS:
                    total += 1
                    hits += v[0] == "uphold"
                else:
                    verdicts.setdefault(r["simplified"], {})[adj] = v
        if total:
            print(f"{adj}: seed recall {hits}/{total}")
            if hits / total < 0.9:
                problems.append(f"{adj}: seed recall under 90%; do not trust its overrules")
    return verdicts, problems


def write_log(log: list) -> None:
    new = not LOG.exists()
    with LOG.open("a", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        if new:
            w.writerow(["word", "reviewer", "reason", "note"]
                       + [f"{a}-{c}" for a in ADJUDICATORS for c in ("verdict", "note")] + ["outcome"])
        w.writerows(log)


def log_row(word, reviewer, reason, note, v, stands) -> list:
    return [word, reviewer, reason, note] + [x for a in ADJUDICATORS for x in v[a]] + ["reject" if stands else "keep"]


def overrule_note(v) -> str:
    return "overruled: " + "; ".join(v[a][1] for a in ADJUDICATORS)


def apply_splits(verdicts: dict) -> int:
    split = splits()
    gone = [w for w in verdicts if w not in split]
    if gone:
        print(f"no longer split decisions: {gone[:10]}", file=sys.stderr)
        return 1
    log, freed = [], {}
    for w, v in sorted(verdicts.items()):
        rej, reason, note = split[w]
        stands = any(v[a][0] == "uphold" for a in ADJUDICATORS)
        log.append(log_row(w, rej, reason, note, v, stands))
        if not stands:
            freed[(rej, w)] = overrule_note(v)
    removed = free(freed)
    write_log(log)
    print(f"{len(log)} split rejects adjudicated: {len(log) - len(freed)} stand, {len(freed)} overruled "
          f"({removed} denylist rows removed); rerun generate.py")
    return 0


def free(freed: dict) -> int:
    """Turn merged rejects into keeps: {(reviewer, word): note}. Edits
    review/decisions.tsv, drops the matching denylist.tsv rows, and returns
    how many rows were dropped."""
    rows = read_tsv(DECISIONS)
    for r in rows:
        if (r["reviewer"], r["word"]) in freed:
            r.update(decision="keep", reason="", note=freed[(r["reviewer"], r["word"])])
    with DECISIONS.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, ["reviewer", "word", "decision", "reason", "note"], delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    lines = DENYLIST.read_text(encoding="utf-8").splitlines(keepends=True)

    def key(line):  # (reviewer, word) of a denylist row
        parts = line.rstrip("\n").split("\t") + [""]
        return parts[1], parts[0]

    kept = [ln for ln in lines if key(ln) not in freed]
    DENYLIST.write_text("".join(kept), encoding="utf-8")
    return len(lines) - len(kept)


def apply_tiebreak(verdicts: dict) -> int:
    tie = tied()
    gone = [w for w in verdicts if w not in tie]
    if gone:
        print(f"no longer tied: {gone[:10]}", file=sys.stderr)
        return 1
    log, freed = [], {}
    for w, v in sorted(verdicts.items()):
        r = tie[w]
        verdict, note = v[TIEBREAKER]
        log.append([w, r["reviewer"], r["reason"], r["note"]] + [r[f"{a}-verdict"] for a in ADJUDICATORS]
                   + [verdict, note, "reject" if verdict == "uphold" else "keep"])
        if verdict == "overrule":
            over = next(r[f"{a}-note"] for a in ADJUDICATORS if r[f"{a}-verdict"] == "overrule")
            freed[(r["reviewer"], w)] = f"overruled 2-1: {over}; {note}"
    removed = free(freed)
    new = not TIE_LOG.exists()
    with TIE_LOG.open("a", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        if new:
            w.writerow(["word", "reviewer", "reason", "note"] + [f"{a}-verdict" for a in ADJUDICATORS]
                       + [f"{TIEBREAKER}-verdict", f"{TIEBREAKER}-note", "outcome"])
        w.writerows(log)
    print(f"{len(log)} tied rejects broken: {len(log) - len(freed)} stand, {len(freed)} overruled "
          f"({removed} denylist rows removed); rerun generate.py")
    return 0


def apply(reviewer: str, rnd: int = 0) -> int:
    adjs = (TIEBREAKER,) if reviewer == "tiebreak" else ADJUDICATORS
    verdicts, problems = verdicts_of(ADJ / f"round-{rnd or rounds()[-1]}", adjs)
    if problems:
        print("\n".join(problems[:20]), file=sys.stderr)
        return 1
    if reviewer == "tiebreak":
        return apply_tiebreak(verdicts)
    if reviewer == "splits":
        return apply_splits(verdicts)
    log, overruled = [], 0
    others = rejected_by_others(reviewer)
    for answer in answers_of(reviewer):
        rows = read_tsv(answer)
        answer.rename(answer.with_name(answer.name.replace(".answer.tsv", ".answer.raw.tsv")))
        for r in rows:
            if r["decision"] != "reject" or r["word"] in SEEDS or r["word"] in others:
                continue
            v = verdicts[r["word"]]
            stands = any(v[a][0] == "uphold" for a in ADJUDICATORS)
            log.append(log_row(r["word"], reviewer, r["reason"], r["note"], v, stands))
            if not stands:
                overruled += 1
                r.update(decision="keep", reason="", note=overrule_note(v))
        with answer.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, ["word", "decision", "reason", "note"], delimiter="\t",
                               lineterminator="\n", extrasaction="ignore")
            w.writeheader()
            w.writerows(rows)
    write_log(log)
    print(f"{len(log)} rejects adjudicated: {len(log) - overruled} stand, {overruled} overruled; "
          f"now run review.py merge")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("reviewer", help="a reviewer's answer files, `splits` or `tiebreak`")
    b.add_argument("--size", type=int, default=350)
    b.add_argument("--only", default="", help="splits only: file of words to include")
    a = sub.add_parser("apply")
    a.add_argument("reviewer")
    a.add_argument("--round", type=int, default=0, help="adjudication round to apply (default: latest)")
    args = ap.parse_args()
    if args.cmd == "build":
        build(args.reviewer, args.size, args.only)
        return 0
    return apply(args.reviewer, args.round)


if __name__ == "__main__":
    sys.exit(main())

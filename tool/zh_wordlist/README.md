# zh_wordlist: build-time generator for the zh-1 word list

Signet's Chinese words are a curated list of 2048 Mandarin words of two or three characters (three-character words are nouns), id `zh-1`, rendered in simplified or Taiwan traditional characters. This folder builds the candidates for that list and records every review decision. Nothing here ships in the app: once frozen (plan Task 2.5), the list is checked in as Dart with a checksum, and that file is the trust anchor.

Design and rationale: `.devloop/spikes/chinese-words.md` (Revision 3: no native-speaker reviewers, so free data, an automated listening pipeline and an LLM reviewer panel stand in for them).

## Run

Needs [uv](https://docs.astral.sh/uv/) and `bsdtar` (libarchive, for one RAR archive). uv installs the pinned Python 3.12 and dependencies from `uv.lock`.

```
uv run fetch.py                     # download pinned sources into .cache/, check sha256
uv run python -m unittest test_sound
uv run generate.py                  # writes out/candidates.tsv, out/rejected.tsv, out/summary.txt
```

`generate.py` exits non-zero if fewer than 2048 words are eligible.

## What generate.py does

1. **Pool:** HSK 3.0 levels 1-9 two-character words and three-character nouns, plus nouns outside HSK that are MOE dictionary headwords (簡編本 first, then the larger 修訂本) and occur in SUBTLEX-CH.
2. **Gates**, each with a reason code in `out/rejected.tsv`:
   - `pos`: every HSK tag must be a content tag (nouns, verbs, adjectives, time, place, direction); words outside HSK must be nouns.
   - `deny-char`, `discourse`: a short deny-list of alarming characters and of conversation fillers and vocatives.
   - `denylist`: `denylist.tsv`, filled by reviewers.
   - `script-roundtrip`, `regional-vocab`: the Taiwan form must convert back, and OpenCC's Taiwan phrasing (`s2twp`) must not use a different word (信息 → 資訊).
   - `not-in-moe`, `moe-several-readings`, `reading-differs`, `hsk-several-readings`: the word must be in the MOE dictionary with exactly one reading, equal to the Mainland reading, so one pinyin serves both and Taiwan readers are never shown a reading they would not say.
   - `zhuyin-source`: the shipped Zhuyin comes from libchewing or McBopomofo, only when that table has the MOE reading and no other. A word in neither phrase table takes each character's libchewing reading instead (`chewing-chars`), when every character lists the MOE syllable.
   - `sound`: the word must not share a sound key with any higher-ranked word (`sound.py`: tones dropped, accent mergers, onset confusions in noise, every reading of every accepted written form, every two- or three-syllable split of its Latin spelling).
   - `prefix`: no two-character word may be spelt exactly like the first two syllables of a three-character word (电视 / 电视机).
   - `near-duplicate`: no three-character word may be a two-character word plus one character (电扇 / 电风扇).
3. **Ranking:** words every reviewer has kept first (so a new word never takes their sound), then nouns, then adjectives and places, then verbs and time words; within a tier, familiarity (SUBTLEX-CH contextual diversity) minus abstractness (Xu & Li 2020). The greedy sound selection gives each sound to the higher-ranked word, so the ranking decides every clash.
4. **Flags** for reviewers: `flags.tsv` (scam, verification and alarm words, hand-written) and the LDNOOBW Chinese list. A flag is evidence for reviewers, never an automatic reject.

## Review loop

```
uv run review.py batches <reviewer>   # out/review/<reviewer>/batch-NN.tsv
# give each batch plus review/PROMPT.md to the reviewer; save its answer as batch-NN.answer.tsv
uv run review.py merge                # review/decisions.tsv, rejects appended to denylist.tsv
uv run generate.py                    # rejected words free their sounds; repeat
```

Reviewers are listed in `review.py` (`REVIEWERS`): two Opus reviewers with Mainland and Taiwan lenses and a Sonnet reviewer. A non-Claude model run by the owner (`owner-model`, in `OPTIONAL`) is deferred; its batches are kept and can still be merged. Any reject wins, and a word is final only when every reviewer has kept it. Each batch hides three known-bad seed words; `merge` refuses a reviewer whose seed recall is under 90%.

`review/PROMPT.md` is self-contained, so it can be pasted into any chat model together with one batch file. Each round goes in its own folder (`out/review/<reviewer>/round-K/`), and merged answers are renamed `*.merged.tsv`.

### Adjudication

A lone reject (one reviewer rejects a word the others kept) goes to two adjudicators (`adj-a` Mainland lens, `adj-b` Taiwan lens) instead of standing automatically. They see the word, the reason and the note, and uphold the reject if the harm is real and specific, or overrule it if it is vague or untrue (`review/ADJUDICATE.md`). A reject stands if either adjudicator upholds it. When the two split (one upholds, one overrules) on a word no other reviewer rejected, a third adjudicator (`adj-c`, both lenses) breaks the tie, and the reject stands only on two upholds of three (owner, 2026-10-26, when the list fell short; first for Sonnet's rejects, then for the Opus reviewers' alike). A freed word some reviewer has not seen yet still goes to that reviewer. Seed words posing as correct rejects check each adjudicator. Rejects of words another reviewer also rejected are not lone rejects and stand without adjudication.

```
uv run adjudicate.py build sonnet         # Sonnet's unmerged rejects
uv run adjudicate.py apply sonnet         # rewrites its answers (originals kept as *.answer.raw.tsv), then review.py merge
uv run adjudicate.py build splits [--only FILE]   # merged Opus split decisions
uv run adjudicate.py apply splits         # edits decisions.tsv and denylist.tsv, then generate.py
uv run adjudicate.py build tiebreak       # split adjudications, for adj-c
uv run adjudicate.py apply tiebreak       # edits decisions.tsv and denylist.tsv, then generate.py
```

Every adjudicated row is logged in `review/adjudication.tsv`, and every tie-break in `review/tiebreak.tsv`.

### Freeze

`uv run freeze.py` takes the 2048 highest-ranked words every reviewer kept, orders them by canonical key and writes `lib/core/crypto/zh_wordlist.dart`; `uv run freeze.py --check` fails if the file on disk differs. zh-1 was frozen on 2026-10-26 (SHA-256 `13c5f616df16fb69bbe4e2332f17cf071ccb85db6be2734b2a1f078696203dc0`, checked by `test/crypto/zh_wordlist_test.dart`). Once committed it never changes: rerunning the tool after any data change gives a different list, which would be `zh-2`.

### Reading table

`uv run reading_table.py` writes `lib/core/crypto/zh_reading_table.dart`: one toneless Mandarin reading per character (GB2312, Big5 and every zh-1 written form, from pypinyin), which the app uses for zh-1 input by characters that are not an exact written form of an entry. A character of an entry also gets the reading it has in that entry. The output is deterministic; rerun it and check `git status` shows no change.

### Synonym check

Two entries that name the same thing (冬季/冬天, 单车/脚踏车, 流水/水流) let a listener who writes from meaning type the wrong one. A checker reads the whole kept list and lists every pair it thinks interchangeable, marking borderline ones `near:`. Only clear pairs count: pinyin and Zhuyin typists type the sound they hear, so near-synonyms that sound different are low risk. Each clear pair then goes to the two adjudicators (seeded with known synonym pairs); the pair stands if either upholds it, and an adjudicator under 90% seed recall is replaced by a third (`adj-c`, both lenses) for the pairs it overruled. One word per standing pair goes to `denylist.tsv` (reviewer `synonym-check`), covering every pair with as few drops as possible. The first pass (2026-10-25, `review/synonym-pairs.tsv`) dropped 258 words; the second, over the near-final list (2026-10-26, `review/synonym2-pairs.tsv`, verdicts in `review/synonym2-verdicts.tsv`), found 62 clear pairs, of which 48 stood, for 47 drops. A third pass (`review/synonym3-pairs.tsv`, `review/synonym3-verdicts.tsv`) checked only pairs involving the 73 words added after that: 14 clear pairs, all standing, 13 drops. In that pass every adjudicator missed one seed, and every missed seed was itself arguable (老农/农夫, 泉水/清泉, 男人/男士, 宴会/酒席): the first pass's clear pairs were never adjudicated, so they make poor seeds. All 14 pairs were applied without using any overrule. Future synonym seeds should come from pairs both adjudicators upheld in the second pass. Rerun the check over any words added later: new words can pair with old ones.

## Listening pipeline (listen/)

Build-time check for words that a recognizer hears as other list words over a phone channel. Needs the `listen` dependency group and the sherpa-onnx models under `.cache/models/` (Kokoro multi-lang v1.1, VITS AISHELL-3, zipformer CTC zh int8; all Apache-2.0).

```
uv run --group listen listen/pilot.py        # calibration and channel check
uv run --group listen listen/run.py          # every kept word, 10 voices, 3 channels (hours)
uv run --group listen listen/run.py --analyze [--apply]
uv run --group listen listen/run.py --targets out/listen/recheck.txt --out run-recheck.tsv
uv run --group listen listen/run.py --analyze --out run.tsv,run-recheck.tsv [--apply]
```

Each word is spoken inside a 4-word code by a Kokoro Chinese voice, passed through a simulated phone channel (`channel.py`: AMR-NB, G.711, band-pass, noise), and scored by forced choice over every kept word (`ear.py`: CTC log-likelihood per candidate). `--analyze` lists pairs heard as each other in at least two voices that also sound close (one syllable differs, sharing its initial or final); `--apply` sends one word per pair to `denylist.tsv` (reviewer `pipeline`): a word heard in several pairs (天线 with 棉线 and 铜线) goes once instead of taking each partner with it, otherwise the lower-ranked word goes. Repeated pairs that do not sound close are the recognizer's pull towards words common in its training data and go to `out/listen/biased.tsv` for reference.

A resumed run scores only words missing from the results file, so after new words join the list, rerun with `--targets` for older words that could clash with them (write the word list to a file, one per line) and analyze both files together. Standard-Mandarin voices cannot show accent confusions; the accent mergers in `sound.py` cover those. The weaker noise onset pairs (p-t, d-g, m-n, k-t) are not hard rules in `sound.py`; this pipeline catches them (毯子/盘子, 裤子/兔子, 逆风/蜜蜂).

## Files

| File | Checked in | What |
|---|---|---|
| `sources.json` | yes | pinned URL, sha256, licence and use of every source |
| `SOURCES.md` | yes | licence notes and attribution |
| `fetch.py`, `data.py`, `sound.py`, `generate.py`, `review.py`, `adjudicate.py`, `freeze.py` | yes | the tool |
| `test_sound.py` | yes | merger checks |
| `denylist.tsv` | yes | every rejection: word, reviewer, reason code, note |
| `flags.tsv` | yes | hand-written reviewer flags |
| `review/PROMPT.md`, `review/ADJUDICATE.md` | yes | reviewer and adjudicator instructions |
| `review/decisions.tsv`, `review/adjudication.tsv`, `review/tiebreak.tsv` | yes | every reviewer's decisions, every adjudication and tie-break |
| `review/synonym-pairs.tsv`, `review/synonym2-pairs.tsv`, `review/synonym2-verdicts.tsv` | yes | synonym checks and their adjudication |
| `.cache/`, `out/` | no | downloaded sources and generated output |

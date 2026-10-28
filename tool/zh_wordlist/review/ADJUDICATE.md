# zh-1 word review: instructions for an adjudicator

You are checking another reviewer's rejections for a security app's word list. Read all of this, then `review/PROMPT.md` (the instructions that reviewer followed), before you start.

## Why this step exists

Every word in the list is read aloud over a phone call by a stressed, possibly elderly person, and typed by another. Several reviewers judge each word. For every word in your file, at least one reviewer kept it and exactly one rejected it. A lone rejection often catches a real problem the others missed (a word that means something else in Taiwan, a slang sense, a variant character), but reviewers also reject everyday words out of caution (one rejected 赤道, 故乡 and 墙壁). If every lone rejection stands, the list cannot be filled.

Your job: for each row, decide whether the stated rejection is **real**.

## Decide for each row

- `uphold`: the problem is real. You can say concretely how the word would mislead, upset, embarrass or trip up a 75-year-old in Beijing or Taipei: it means something different in one region, one region says or writes it differently, it has a slang or vulgar sense people actually know, a character is commonly misread or written in a variant form, it names a brand or person, it is about illness, death, crime, money trouble or other things in PROMPT.md's `alarming` list, it is political or religious, or most adults would not know it. Uphold also when the reviewer's reason is wrong but a different real reason from PROMPT.md applies (say which).
- `overrule`: the concern is vague, far-fetched or untrue. Examples: an ordinary concrete thing called abstract; a word every adult knows called rare; a harmless word called alarming because of a distant association (大风, 冰雹); a sound-alike with a word nobody would think of in context; a body part or surface that is not one the video check uses.

The video check asks the caller to do one of exactly these: look up at the ceiling, look down at the floor, look over the left or right shoulder, touch the tip of the nose, touch the forehead, touch the left or right ear. Words naming those targets (天花板, 地板, 地面, 鼻子, 额头, 耳朵, 肩膀) or close to them (face parts, the head, gestures and poses) are a real problem. Other body parts and other surfaces are not, unless another reason applies.

The data columns help: `cd` is the share of films whose subtitles use the word (familiarity: above about 1.0 is common), and `concreteness` runs from 1 (concrete) to 5 (abstract), blank if unrated.

The list cannot change once it ships, so do not wave a real problem through to save the count. But a rejection you cannot state concretely is not a reason to lose a good word.

Some rows are deliberately bad words with a correct rejection, to check the adjudication. Judge every row on its merits.

## Columns you get

`simplified`, `tw` (Taiwan form), `pinyin`, `zhuyin`, `concreteness`, `cd`, `flags`, then the reviewer's `reason` and `note`.

## What to return

A tab-separated table, one row per input row, same order, no extra text, with this header:

```
word	verdict	note
```

- `word`: the `simplified` value, unchanged.
- `verdict`: `uphold` or `overrule`.
- `note`: a few words in English saying why; required for every row.

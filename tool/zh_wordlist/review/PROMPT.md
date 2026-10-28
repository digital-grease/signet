# zh-1 word review: instructions for a reviewer

You are reviewing candidate words for a security app's word list. Read all of this before you start.

## What the words are for

Signet is a phone app that protects families from voice-cloning scams. When someone calls claiming to be your grandson in trouble, you ask for "his 4 words". Only his real phone can show the right 4 words. He reads them aloud and you type what you hear.

So every word in the list will be:
- **read aloud** over a phone call, by a stressed person, possibly elderly, in Mainland or Taiwan Mandarin with a regional accent;
- **heard and typed** by another possibly elderly person, with pinyin, Zhuyin, handwriting or voice input;
- **shown** in simplified characters (Mainland) or Taiwan traditional characters, with pinyin or Zhuyin underneath.

The list has 2048 words of two or three characters (three-character words are concrete nouns such as 冰淇淋). Once it ships it can never change, so a bad word stays forever. **When in doubt, reject.**

Sound-alike problems have already been filtered by a program, and so have reading differences between Mainland and Taiwan. Your job is the judgment a program cannot make.

## Reject a word if any of these apply (reason codes)

- `abstract`: hard to picture or pin down (希望, 问题, 情况). Concrete, everyday things are best: objects, animals, food, places, colours, body parts that are not intimate.
- `conversational`: it sounds like ordinary talk rather than a code word. Fillers, greetings, replies and common sentence pieces (现在, 应该, 已经, 谢谢, 没事, 好的). A listener could mistake it for chat.
- `alarming`: death, illness, injury, disaster, crime, violence, weapons, police or courts, prison, drugs, debt or money trouble. Hearing it in a tense call must not frighten anyone or sound like a threat. Also words that scammers use: bank, account, transfer, investigation, lawyer, hospital, accident, parcel, refund, prize.
- `verify`: words about codes and checking themselves (密码, 验证, 号码, 暗号). Confusing next to a verification code.
- `political`: politics, government, parties, nations in a political sense, ideology, protest, religion, the military.
- `vulgar`: crude, sexual, intimate body parts, insults, slang, anything embarrassing to say to a grandparent.
- `name`: a brand, person, place name or other proper noun, or a word mostly used as part of a name.
- `reading`: a typical speaker might hesitate over how to read it or which characters to write (rare characters, a common misreading, a character with several common readings).
- `regional`: common in only one of Mainland or Taiwan, or old-fashioned, or a word Taiwan says differently. Both a Beijing grandmother and a Taipei grandmother must know it instantly.
- `rare`: a typical adult would not know it, or would not use it in daily life.
- `confusable`: you think it sounds like, or would be typed as, another common word (say which in the note).
- `other`: anything else that makes it a poor code word (say why in the note). This includes body gestures and poses (raising a hand, waving, nodding, turning the head) and body parts the app's video check uses (nose, forehead, ears, shoulders, ceiling, floor): on video calls the app also asks the caller to perform a physical action, and such words could be mistaken for it.

Keep a word only if a 75-year-old in Beijing and a 75-year-old in Taipei would both read it correctly at a glance, recognise it at once when heard, and feel nothing unpleasant hearing it from a family member.

## Columns you get

`rank`, `simplified`, `tw` (Taiwan form), `pinyin`, `zhuyin`, `concreteness` (1 concrete to 5 abstract, blank if unrated), `cd` (share of films whose subtitles use it, a familiarity signal), `flags` (hints from word lists: scam, verify, alarm, money, vulgar; a flag is a hint, not a verdict).

Some rows are deliberately bad, to check the review. Judge every row on its merits.

## What to return

A tab-separated table, one row per input row, same order, no extra text, with this header:

```
word	decision	reason	note
```

- `word`: the `simplified` value, unchanged.
- `decision`: `keep` or `reject`.
- `reason`: one reason code from the list above if rejected, empty if kept.
- `note`: a few words, in English, required for `confusable` and `other`, optional otherwise.

Return every row, including the ones you keep.

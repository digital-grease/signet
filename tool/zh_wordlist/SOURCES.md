# Sources and licences

Exact URLs and sha256 hashes are in `sources.json`. "Build time" means the data is read by the generator to select or check words and is never copied into the app. Only the final word list ships: the words themselves, their simplified and Taiwan forms, Mainland pinyin (pypinyin) and Taiwan Zhuyin (libchewing or McBopomofo).

| Source | Licence | Used for | Ships? |
|---|---|---|---|
| HSK 3.0 vocabulary (GF0025-2021), via drkameleon/complete-hsk-vocabulary @ 7ac65bf | MIT (repository) | candidate pool, part of speech, level | the selected words only |
| SUBTLEX-CH word frequency and part-of-speech files (Cai & Brysbaert 2010, PLoS ONE 5(6) e10729) | no licence text; free for research, and the authors allowed redistribution for any purpose with credit (per the wordfreq README) | frequency, contextual diversity, part of speech of words outside HSK | no |
| MOE 國語辭典簡編本, version 2014_20260929 (中華民國教育部) | CC BY-ND 3.0 TW plus the MOE usage note, which forbids changing an entry's reading or converting it to simplified characters | Taiwan-common gate; Taiwan reading oracle | **no, never**: F-Droid treats ND data as non-free, and the usage note forbids the changes shipping would need |
| libchewing-data `dict/chewing/tsi.csv` @ 703accab (Copyright (c) 2025 libchewing Core Team) | LGPL-2.1-or-later | Zhuyin, only where it equals the MOE reading | yes (Zhuyin strings); LGPL-2.1-or-later is compatible with AGPL-3.0 via GPL |
| McBopomofo `BPMFMappings.txt` and `phrase.occ` @ ccd2cd78 (Copyright 2011-2026 Mengjuei Hsieh et al.) | MIT | Zhuyin fallback; Taiwan frequency evidence | Zhuyin strings, where used |
| pypinyin 0.53.0 | MIT | Mainland readings, heteronyms | yes (pinyin strings) |
| OpenCC 1.4.2 (`s2t`, `s2tw`, `s2hk`, `s2twp`, `tw2s`) | Apache-2.0 | traditional forms; regional vocabulary flags | yes (traditional forms) |
| Xu & Li 2020, concreteness ratings of 9,877 two-character words (PLoS ONE 15(6) e0232133, supporting file S1) | CC BY 4.0 | ranking | no |
| LDNOOBW `zh` list @ 921a2965 | CC BY 4.0 | flags vulgar words for reviewers | no |
| Yu & Do 2023, Mandarin onset confusions in noise (OSF raw data) | see the OSF project | the noise confusion pairs in `sound.py` (the pairs, not the data) | no |

Attribution for the app's licence screen once the list ships: HSK 3.0 syllabus; pypinyin (MIT); OpenCC (Apache-2.0); libchewing data (LGPL-2.1-or-later) and McBopomofo (MIT) for Zhuyin. The MOE dictionary is used only to check readings and is not a source of anything shipped.

Not used, on purpose: 兩岸常用詞典 / moedict-data-csld (CC BY-NC-ND, granted to one project), the Sinica word list (paid, academic only), TBCL (all rights reserved), TOCFL 8000 (withdrawn), BCC (no licence), KeSpeech, MAGICDATA and Primewords (non-commercial or no adaptations).

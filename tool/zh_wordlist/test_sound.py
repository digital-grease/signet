"""Checks for sound.py. Run: uv run python -m unittest test_sound"""

import unittest

from sound import alt_segment_keys, classes, detone, inventory, keyset, prefixes, spelt


def clash(a: str, b: str) -> bool:
    return bool(classes(a) & classes(b))


class Mergers(unittest.TestCase):
    def test_accent_mergers(self):
        for a, b in [("zhang", "zang"), ("chi", "ci"), ("shi", "si"), ("nan", "lan"),
                     ("ren", "len"), ("ren", "yin"), ("ri", "yi"), ("xin", "xing"),
                     ("men", "meng"), ("fan", "fang"), ("ju", "ji"), ("lv", "li"),
                     ("yuan", "yan"), ("hui", "fei"), ("huan", "fan"), ("hu", "fu"),
                     ("hong", "feng"), ("guo", "ge"), ("huo", "he")]:
            self.assertTrue(clash(a, b), f"{a} ~ {b}")

    def test_noise_confusions(self):
        for a, b in [("hao", "pao"), ("ba", "fa")]:
            self.assertTrue(clash(a, b), f"{a} ~ {b}")

    def test_kept_apart(self):
        # Aspiration pairs are rarely confused (Yu & Do 2023).
        for a, b in [("ba", "pa"), ("da", "ta"), ("ga", "ka"), ("ju", "zu"), ("ma", "ba"),
                     ("an", "ai"), ("shi", "shu"),
                     # Not confused in the data, and never chained: b>f>s, x>s, f>h.
                     ("ba", "sa"), ("xi", "si"), ("sa", "fa"), ("fa", "ha"), ("ba", "ha"),
                     # Weaker noise pairs, left to the listening pipeline.
                     ("pa", "ta"), ("ta", "ka"), ("da", "ga"), ("ma", "na")]:
            self.assertFalse(clash(a, b), f"{a} !~ {b}")


class Readings(unittest.TestCase):
    def test_detone(self):
        self.assertEqual(detone("píng guǒ"), ("ping", "guo"))
        self.assertEqual(detone("lǜ sè"), ("lü", "se"))
        self.assertEqual(detone("dōng xi"), ("dong", "xi"))

    def test_segmentation_finds_qinai_qilai(self):
        syl = inventory("亲爱起来奶")
        self.assertTrue(alt_segment_keys(("qin", "ai"), syl) & keyset([("qi", "lai")]))

    def test_three_syllable_splits_and_parts(self):
        syl = inventory("西安先自行车")
        # xi|an|che also reads as xian|che.
        self.assertTrue(alt_segment_keys(("xi", "an", "che"), syl) & keyset([("xian", "che")]))
        self.assertEqual(prefixes({("zi", "xing", "che")}), {("zi", "xing")})
        self.assertTrue(prefixes({("dian", "shi", "ji")}) & spelt({("dian", "shi")}))
        self.assertFalse(prefixes({("san", "ming", "zhi")}) & spelt({("shang", "ren")}))


if __name__ == "__main__":
    unittest.main()

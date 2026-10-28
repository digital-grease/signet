"""Download every pinned source in sources.json into .cache/ and check its sha256.

Usage: uv run fetch.py

A file already in .cache/ with the right hash is kept. A wrong hash is an
error, never a warning: the generator's output is only reproducible from
these exact bytes.
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    CACHE.mkdir(exist_ok=True)
    failed = False
    for src in json.loads((HERE / "sources.json").read_text(encoding="utf-8")):
        path = CACHE / src["file"]
        if not path.exists() or sha256(path) != src["sha256"]:
            # The MOE site refuses IPv6.
            cmd = ["curl", "-sSfL", "-o", str(path), src["url"]]
            if src.get("ipv4"):
                cmd.insert(1, "-4")
            print(f"fetch {src['id']}: {src['url']}")
            subprocess.run(cmd, check=True)
        got = sha256(path)
        if got != src["sha256"]:
            print(f"FAIL {src['id']}: sha256 {got}, expected {src['sha256']}", file=sys.stderr)
            failed = True
        else:
            print(f"ok   {src['id']}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

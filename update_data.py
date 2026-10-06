#!/usr/bin/env python3
"""Refresh employer data and stamp the automatic refresh time into index.html."""

from __future__ import annotations

import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


BASE = Path(__file__).resolve().parent
INDEX = BASE / "index.html"
ENRICHMENT_SCRIPT = BASE / "enrich_offres.py"
BADGE_PATTERN = re.compile(
    r'(<span class="source-pill" id="last-update" data-updated-at=")[^"]*(">)'
    r"Dernier rafraîchissement automatique : .*?(</span>)",
    flags=re.DOTALL,
)


def main() -> int:
    if not INDEX.is_file() or not ENRICHMENT_SCRIPT.is_file():
        print("index.html ou enrich_offres.py est introuvable dans le dossier du projet.", file=sys.stderr)
        return 2

    # Keep the badge unchanged if data collection fails.
    subprocess.run([sys.executable, str(ENRICHMENT_SCRIPT)], cwd=BASE, check=True)

    now = datetime.now(ZoneInfo("Europe/Paris"))
    readable = now.strftime("%d/%m/%Y à %H:%M")
    html = INDEX.read_text(encoding="utf-8")
    updated_html, replacements = BADGE_PATTERN.subn(
        rf'\g<1>{now.isoformat(timespec="minutes")}\g<2>'
        f"Dernier rafraîchissement automatique : {readable}"
        r"\g<3>",
        html,
        count=1,
    )
    if replacements != 1:
        print("Le badge last-update est absent ou son balisage a changé.", file=sys.stderr)
        return 3

    INDEX.write_text(updated_html, encoding="utf-8")
    print(f"Badge actualisé : Dernier rafraîchissement automatique : {readable}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

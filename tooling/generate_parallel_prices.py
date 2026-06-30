#!/usr/bin/env python3
"""Generate or update assets/catalog/parallel_prices.json.

Seed data can be extended from SportsCardsPro ungraded values. Stickers without
specific entries fall back to defaults_by_kind at runtime.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "catalog" / "parallel_prices.json"

DEFAULTS = {
    "blue": 12.0,
    "red": 45.0,
    "purple": 85.0,
    "green": 250.0,
    "black": 5000.0,
}

# Top chase stickers — extend from SportsCardsPro aggregates.
SPECIFIC = {
    "ARG17": {"blue": 21.24, "red": 104.25, "purple": 460.0, "green": 1200.0},
    "POR15": {"blue": 102.5, "red": 179.17, "purple": 275.0, "green": 800.0},
    "ESP15": {"blue": 21.24, "red": 112.0, "purple": 374.65, "green": 900.0},
    "BRA14": {"blue": 18.5, "red": 95.0, "purple": 220.0, "green": 650.0},
    "FRA14": {"blue": 20.0, "red": 98.0, "purple": 280.0, "green": 750.0},
    "ENG14": {"blue": 19.0, "red": 88.0, "purple": 240.0, "green": 600.0},
    "GER14": {"blue": 17.5, "red": 82.0, "purple": 210.0, "green": 550.0},
    "USA16": {"blue": 15.0, "red": 65.0, "purple": 180.0, "green": 450.0},
    "MEX15": {"blue": 14.0, "red": 55.0, "purple": 150.0, "green": 400.0},
    "NOR15": {"blue": 22.0, "red": 120.0, "purple": 350.0, "green": 465.0},
    "NED14": {"blue": 16.0, "red": 70.0, "purple": 190.0, "green": 500.0},
    "BEL14": {"blue": 15.5, "red": 68.0, "purple": 175.0, "green": 420.0},
    "CRO14": {"blue": 14.5, "red": 60.0, "purple": 160.0, "green": 380.0},
    "URU14": {"blue": 16.5, "red": 72.0, "purple": 200.0, "green": 520.0},
    "COL14": {"blue": 13.0, "red": 50.0, "purple": 130.0, "green": 350.0},
}


def main() -> None:
    payload = {
        "version": 1,
        "source": "SportsCardsPro eBay sold aggregates (ungraded)",
        "updated_at": date.today().isoformat(),
        "defaults_by_kind": DEFAULTS,
        "prices": SPECIFIC,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(SPECIFIC)} specific stickers)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate page template JSON files for all national teams."""

import json
from pathlib import Path

# Standard Panini team spread: 20 slots in 4 columns x 5 rows (normalized coords).
# Layout approximates a typical WC album team page (two-page spread flattened).
COLS = 4
ROWS = 5
MARGIN_X = 0.06
MARGIN_Y = 0.08
GAP_X = 0.02
GAP_Y = 0.02


def slot_rect(col: int, row: int) -> dict:
    usable_w = 1.0 - 2 * MARGIN_X - (COLS - 1) * GAP_X
    usable_h = 1.0 - 2 * MARGIN_Y - (ROWS - 1) * GAP_Y
    cw = usable_w / COLS
    ch = usable_h / ROWS
    return {
        "x": MARGIN_X + col * (cw + GAP_X),
        "y": MARGIN_Y + row * (ch + GAP_Y),
        "w": cw,
        "h": ch,
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    catalog_path = root / "assets" / "catalog" / "wc26_catalog.json"
    catalog = json.loads(catalog_path.read_text())
    out_dir = root / "assets" / "page_templates"
    out_dir.mkdir(parents=True, exist_ok=True)

    teams: dict[str, list] = {}
    for s in catalog["stickers"]:
        tc = s["team_code"]
        if tc in ("FWC", "CC"):
            continue
        teams.setdefault(tc, []).append(s)

    for team_code, stickers in teams.items():
        stickers.sort(key=lambda x: x["slot_number"])
        team_name = stickers[0]["team_name"]
        slots = []
        for i, st in enumerate(stickers):
            col, row = i % COLS, i // COLS
            rect = slot_rect(col, row)
            slots.append(
                {
                    "index": i,
                    "sticker_code": st["code"],
                    **rect,
                }
            )
        template = {
            "id": f"team_spread_{team_code.lower()}",
            "team_code": team_code,
            "team_name": team_name,
            "layout": "team_spread_4x5",
            "slots": slots,
        }
        path = out_dir / f"team_{team_code.lower()}.json"
        path.write_text(json.dumps(template, indent=2))
        print(f"Wrote {path.name}")

    # FWC intro spread (20 slots)
    fwc = [s for s in catalog["stickers"] if s["team_code"] == "FWC"]
    fwc.sort(key=lambda x: x["slot_number"])
    fwc_slots = []
    for i, st in enumerate(fwc):
        col, row = i % COLS, i // COLS
        fwc_slots.append({"index": i, "sticker_code": st["code"], **slot_rect(col, row)})
    (out_dir / "fwc_intro.json").write_text(
        json.dumps(
            {
                "id": "fwc_intro",
                "team_code": "FWC",
                "team_name": "FIFA World Cup",
                "layout": "fwc_4x5",
                "slots": fwc_slots,
            },
            indent=2,
        )
    )
    (out_dir / "index.json").write_text(
        json.dumps({"templates": [f"assets/page_templates/{p.name}" for p in sorted(out_dir.glob("team_*.json"))] + (["assets/page_templates/fwc_intro.json"] if (out_dir / "fwc_intro.json").exists() else [])}, indent=2)
    )
    print("Wrote index.json")


if __name__ == "__main__":
    main()

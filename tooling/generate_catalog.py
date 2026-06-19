#!/usr/bin/env python3
"""Parse master_list.md into wc26_catalog.json for the Flutter app."""

from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

MASTER_LIST_URL = (
    "https://raw.githubusercontent.com/wpercybrooks/"
    "Panini-WC26-album-tracker/main/master_list.md"
)

TEAM_LINE = re.compile(
    r"^([A-Z]{2,3})\s+(\d+)\s+\((Badge|Team Photo)\)|"
    r"^([A-Z]{2,3})\s+(\d+)\s+(.+?)(?:,|\.$)|"
    r"^([A-Z]{2,3})\s+(\d+)\s+\((Badge|Team Photo)\)",
    re.MULTILINE,
)

# Simpler: parse team paragraphs like "BRA 1 (Badge), BRA 2 Alisson, ..."
TEAM_PARAGRAPH = re.compile(
    r"^#### .+ \(([A-Z]{2,3})\)\s*\n(.+?)(?=\n#### |\n---|\n### Group|\Z)",
    re.MULTILINE | re.DOTALL,
)
STICKER_TOKEN = re.compile(
    r"([A-Z]{2,3})\s+(\d+)\s+(?:\((Badge|Team Photo)\)|(.+?))(?=,\s*[A-Z]{2,3}\s+\d+|\.$)",
)

GROUP_HEADER = re.compile(r"^### Group ([A-L])\s*$", re.MULTILINE)
TEAM_HEADER = re.compile(r"^#### (.+?) \(([A-Z]{2,3})\)\s*$", re.MULTILINE)

FWC_ROW = re.compile(r"^\|\s*(FWC\s+\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", re.MULTILINE)
CC_ROW = re.compile(r"^\|\s*(CC\s+\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|$", re.MULTILINE)


def category_for(slot: int, special: str | None) -> str:
    if special == "Badge":
        return "badge"
    if special == "Team Photo":
        return "team_photo"
    return "player"


def parse_team_line(text: str, group: str, team_name: str, team_code: str) -> list[dict]:
    stickers: list[dict] = []
    # Split on comma boundaries before team codes
    parts = re.split(r",\s*(?=[A-Z]{2,3}\s+\d+)", text.strip().rstrip("."))
    for part in parts:
        part = part.strip()
        m = re.match(r"^([A-Z]{2,3})\s+(\d+)\s+(?:\((Badge|Team Photo)\)|(.+))$", part)
        if not m:
            continue
        code_prefix, num_str, special, player = m.groups()
        if code_prefix != team_code:
            continue
        slot = int(num_str)
        code = f"{team_code}{slot}"
        cat = category_for(slot, special)
        name = None
        if special == "Badge":
            name = f"{team_name} Badge"
        elif special == "Team Photo":
            name = f"{team_name} Team Photo"
        else:
            name = (player or "").strip()
        stickers.append(
            {
                "code": code,
                "team_code": team_code,
                "team_name": team_name,
                "slot_number": slot,
                "player_name": name if cat == "player" else name,
                "category": cat,
                "group": f"Group {group}",
                "album_page": None,
                "slot_index_on_page": slot - 1 if slot <= 12 else slot - 2,
            }
        )
    return stickers


def parse_fwc_table(text: str) -> list[dict]:
    items = []
    for m in FWC_ROW.finditer(text):
        raw_code, name, detail = m.group(1), m.group(2).strip(), m.group(3).strip()
        code = raw_code.replace(" ", "")
        slot = int(code[3:])
        cat = "fwc"
        if "Museum" in detail or "Team Photo" in detail:
            cat = "fwc_museum"
        elif "Foil" in detail or "Logo" in detail or "emblem" in name.lower():
            cat = "fwc_foil"
        items.append(
            {
                "code": code,
                "team_code": "FWC",
                "team_name": "FIFA World Cup",
                "slot_number": slot,
                "player_name": name,
                "category": cat,
                "group": "FWC",
                "album_page": None,
                "slot_index_on_page": slot,
            }
        )
    return items


def parse_cc_table(text: str) -> list[dict]:
    items = []
    for m in CC_ROW.finditer(text):
        raw_code, player, team = m.group(1), m.group(2).strip(), m.group(3).strip()
        code = raw_code.replace(" ", "")
        slot = int(code[2:])
        items.append(
            {
                "code": code,
                "team_code": "CC",
                "team_name": team,
                "slot_number": slot,
                "player_name": player,
                "category": "coca_cola",
                "group": "Coca-Cola",
                "album_page": None,
                "slot_index_on_page": slot - 1,
            }
        )
    return items


def assign_album_pages(catalog: list[dict]) -> None:
    page = 1
    current_group = None
    for entry in catalog:
        g = entry["group"]
        if g != current_group and g.startswith("Group"):
            current_group = g
        if entry["team_code"] in ("FWC", "CC"):
            continue
        if entry["slot_number"] == 1:
            page += 1
        entry["album_page"] = page


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    md_path = root / "tooling" / "data" / "master_list.md"
    md_path.parent.mkdir(parents=True, exist_ok=True)
    if not md_path.exists():
        print(f"Downloading master list to {md_path}")
        md_path.write_text(urllib.request.urlopen(MASTER_LIST_URL).read().decode())
    text = md_path.read_text()

    catalog: list[dict] = []
    catalog.extend(parse_fwc_table(text))
    catalog.extend(parse_cc_table(text))

    current_group = "A"
    for line in text.splitlines():
        gm = GROUP_HEADER.match(line)
        if gm:
            current_group = gm.group(1)
            continue
        tm = TEAM_HEADER.match(line)
        if not tm:
            continue
        team_name, team_code = tm.group(1), tm.group(2)
        # Next line(s) until blank or next header
        idx = text.splitlines().index(line)
        body_lines = []
        for bl in text.splitlines()[idx + 1 :]:
            if bl.startswith("#### ") or bl.startswith("### ") or bl == "---":
                break
            if bl.strip():
                body_lines.append(bl.strip())
        if body_lines:
            catalog.extend(parse_team_line(" ".join(body_lines), current_group, team_name, team_code))

    assign_album_pages(catalog)

    # Dedupe by sticker code (keep first occurrence).
    seen: set[str] = set()
    unique: list[dict] = []
    for entry in catalog:
        code = entry["code"].upper()
        if code in seen:
            continue
        seen.add(code)
        unique.append(entry)
    catalog = unique

    out = {
        "version": "1.0.0",
        "edition": "global",
        "total_stickers": len(catalog),
        "stickers": catalog,
    }
    out_path = root / "assets" / "catalog" / "wc26_catalog.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False))
    print(f"Wrote {len(catalog)} stickers to {out_path}")


if __name__ == "__main__":
    main()

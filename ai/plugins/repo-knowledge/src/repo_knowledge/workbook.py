"""Read-only text extraction for .xlsx workbooks using only the standard library.

One line per non-empty row: ``[Sheet] row N | Header: value | ...``. Dates are
ISO, and struck-through text is kept as ``~~text~~`` because a strike often
means "received" or "withdrawn"; dropping it, or showing it as plain text,
would misstate the row. The workbook itself is never written.
"""
from __future__ import annotations

import io
import re
import zipfile
from datetime import date, timedelta
import xml.etree.ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
      "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"
DATE_FORMAT_IDS = set(range(14, 23)) | {45, 46, 47}


def _struck(rpr) -> bool:
    if rpr is None:
        return False
    strike = rpr.find("m:strike", NS)
    return strike is not None and strike.get("val", "1") not in ("0", "false")


def _shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    out = []
    for si in ET.parse(zf.open("xl/sharedStrings.xml")).getroot().findall("m:si", NS):
        runs = si.findall("m:r", NS)
        if not runs:
            out.append("".join(t.text or "" for t in si.iter(f"{{{NS['m']}}}t")))
            continue
        parts = []
        for run in runs:
            text = "".join(t.text or "" for t in run.findall("m:t", NS))
            parts.append(f"~~{text}~~" if text.strip() and _struck(run.find("m:rPr", NS)) else text)
        out.append("".join(parts))
    return out


def _styles(zf: zipfile.ZipFile) -> tuple[list[bool], list[bool]]:
    """Per cell-style index: (is a date format, font is struck through)."""
    if "xl/styles.xml" not in zf.namelist():
        return [], []
    root = ET.parse(zf.open("xl/styles.xml")).getroot()
    custom = {int(f.get("numFmtId")): f.get("formatCode", "")
              for f in root.findall("m:numFmts/m:numFmt", NS)}
    fonts = [_struck(font) for font in root.findall("m:fonts/m:font", NS)]
    is_date, is_struck = [], []
    for xf in root.findall("m:cellXfs/m:xf", NS):
        fmt = int(xf.get("numFmtId", "0"))
        code = re.sub(r'"[^"]*"|\[[^\]]*\]', "", custom.get(fmt, ""))
        is_date.append(fmt in DATE_FORMAT_IDS or bool(re.search(r"[dy]", code, re.I)))
        font = int(xf.get("fontId", "0"))
        is_struck.append(fonts[font] if font < len(fonts) else False)
    return is_date, is_struck


def _column(ref: str) -> int:
    letters = re.match(r"[A-Z]+", ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n


def _sheets(zf: zipfile.ZipFile) -> list[tuple[str, str]]:
    book = ET.parse(zf.open("xl/workbook.xml")).getroot()
    rels = ET.parse(zf.open("xl/_rels/workbook.xml.rels")).getroot()
    targets = {r.get("Id"): r.get("Target") for r in rels.iter(f"{REL}Relationship")}
    out = []
    for sheet in book.findall("m:sheets/m:sheet", NS):
        target = targets[sheet.get(f"{{{NS['r']}}}id")].lstrip("/")
        out.append((sheet.get("name"), target if target.startswith("xl/") else f"xl/{target}"))
    return out


def extract_text(raw: bytes) -> str:
    zf = zipfile.ZipFile(io.BytesIO(raw))
    strings = _shared_strings(zf)
    is_date, is_struck = _styles(zf)
    lines = []
    for name, part in _sheets(zf):
        rows = []
        for row in ET.parse(zf.open(part)).getroot().iter(f"{{{NS['m']}}}row"):
            cells = {}
            for c in row.findall("m:c", NS):
                kind, style = c.get("t"), int(c.get("s", "0"))
                v = c.find("m:v", NS)
                if kind == "s" and v is not None:
                    text = strings[int(v.text)]
                elif kind == "inlineStr":
                    text = "".join(t.text or "" for t in c.iter(f"{{{NS['m']}}}t"))
                elif v is not None and v.text is not None:
                    text = v.text
                    if kind is None and style < len(is_date) and is_date[style]:
                        try:
                            text = (date(1899, 12, 30) + timedelta(days=float(text))).isoformat()
                        except (ValueError, OverflowError):
                            pass
                else:
                    continue
                text = " ".join(text.split())
                if not text:
                    continue
                if style < len(is_struck) and is_struck[style] and not text.startswith("~~"):
                    text = f"~~{text}~~"
                cells[_column(c.get("r"))] = text
            if cells:
                rows.append((int(row.get("r")), cells))
        # Header: the first row with three or more text cells and no digits-only values.
        header, header_row = {}, 0
        for number, cells in rows:
            if len(cells) >= 3 and not any(re.fullmatch(r"[\d.\-]+", v) for v in cells.values()):
                header = cells
                header_row = number
                break
        for number, cells in rows:
            if header and number == header_row:
                lines.append(f"[{name}] header row {number}: " + " | ".join(cells.values()))
                continue
            labels = header if number > header_row else {}
            parts = [f"{labels.get(col, f'col {col}')}: {val}" for col, val in sorted(cells.items())]
            lines.append(f"[{name}] row {number} | " + " | ".join(parts))
    return "\n".join(lines) + "\n"

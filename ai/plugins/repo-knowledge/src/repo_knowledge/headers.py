"""Parse explicit record metadata without inferring authority or freshness."""
from __future__ import annotations

import re
from datetime import date, datetime
from pathlib import PurePosixPath

# Plain, list ("- Key:") and bold ("**Key:**") header lines.
HEADER = re.compile(r"^(?:-\s+)?(?:\*\*)?([A-Za-z][A-Za-z -]*):(?:\*\*)?\s*(.*)$")
INLINE = re.compile(r"\(superseded\s+\d{4}-\d{2}-\d{2}:\s*[^)]+\)", re.I)


def normalize_status(raw: str, record_type: str) -> str:
    if record_type == "ticket_snapshot":
        return "unknown"  # A tracker's issue state is not a posting workflow state.
    upper = raw.upper()
    if re.match(r"POSTED\s+(?:IN PART|PARTIALLY)\b", upper):
        return "PARTIALLY POSTED"
    if re.match(r"HELD\b", upper):
        return "NOT POSTED"
    for status in ("PARTIALLY POSTED", "NOT POSTED", "POSTED", "DRAFT", "SENT", "RECEIVED"):
        if re.match(re.escape(status) + r"(?:\b|$)", upper):
            return status
    return "unknown"


def explicit_date(value: str) -> str:
    value = value.strip().rstrip(".")
    for fmt in ("%Y-%m-%d", "%d %B %Y", "%d %b %Y"):
        try:
            return datetime.strptime(value, fmt).date().isoformat()
        except ValueError:
            pass
    return "unknown"


def parse_headers(text: str, path: str, record_type: str) -> dict:
    headers: dict[str, str] = {}
    warnings = []
    legacy_superseded = False
    # Only the opening metadata block, never quoted examples in the body.
    for line in text.splitlines()[:40]:
        stripped = line.strip()
        if stripped.startswith(("##", "```", "~~~")):
            break
        if re.match(r"^SUPERSEDED\b", stripped, re.I):
            legacy_superseded = True
        match = HEADER.match(stripped)
        if match:
            key, value = match.groups()
            key = key.lower()
            if key in headers:
                warnings.append(f"Duplicate header: {key}; first value retained")
            else:
                headers[key] = value
    raw = headers.get("status", "")
    legacy_superseded |= bool(re.match(r"SUPERSEDED\b", raw, re.I))
    target = headers.get("superseded-by", "")
    scope = headers.get("superseded", "").lower()
    inline = [i for i, line in enumerate(text.splitlines(), 1) if INLINE.search(line)]
    if scope == "whole" or legacy_superseded:
        supersession = "whole"
        target = target or "unknown"
    elif scope == "partial" or inline:
        supersession = "partial"
    else:
        supersession = "none recorded"
        if target or scope:
            warnings.append("Supersession header lacks a recognized scope; read source")
    record_date = explicit_date(headers.get("recorded", headers.get("date", "")))
    if record_date == "unknown":
        # A date anywhere in the file name, e.g. update-for-review-2026-10-30-x.md.
        match = re.search(r"(?<!\d)(\d{4}-\d{2}-\d{2})(?!\d)", PurePosixPath(path).name)
        if match:
            try:
                record_date = date.fromisoformat(match[1]).isoformat()
            except ValueError:
                pass
    return {
        "workflow_status": normalize_status(raw, record_type),
        "status_detail": raw or "unknown",
        "record_date": record_date,
        "source_updated": headers.get("updated", "unknown"),
        "ticket_status": raw if record_type == "ticket_snapshot" else None,
        "supersession": supersession,
        "superseded_by": target or None,
        "superseded_lines": inline,
        "warnings": warnings,
    }

"""Read-only access to classic Outlook through COM. No MCP types here.

Nothing in this module sends, moves, deletes, flags or marks mail as read.
"""
from __future__ import annotations

import gc
import re
from collections.abc import Generator
from contextlib import contextmanager
from datetime import datetime, timedelta
from typing import Any

PR_SMTP_ADDRESS = "http://schemas.microsoft.com/mapi/proptag/0x39FE001E"
PR_SENDER_SMTP_ADDRESS = "http://schemas.microsoft.com/mapi/proptag/0x5D01001F"

# OlDefaultFolders
DEFAULT_FOLDERS = {
    "inbox": 6, "sent items": 5, "sent": 5, "drafts": 16, "outbox": 4,
    "deleted items": 3, "trash": 3, "junk email": 23, "junk": 23,
}
RECIPIENT_TYPES = {1: "to", 2: "cc", 3: "bcc"}
MAX_SCAN = 20000        # items inspected while applying date limits
MAX_RECIPIENTS = 50
MAX_CONVERSATION = 100


class OutlookError(Exception):
    """User-facing failure: Outlook missing, bad folder, bad argument."""


@contextmanager
def outlook() -> Generator[Any]:
    """Yield the MAPI namespace of the running Outlook; COM is initialized per call so any
    worker thread can use it. Outlook is never started here (a profile dialog would hang)."""
    import pythoncom
    import pywintypes
    import win32com.client

    pythoncom.CoInitialize()
    app = ns = None
    try:
        try:
            app = win32com.client.GetActiveObject("Outlook.Application")
            ns = app.GetNamespace("MAPI")
        except pywintypes.com_error as exc:
            raise OutlookError(
                "Cannot reach Outlook over COM. Start classic Outlook (the 'New Outlook' toggle has no "
                "COM) and run both it and this server at the same elevation.") from exc
        yield ns
    except pywintypes.com_error as exc:
        raise OutlookError(f"Outlook COM error: {exc.excepinfo[2] if exc.excepinfo and exc.excepinfo[2] else exc}") from exc
    finally:
        app = ns = None
        gc.collect()          # release COM references before the apartment goes away
        pythoncom.CoUninitialize()


def _get(obj: Any, name: str, default: Any = None) -> Any:
    """Property read that tolerates item classes lacking it (reports, meeting responses...)."""
    try:
        value = getattr(obj, name)
    except Exception:
        return default
    return default if value is None else value


def _naive(dt: Any) -> datetime | None:
    """Outlook times are local; pywin32 may label them with a tzinfo, which is dropped."""
    if not isinstance(dt, datetime):
        return None
    return dt.replace(tzinfo=None)


def _iso(dt: Any) -> str | None:
    value = _naive(dt)
    # Outlook uses 4501-01-01 as "no date"
    return None if value is None or value.year >= 4501 else value.isoformat(timespec="seconds")


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+\n", "\n", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def parse_when(value: str | None, end: bool = False) -> datetime | None:
    """ISO date or datetime in local time. A bare date as an end bound includes that whole day."""
    if not value:
        return None
    try:
        when = datetime.fromisoformat(value.strip())
    except ValueError as exc:
        raise OutlookError(f"Invalid date {value!r}; use YYYY-MM-DD or YYYY-MM-DDTHH:MM") from exc
    if end and len(value.strip()) == 10:
        when += timedelta(days=1)
    return when.replace(tzinfo=None)


def _like(prop: str, text: str) -> str:
    return f"\"{prop}\" LIKE '%{text.replace(chr(39), chr(39) * 2)}%'"


def build_filter(query: str | None, sender: str | None, subject: str | None,
                 unread_only: bool, has_attachments: bool) -> str | None:
    """DASL filter for Items.Restrict, or None. Query terms are ANDed; each term may hit the
    subject, body or sender name."""
    clauses: list[str] = []
    for term in (query or "").split():
        clauses.append("(" + " OR ".join([
            _like("urn:schemas:httpmail:subject", term),
            _like("urn:schemas:httpmail:textdescription", term),
            _like("urn:schemas:httpmail:fromname", term)]) + ")")
    if subject:
        clauses.append(_like("urn:schemas:httpmail:subject", subject))
    if sender:
        clauses.append("(" + _like("urn:schemas:httpmail:fromname", sender)
                       + " OR " + _like(PR_SENDER_SMTP_ADDRESS, sender) + ")")
    if unread_only:
        clauses.append('"urn:schemas:httpmail:read" = 0')
    if has_attachments:
        clauses.append('"urn:schemas:httpmail:hasattachment" = 1')
    return "@SQL=" + " AND ".join(clauses) if clauses else None


def _find_store(ns: Any, store: str | None) -> Any:
    if not store:
        return ns.DefaultStore
    stores = list(ns.Stores)
    names = [s.DisplayName for s in stores]
    exact = [s for s in stores if s.DisplayName.lower() == store.lower()]
    partial = [s for s in stores if store.lower() in s.DisplayName.lower()]
    for matches in (exact, partial):
        if len(matches) == 1:
            return matches[0]
    raise OutlookError(f"Store {store!r} not found or ambiguous. Stores: {names}")


def _child(folder: Any, name: str) -> Any:
    names = [f.Name for f in folder.Folders]
    for candidate in names:
        if candidate.lower() == name.lower():
            return folder.Folders[candidate]
    raise OutlookError(f"No folder {name!r} under {folder.Name!r}. Available: {names}")


def resolve_folder(ns: Any, path: str, store: str | None = None) -> Any:
    """'Inbox', 'Sent Items', 'Inbox/Projects', or a top-level folder name in the store."""
    parts = [p for p in re.split(r"[\\/]+", path.strip()) if p]
    if not parts:
        raise OutlookError("Folder path is empty")
    st = _find_store(ns, store)
    folder_id = DEFAULT_FOLDERS.get(parts[0].lower())
    if folder_id is not None:
        try:
            folder = st.GetDefaultFolder(folder_id)
        except Exception as exc:
            raise OutlookError(f"Store {st.DisplayName!r} has no default folder {parts[0]!r}") from exc
    else:
        folder = _child(st.GetRootFolder(), parts[0])
    for part in parts[1:]:
        folder = _child(folder, part)
    return folder


def list_folders(ns: Any, store: str | None, depth: int) -> dict[str, Any]:
    st = _find_store(ns, store)
    rows: list[dict[str, Any]] = []

    def walk(folder: Any, prefix: str, level: int) -> None:
        for sub in folder.Folders:
            path = f"{prefix}/{sub.Name}" if prefix else sub.Name
            rows.append({"path": path, "items": _get(sub, "Items").Count if _get(sub, "Items") else None,
                         "unread": _get(sub, "UnReadItemCount")})
            if level < depth:
                walk(sub, path, level + 1)

    walk(st.GetRootFolder(), "", 1)
    return {"store": st.DisplayName, "stores": [s.DisplayName for s in ns.Stores], "folders": rows}


def _sender_email(item: Any) -> str | None:
    """SMTP address; the plain SenderEmailAddress is an X500 DN for Exchange-internal senders."""
    try:
        value = item.PropertyAccessor.GetProperty(PR_SENDER_SMTP_ADDRESS)
        if value:
            return value
    except Exception:
        pass
    address = _get(item, "SenderEmailAddress")
    return address if address and "@" in address else None


def summarize(item: Any, snippet_chars: int = 200) -> dict[str, Any]:
    result = {
        "entry_id": _get(item, "EntryID"),
        "subject": _get(item, "Subject", ""),
        "sender_name": _get(item, "SenderName"),
        "sender_email": _sender_email(item),
        "received": _iso(_get(item, "ReceivedTime")),
        "sent": _iso(_get(item, "SentOn")),
        "unread": bool(_get(item, "UnRead", False)),
        "has_attachments": (_get(item, "Attachments").Count > 0) if _get(item, "Attachments") else False,
        "size_bytes": _get(item, "Size"),
        "categories": _get(item, "Categories") or None,
        "message_class": _get(item, "MessageClass"),
    }
    if snippet_chars:
        body = clean_text(_get(item, "Body", "") or "")
        result["snippet"] = " ".join(body.split())[:snippet_chars]
    return result


def search(ns: Any, folder: str, store: str | None, query: str | None, sender: str | None,
           subject: str | None, since: str | None, until: str | None, unread_only: bool,
           has_attachments: bool, limit: int) -> dict[str, Any]:
    start, stop = parse_when(since), parse_when(until, end=True)
    f = resolve_folder(ns, folder, store)
    items = f.Items
    dasl = build_filter(query, sender, subject, unread_only, has_attachments)
    if dasl:
        items = items.Restrict(dasl)
    items.Sort("[ReceivedTime]", True)

    found: list[dict[str, Any]] = []
    scanned, truncated = 0, False
    item = items.GetFirst()
    while item is not None and len(found) < limit:
        scanned += 1
        if scanned > MAX_SCAN:
            truncated = True
            break
        received = _naive(_get(item, "ReceivedTime"))
        if start and received and received < start:
            break                      # sorted newest first: everything after is older
        if not (stop and received and received >= stop):
            found.append(summarize(item))
        item = items.GetNext()
    return {"folder": f.FolderPath, "count": len(found), "scan_limit_hit": truncated,
            "more_may_exist": item is not None and len(found) >= limit, "messages": found}


def _item(ns: Any, entry_id: str) -> Any:
    try:
        return ns.GetItemFromID(entry_id)
    except Exception:
        pass
    for st in ns.Stores:
        try:
            return ns.GetItemFromID(entry_id, st.StoreID)
        except Exception:
            continue
    raise OutlookError("No item with that entry_id. IDs change when a message is moved; search again.")


def read(ns: Any, entry_id: str, max_chars: int) -> dict[str, Any]:
    item = _item(ns, entry_id)
    result = summarize(item, snippet_chars=0)
    recipients = []
    all_recipients = _get(item, "Recipients")
    total = all_recipients.Count if all_recipients else 0
    for index in range(1, min(total, MAX_RECIPIENTS) + 1):
        r = all_recipients.Item(index)
        try:
            email = r.PropertyAccessor.GetProperty(PR_SMTP_ADDRESS) or None
        except Exception:
            email = None
        recipients.append({"type": RECIPIENT_TYPES.get(_get(r, "Type"), "to"), "name": _get(r, "Name"),
                           "email": email})
    attachments = []
    for a in (_get(item, "Attachments") or []):
        attachments.append({"name": _get(a, "FileName") or _get(a, "DisplayName"), "size_bytes": _get(a, "Size")})
    body = clean_text(_get(item, "Body", "") or "")
    result.update({
        "recipients": recipients, "recipients_total": total, "attachments": attachments,
        "conversation_topic": _get(item, "ConversationTopic"),
        "body": body[:max_chars], "body_chars": len(body), "body_truncated": len(body) > max_chars,
    })
    return result


def conversation(ns: Any, entry_id: str, limit: int) -> dict[str, Any]:
    item = _item(ns, entry_id)
    try:
        conv = item.GetConversation()
    except Exception:
        conv = None
    if conv is None:
        raise OutlookError("Outlook cannot give a conversation for this item (conversation view unsupported "
                           "for its store or class).")
    cap = min(limit, MAX_CONVERSATION)
    seen: dict[str, dict[str, Any]] = {}
    queue = list(conv.GetRootItems())
    while queue and len(seen) < cap:
        current = queue.pop(0)
        key = _get(current, "EntryID")
        if key in seen:
            continue
        seen[key] = summarize(current)
        queue.extend(conv.GetChildren(current))
    # Traversal is breadth-first from the thread roots, so a cut-off drops the deepest replies.
    truncated = any(_get(pending, "EntryID") not in seen for pending in queue)
    messages = sorted(seen.values(), key=lambda m: m["received"] or "")
    return {"topic": _get(item, "ConversationTopic"), "count": len(messages), "limit": cap,
            "truncated": truncated, "messages": messages}

import datetime
import os
from typing import Optional
from app.core.firebase import get_db

try:
    from google.cloud.firestore_v1 import Increment as _Inc
    def _inc(n): return _Inc(n)
except ImportError:
    def _inc(n): return n  # fallback: plain int (no server-side atomicity)


def _bump_weekly(user_ref):
    """Increment today's bar on the weekly-usage chart, resetting the count when
    a new week begins so the chart only ever reflects the *current* week.

    Uses local time (not UTC) so the logged day lines up with the app's "today"
    highlight, and stamps each day's doc with the week it belongs to (weekStart =
    this week's Monday) so the dashboard can ignore leftover days from prior weeks.
    """
    local_now = datetime.datetime.now()
    weekday = local_now.weekday()  # 0=Mon … 6=Sun
    week_start = (local_now.date() - datetime.timedelta(days=weekday)).isoformat()
    day_doc = user_ref.collection("weeklyUsage").document(str(weekday))
    try:
        snap = day_doc.get()
        data = snap.to_dict() if snap.exists else None
        if data and data.get("weekStart") == week_start:
            count = (data.get("count", 0) or 0) + 1
        else:
            count = 1  # new week (or first use of this weekday) → start fresh
        day_doc.set({"day": weekday, "count": count, "weekStart": week_start})
    except Exception as e:
        print(f"[Firestore] _bump_weekly error: {e}")


def get_document_local_path(doc_id: str) -> Optional[str]:
    """Look up the on-disk path for a previously uploaded document by its doc_id (sha256)."""
    db = get_db()
    if not db:
        return None
    try:
        snap = db.collection("DOCUMENTS").document(doc_id).get()
    except Exception as e:
        print(f"[Firestore] get_document_local_path error: {e}")
        return None
    if not snap.exists:
        return None
    data = snap.to_dict() or {}
    return data.get("local_path")


def on_document_uploaded(uid: str, filename: str, file_hash: str, file_size_bytes: int):
    """Write to user-specific Firestore paths after a document is uploaded."""
    if not uid:
        return
    db = get_db()
    if not db:
        return

    now = datetime.datetime.utcnow()
    file_ext = os.path.splitext(filename)[1].lstrip('.').lower() or 'pdf'

    try:
        user_ref = db.collection("users").document(uid)
        batch = db.batch()

        # 1. Add document to user's documents subcollection (dashboard recent docs)
        batch.set(user_ref.collection("documents").document(file_hash), {
            "name": filename,
            "sizeKb": file_size_bytes // 1024,
            "status": "uploaded",
            "fileType": file_ext,
            "uploadedAt": now,
            "hash": file_hash,
        })

        # 2. Increment user stats (dashboard stat cards)
        batch.set(user_ref.collection("stats").document("summary"), {
            "totalDocs": _inc(1),
            "docsThisWeek": _inc(1),
        }, merge=True)

        # 3. Log activity (dashboard activity feed)
        activity_ref = user_ref.collection("activity").document()
        batch.set(activity_ref, {
            "text": f"Uploaded {filename}",
            "time": now,
            "type": "upload",
        })

        batch.commit()

        # Weekly chart — separate read-modify-write so it can reset each week.
        _bump_weekly(user_ref)

    except Exception as e:
        print(f"[Firestore] on_document_uploaded error: {e}")


def on_ai_query(uid: str, question: str):
    """Update user stats and activity after an AI chat query."""
    if not uid:
        return
    db = get_db()
    if not db:
        return

    now = datetime.datetime.utcnow()

    try:
        user_ref = db.collection("users").document(uid)
        batch = db.batch()

        # Increment totalChats + aiResponses
        batch.set(user_ref.collection("stats").document("summary"), {
            "totalChats": _inc(1),
            "aiResponses": _inc(1),
        }, merge=True)

        # Log activity
        preview = question[:60] + ("..." if len(question) > 60 else "")
        activity_ref = user_ref.collection("activity").document()
        batch.set(activity_ref, {
            "text": f"Asked: {preview}",
            "time": now,
            "type": "chat",
        })

        batch.commit()

        # Weekly chart — separate read-modify-write so it can reset each week.
        _bump_weekly(user_ref)

    except Exception as e:
        print(f"[Firestore] on_ai_query error: {e}")

import datetime
import os
from typing import Optional
from app.core.firebase import get_db

try:
    from google.cloud.firestore_v1 import Increment as _Inc
    def _inc(n): return _Inc(n)
except ImportError:
    def _inc(n): return n  # fallback: plain int (no server-side atomicity)


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
    today_weekday = now.weekday()  # 0=Mon, 6=Sun
    file_ext = os.path.splitext(filename)[1].lstrip('.').lower() or 'pdf'

    try:
        user_ref = db.collection("users").document(uid)

        # 1. Add document to user's documents subcollection (dashboard recent docs)
        user_ref.collection("documents").document(file_hash).set({
            "name": filename,
            "sizeKb": file_size_bytes // 1024,
            "status": "uploaded",
            "fileType": file_ext,
            "uploadedAt": now,
            "hash": file_hash,
        })

        # 2. Increment user stats (dashboard stat cards)
        user_ref.collection("stats").document("summary").set({
            "totalDocs": _inc(1),
            "docsThisWeek": _inc(1),
        }, merge=True)

        # 3. Log activity (dashboard activity feed)
        user_ref.collection("activity").add({
            "text": f"Uploaded {filename}",
            "time": now,
            "type": "upload",
        })

        # 4. Increment today's bar on weekly chart
        user_ref.collection("weeklyUsage").document(str(today_weekday)).set({
            "day": today_weekday,
            "count": _inc(1),
        }, merge=True)

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
    today_weekday = now.weekday()

    try:
        user_ref = db.collection("users").document(uid)

        # Increment totalChats + aiResponses
        user_ref.collection("stats").document("summary").set({
            "totalChats": _inc(1),
            "aiResponses": _inc(1),
        }, merge=True)

        # Log activity
        preview = question[:60] + ("..." if len(question) > 60 else "")
        user_ref.collection("activity").add({
            "text": f"Asked: {preview}",
            "time": now,
            "type": "chat",
        })

        # Weekly chart
        user_ref.collection("weeklyUsage").document(str(today_weekday)).set({
            "day": today_weekday,
            "count": _inc(1),
        }, merge=True)

    except Exception as e:
        print(f"[Firestore] on_ai_query error: {e}")

import os
import sys
import datetime
from fastapi import HTTPException
from app.utils.hashing import generate_file_hash
from app.core.firebase import get_db, get_bucket

# Shared at-rest encryption helper (lives in the AI package).
_AI_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../AI"))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)
from crypto import encrypt_bytes

UPLOAD_DIR = os.path.abspath("uploads")
USE_FIREBASE_STORAGE = os.getenv("USE_FIREBASE_STORAGE", "false").lower() == "true"
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(50 * 1024 * 1024)))  # 50 MB
ALLOWED_EXTS = {".pdf", ".docx", ".txt"}

if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)


def _safe_extension(filename: str | None) -> str:
    """Return a normalized, allow-listed file extension. Defaults to .pdf if missing."""
    if not filename:
        return ".pdf"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {ext or '(none)'}. Allowed: {sorted(ALLOWED_EXTS)}",
        )
    return ext


def save_document(file):
    # Read in chunks to avoid loading oversized files fully into memory
    chunks = []
    total = 0
    while True:
        chunk = file.file.read(1024 * 1024)  # 1 MB at a time
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_UPLOAD_BYTES:
            raise HTTPException(
                status_code=413,
                detail=f"File exceeds max size of {MAX_UPLOAD_BYTES} bytes",
            )
        chunks.append(chunk)
    file_bytes = b"".join(chunks)
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty upload")

    ext = _safe_extension(file.filename)
    file_hash = generate_file_hash(file_bytes)

    # Always save locally — AI pipeline needs local file access.
    # Name the file by its hash (not the user-supplied filename) to prevent
    # path traversal and filename collisions between users.
    safe_name = f"{file_hash}{ext}"
    file_path = os.path.join(UPLOAD_DIR, safe_name)
    # Defense in depth: confirm the resolved path is still inside UPLOAD_DIR.
    if os.path.commonpath([os.path.abspath(file_path), UPLOAD_DIR]) != UPLOAD_DIR:
        raise HTTPException(status_code=400, detail="Invalid upload path")

    # Encrypt at rest (no-op unless FILE_ENCRYPTION_KEY is set). The hash and
    # Firebase copy stay based on the original bytes, so verification is
    # unaffected and only the local disk copy is ciphertext.
    with open(file_path, "wb") as f:
        f.write(encrypt_bytes(file_bytes))

    storage_url = f"local://{file_path}"

    # Upload to Firebase Storage only when flag is enabled
    if USE_FIREBASE_STORAGE:
        try:
            bucket = get_bucket()
            blob = bucket.blob(f"documents/{file_hash}/{safe_name}")
            blob.upload_from_string(
                file_bytes,
                content_type=file.content_type or "application/octet-stream"
            )
            blob.make_public()
            storage_url = blob.public_url
        except Exception as e:
            print(f"[Storage] Firebase upload failed, keeping local: {e}")

    # Write metadata to Firestore DOCUMENTS collection
    try:
        db = get_db()
        db.collection("DOCUMENTS").document(file_hash).set({
            "doc_id": file_hash,
            "filename": file.filename,
            "hash": file_hash,
            "local_path": file_path,
            "storage_url": storage_url,
            "uploaded_at": datetime.datetime.utcnow().isoformat(),
            "status": "uploaded"
        })
    except Exception as e:
        print(f"[Firestore] Write failed: {e}")

    return {
        "filename": file.filename,
        "path": file_path,
        "hash": file_hash,
        "storage_url": storage_url,
        "size_bytes": len(file_bytes),
    }

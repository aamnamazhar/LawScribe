from typing import Optional
from fastapi import APIRouter, UploadFile, File, Header
from app.services.document_service import save_document
from app.services.ai_service import index_document_file
from app.services.blockchain_service import store_document_hash
from app.services.firestore_service import on_document_uploaded
from app.utils.auth import get_uid

router = APIRouter(prefix="/documents", tags=["Documents"])


@router.post("/upload")
def upload_document(
    file: UploadFile = File(...),
    authorization: Optional[str] = Header(None),
):
    uid = get_uid(authorization)
    if not uid:
        from fastapi import HTTPException
        raise HTTPException(status_code=401, detail="Authentication required")

    result = save_document(file)

    doc_id = result["hash"]
    file_path = result["path"]
    file_size = result.get("size_bytes", 0)

    # Index document in ChromaDB for RAG queries
    try:
        chunks = index_document_file(file_path, doc_id)
        result["chunks_indexed"] = chunks
    except Exception as e:
        result["index_error"] = str(e)

    # Log hash to blockchain (non-blocking)
    tx_hash = store_document_hash(doc_id, uid, result["hash"])
    if tx_hash:
        result["blockchain_tx"] = tx_hash

    # Write real data to user-specific Firestore paths
    on_document_uploaded(uid, file.filename, doc_id, file_size)

    return {"message": "File uploaded successfully", "file": result}

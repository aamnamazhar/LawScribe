import os
from fastapi import APIRouter, HTTPException
from app.services.extraction_service import extract_text_from_pdf

router = APIRouter(prefix="/documents", tags=["Extraction"])

_UPLOAD_DIR = os.path.abspath("uploads")


@router.get("/extract")
def extract_document_text(file_path: str):
    # Prevent path traversal — only allow files inside the uploads directory
    abs_path = os.path.abspath(file_path)
    if os.path.commonpath([abs_path, _UPLOAD_DIR]) != _UPLOAD_DIR:
        raise HTTPException(status_code=400, detail="Invalid file path")
    if not os.path.isfile(abs_path):
        raise HTTPException(status_code=404, detail="File not found")

    try:
        extracted_text = extract_text_from_pdf(abs_path)

        return {
            "message": "Text extracted successfully",
            "text": extracted_text[:3000]  # preview only
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail="Text extraction failed")
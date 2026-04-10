from fastapi import APIRouter, HTTPException
from app.services.extraction_service import extract_text_from_pdf

router = APIRouter(prefix="/documents", tags=["Extraction"])

@router.get("/extract")
def extract_document_text(file_path: str):
    try:
        extracted_text = extract_text_from_pdf(file_path)

        return {
            "message": "Text extracted successfully",
            "text": extracted_text[:3000]  # preview only
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
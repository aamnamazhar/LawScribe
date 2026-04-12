import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from app.services.ai_service import (
    get_summary, answer_question, get_clauses, get_insights,
    get_summary_stream, answer_question_stream,
)
from app.services.blockchain_service import verify_document_hash
from app.services.firestore_service import on_ai_query
from app.dependencies.auth import verify_firebase_token
from app.utils.auth import get_uid

router = APIRouter(prefix="/ai", tags=["AI"])


class QueryRequest(BaseModel):
    doc_id: str
    question: str


class DocRequest(BaseModel):
    doc_id: str


@router.get("/summary")
def summarize_document(doc_id: str, user=Depends(verify_firebase_token)):
    try:
        summary = get_summary(doc_id)
        return {"summary": summary}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/query")
def query_document(
    req: QueryRequest,
    authorization: Optional[str] = Header(None),
):
    uid = get_uid(authorization)
    if not uid:
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    try:
        answer = answer_question(req.question, req.doc_id)
        on_ai_query(uid, req.question)
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/clauses")
def detect_document_clauses(req: DocRequest, user=Depends(verify_firebase_token)):
    try:
        clauses = get_clauses(req.doc_id)
        return {"clauses": clauses}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/insights")
def get_document_insights(req: DocRequest, user=Depends(verify_firebase_token)):
    try:
        insights = get_insights(req.doc_id)
        return {"insights": insights}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _sse_generator(text_stream):
    """Wrap a text-chunk generator as Server-Sent Events."""
    for chunk in text_stream:
        # SSE format: data: <json>\n\n
        yield f"data: {json.dumps({'token': chunk})}\n\n"
    yield "data: [DONE]\n\n"


@router.get("/summary/stream")
def summarize_document_stream(doc_id: str, user=Depends(verify_firebase_token)):
    try:
        return StreamingResponse(
            _sse_generator(get_summary_stream(doc_id)),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/query/stream")
def query_document_stream(
    req: QueryRequest,
    authorization: Optional[str] = Header(None),
):
    uid = get_uid(authorization)
    if not uid:
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    try:
        on_ai_query(uid, req.question)
        return StreamingResponse(
            _sse_generator(answer_question_stream(req.question, req.doc_id)),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/verify")
def verify_document(doc_id: str, file_hash: str, user=Depends(verify_firebase_token)):
    verified = verify_document_hash(doc_id, file_hash)
    return {"verified": verified}

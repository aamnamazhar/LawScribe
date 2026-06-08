import os
import sys

# Add AI directory to Python path so we can import rag, clause_detector, etc.
_AI_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../AI")
)
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

from rag import (
    index_document, query_document, generate_summary, generate_insights,
    query_document_stream, generate_summary_stream,
    general_query, general_query_stream,
)
from clause_detector import detect_clauses
from ledgar_classifier import classify_provision as _classify_provision
from extract import extract_text
from preprocess import clean_text

from app.services.firestore_service import get_document_local_path

# Restrict any path resolved from a doc_id to live under the uploads dir.
# Prevents an attacker who controls Firestore from pointing us at /etc/passwd.
_UPLOAD_DIR = os.path.abspath("uploads")


def _resolve_doc_path(doc_id: str) -> str:
    """Look up the on-disk path for a doc_id and verify it lives under uploads/."""
    path = get_document_local_path(doc_id)
    if not path:
        raise FileNotFoundError(f"Document {doc_id} not found")
    abs_path = os.path.abspath(path)
    if os.path.commonpath([abs_path, _UPLOAD_DIR]) != _UPLOAD_DIR:
        raise PermissionError(f"Document path is outside uploads dir: {abs_path}")
    if not os.path.isfile(abs_path):
        raise FileNotFoundError(f"Document file missing on disk: {abs_path}")
    return abs_path


def index_document_file(file_path: str, doc_id: str) -> int:
    """Index a document into ChromaDB. Returns number of chunks stored."""
    return index_document(file_path, doc_id)


def get_summary(doc_id: str) -> str:
    """Generate a plain-English summary using RAG over indexed chunks."""
    return generate_summary(doc_id)


def answer_question(question: str, doc_id: str) -> str:
    """Answer a question about a document using RAG."""
    return query_document(question, doc_id)


def get_summary_stream(doc_id: str):
    """Streaming summary — yields text chunks."""
    yield from generate_summary_stream(doc_id)


def answer_question_stream(question: str, doc_id: str):
    """Streaming Q&A — yields text chunks."""
    yield from query_document_stream(question, doc_id)


def general_answer(question: str) -> str:
    """Answer a general legal question with no document (hybrid grounding)."""
    return general_query(question)


def general_answer_stream(question: str):
    """Streaming general Q&A — yields text chunks."""
    yield from general_query_stream(question)


def get_clauses(doc_id: str) -> list:
    """Detect legal clause types present in a previously uploaded document."""
    file_path = _resolve_doc_path(doc_id)
    raw_text = extract_text(file_path)
    cleaned = clean_text(raw_text)
    return detect_clauses(cleaned)


def get_insights(doc_id: str) -> list:
    """Return per-clause plain-English insights using Groq."""
    clauses = get_clauses(doc_id)
    return generate_insights(clauses, doc_id)


def classify_provision_text(text: str) -> list:
    """Classify a single contractual provision into LEDGAR categories (top 3)."""
    return _classify_provision(text)

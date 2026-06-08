from pypdf import PdfReader
from docx import Document
import os
import io
import sys

# Reuse the shared at-rest decryption helper from the AI package.
_AI_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../AI"))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)
from crypto import decrypt_bytes


def _read_bytes(file_path: str) -> bytes:
    """Read a stored document and decrypt it if it was encrypted at rest."""
    with open(file_path, "rb") as f:
        return decrypt_bytes(f.read())


def extract_text_from_file(file_path: str) -> str:
    extension = os.path.splitext(file_path)[1].lower()

    if extension == ".pdf":
        return extract_text_from_pdf(file_path)
    elif extension == ".docx":
        return extract_text_from_docx(file_path)
    else:
        raise ValueError(f"Unsupported file type: {extension}")


def extract_text_from_pdf(file_path: str) -> str:
    reader = PdfReader(io.BytesIO(_read_bytes(file_path)))
    text = ""

    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            text += page_text + "\n"

    return text.strip()


def extract_text_from_docx(file_path: str) -> str:
    doc = Document(io.BytesIO(_read_bytes(file_path)))
    text = "\n".join([para.text for para in doc.paragraphs])
    return text.strip()

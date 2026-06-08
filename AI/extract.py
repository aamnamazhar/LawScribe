import fitz  # this is pymupdf
from docx import Document
import os
import io
import sys

# Allow importing the crypto helper whether this runs from AI/ directly or via
# the backend (which adds AI/ to sys.path).
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
from crypto import decrypt_bytes


def _read_bytes(file_path):
    """Read a stored document and decrypt it if it was encrypted at rest."""
    with open(file_path, "rb") as f:
        return decrypt_bytes(f.read())


def extract_from_pdf(data):
    """Extract text from PDF bytes. Falls back to OCR for scanned/image pages."""
    doc = fitz.open(stream=data, filetype="pdf")
    text = ""
    ocr_pages = []

    for i, page in enumerate(doc):
        page_text = page.get_text()
        if page_text.strip():
            text += page_text
        else:
            ocr_pages.append(i)

    # If some pages had no extractable text, try OCR
    if ocr_pages:
        try:
            import pytesseract
            from PIL import Image

            for i in ocr_pages:
                page = doc[i]
                pix = page.get_pixmap(dpi=300)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                text += pytesseract.image_to_string(img)
        except ImportError:
            # pytesseract not installed — skip OCR silently
            pass

    return text


def extract_from_docx(data):
    doc = Document(io.BytesIO(data))
    text = ""
    for paragraph in doc.paragraphs:
        text += paragraph.text + "\n"
    return text


def extract_from_txt(data):
    return data.decode("utf-8", errors="ignore")


def extract_text(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    data = _read_bytes(file_path)

    if ext == ".pdf":
        return extract_from_pdf(data)
    elif ext == ".docx":
        return extract_from_docx(data)
    elif ext == ".txt":
        return extract_from_txt(data)
    else:
        raise ValueError(f"Unsupported file format: {ext or '(none)'}")


# --- test it ---
if __name__ == "__main__":
    path = "sample.pdf"
    text = extract_text(path)
    print(text[:500])

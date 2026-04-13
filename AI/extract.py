import fitz  # this is pymupdf
from docx import Document
import os


def extract_from_pdf(file_path):
    """Extract text from PDF. Falls back to OCR for scanned/image-based pages."""
    doc = fitz.open(file_path)
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
            import io

            for i in ocr_pages:
                page = doc[i]
                pix = page.get_pixmap(dpi=300)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                page_text = pytesseract.image_to_string(img)
                text += page_text
        except ImportError:
            # pytesseract not installed — skip OCR silently
            pass

    return text


def extract_from_docx(file_path):
    text = ""
    doc = Document(file_path)
    for paragraph in doc.paragraphs:
        text += paragraph.text + "\n"
    return text


def extract_from_txt(file_path):
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()


def extract_text(file_path):
    ext = os.path.splitext(file_path)[1].lower()

    if ext == ".pdf":
        return extract_from_pdf(file_path)
    elif ext == ".docx":
        return extract_from_docx(file_path)
    elif ext == ".txt":
        return extract_from_txt(file_path)
    else:
        raise ValueError(f"Unsupported file format: {ext or '(none)'}")


# --- test it ---
if __name__ == "__main__":
    path = "sample.pdf"
    text = extract_text(path)
    print(text[:500])
import fitz  # this is pymupdf
from docx import Document
import os


def extract_from_pdf(file_path):
    text = ""
    doc = fitz.open(file_path)
    for page in doc:
        text += page.get_text()
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
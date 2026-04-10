import re

def clean_text(text):
    # remove extra whitespace and blank lines
    text = re.sub(r'\n\s*\n', '\n', text)
    
    # remove weird characters (keep letters, numbers, punctuation)
    text = re.sub(r'[^\x00-\x7F]+', ' ', text)
    
    # remove multiple spaces
    text = re.sub(r' +', ' ', text)
    
    # strip leading/trailing whitespace
    text = text.strip()
    
    return text

def chunk_text(text, chunk_size=500, overlap=50):
    """
    Splits text into overlapping chunks.
    chunk_size = how many words per chunk
    overlap = how many words repeated between chunks
    (overlap helps so we don't cut a sentence right in the middle)
    """
    if chunk_size <= 0:
        raise ValueError("chunk_size must be > 0")
    # Guarantee forward progress even if a caller passes overlap >= chunk_size.
    step = max(1, chunk_size - overlap)

    words = text.split()
    chunks = []
    start = 0

    while start < len(words):
        end = start + chunk_size
        chunk = ' '.join(words[start:end])
        chunks.append(chunk)
        start += step

    return chunks

# --- test it ---
if __name__ == "__main__":
    from extract import extract_text

    path = "sample.pdf"  # same file you tested earlier
    raw_text = extract_text(path)
    
    cleaned = clean_text(raw_text)
    chunks = chunk_text(cleaned)
    
    print(f"Total chunks: {len(chunks)}")
    print(f"\n--- Chunk 1 ---\n{chunks[0]}")
    print(f"\n--- Chunk 2 ---\n{chunks[1]}")
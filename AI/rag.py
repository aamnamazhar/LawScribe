import os
import sys

# Ensure AI directory is always on sys.path regardless of where Python is run from
_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

import chromadb
from groq import Groq
from sentence_transformers import SentenceTransformer
from preprocess import clean_text, chunk_text
from extract import extract_text

# --- setup ---
print("Loading embedding model...")
embedder = SentenceTransformer('all-MiniLM-L6-v2')
print("Embedding model loaded!")

# setup chromadb — path relative to this file, not CWD
chroma_client = chromadb.PersistentClient(path=os.path.join(_AI_DIR, "vectorstore"))

# setup groq
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise RuntimeError(
        "GROQ_API_KEY is not set. Add it to your environment or .env file."
    )
client = Groq(api_key=GROQ_API_KEY)


def index_document(file_path, doc_id):
    """
    Extract, clean, chunk and store a document in ChromaDB.
    Call this when a user uploads a document.
    """
    print(f"Indexing document: {file_path}")

    raw_text = extract_text(file_path)
    cleaned = clean_text(raw_text)
    chunks = chunk_text(cleaned)

    collection = chroma_client.get_or_create_collection(name=f"doc_{doc_id}")

    for i, chunk in enumerate(chunks):
        embedding = embedder.encode(chunk).tolist()
        collection.add(
            documents=[chunk],
            embeddings=[embedding],
            ids=[f"chunk_{i}"]
        )

    print(f"✅ Indexed {len(chunks)} chunks for document {doc_id}")
    return len(chunks)


def query_document(question, doc_id, top_k=3):
    """
    Find relevant chunks and answer using Groq + LLaMA.
    """
    try:
        collection = chroma_client.get_collection(name=f"doc_{doc_id}")
    except Exception as e:
        print(f"[rag] query_document: collection lookup failed: {e}")
        return "Document not found. Please upload it first."

    # embed the question
    question_embedding = embedder.encode(question).tolist()

    # find most relevant chunks
    results = collection.query(
        query_embeddings=[question_embedding],
        n_results=top_k
    )

    relevant_chunks = results['documents'][0]
    context = "\n\n".join(relevant_chunks)

    prompt = f"""You are a legal document assistant.
Answer the question based ONLY on the document context provided below.
If the answer is not in the context, say "I couldn't find this in the document."
Do not make up information.

Document Context:
{context}

Question: {question}

Answer:"""

    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "user", "content": prompt}
        ]
    )
    return response.choices[0].message.content


def generate_summary(doc_id):
    """
    Generate a plain language summary of the document.
    """
    try:
        collection = chroma_client.get_collection(name=f"doc_{doc_id}")
    except Exception as e:
        print(f"[rag] generate_summary: collection lookup failed: {e}")
        return "Document not found."

    # get all chunks
    results = collection.get()
    all_text = "\n\n".join(results['documents'][:5])  # first 5 chunks

    prompt = f"""You are a legal document assistant.
Summarize the following legal document in simple, plain English.
Keep it concise — 3 to 5 sentences.
Do not use legal jargon.

Document:
{all_text}

Summary:"""

    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "user", "content": prompt}
        ]
    )
    return response.choices[0].message.content


def generate_insights(detected_clauses, doc_id):
    """
    For each detected clause, retrieve the most relevant chunks from the
    indexed document and generate a plain-English explanation grounded in
    the actual contract language (not a generic definition).
    """
    if not detected_clauses:
        return []

    try:
        collection = chroma_client.get_collection(name=f"doc_{doc_id}")
    except Exception as e:
        print(f"[rag] generate_insights: collection lookup failed: {e}")
        return []

    insights = []

    for clause in detected_clauses:
        clause_type = clause['clause_type']
        confidence = clause['confidence']

        # Pull the chunks most semantically similar to this clause type so the
        # LLM can ground its explanation in the actual contract text.
        try:
            query_embedding = embedder.encode(clause_type).tolist()
            results = collection.query(
                query_embeddings=[query_embedding],
                n_results=3,
            )
            relevant = results.get('documents', [[]])[0] or []
        except Exception as e:
            print(f"[rag] generate_insights: query failed for {clause_type}: {e}")
            relevant = []

        context = "\n\n---\n\n".join(relevant) if relevant else "(no matching excerpt found)"

        prompt = f"""You are a legal document assistant helping non-lawyers understand contracts.

A "{clause_type}" clause was detected in this document (model confidence: {confidence}%).

Here are the most relevant excerpts from the actual contract:
{context}

Based on the excerpts above, provide a brief insight in this exact format:
1. What it means: (1 sentence plain English explanation grounded in the excerpt)
2. Why it matters: (1 sentence why the user should care)
3. Risk level: (Low / Medium / High)

Keep it simple, no legal jargon. If the excerpts do not actually contain this clause, say so."""

        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        insights.append({
            'clause_type': clause_type,
            'confidence': confidence,
            'insight': response.choices[0].message.content
        })

    return insights


def delete_document(doc_id):
    """
    Remove a document from ChromaDB.
    """
    try:
        chroma_client.delete_collection(name=f"doc_{doc_id}")
        print(f"✅ Deleted document {doc_id}")
    except Exception as e:
        print(f"Document {doc_id} not found ({e})")


# --- test it ---
if __name__ == "__main__":
    from clause_detector import detect_clauses
    from preprocess import clean_text
    from extract import extract_text

    delete_document("test001")

    path = r"C:\Users\USER\OneDrive\Documents\LAWSCRIBE\AI\contract.pdf"
    
    index_document(path, doc_id="test001")

    print("\n--- SUMMARY ---\n")
    summary = generate_summary("test001")
    print(summary)

    print("\n--- CLAUSE DETECTION ---\n")
    raw_text = extract_text(path)
    cleaned = clean_text(raw_text)
    clauses = detect_clauses(cleaned)
    print(f"Found {len(clauses)} clauses:")
    for c in clauses:
        print(f"  ✅ {c['clause_type']} — {c['confidence']}%")

    print("\n--- INSIGHTS ---\n")
    insights = generate_insights(clauses, "test001")
    for insight in insights:
        print(f"📌 {insight['clause_type']} ({insight['confidence']}% confidence)")
        print(insight['insight'])
        print()

    print("\n--- Q&A ---\n")
    questions = [
        "What is this contract about?",
        "Who are the parties involved?",
        "What are the termination conditions?",
    ]
    for q in questions:
        print(f"Q: {q}")
        answer = query_document(q, doc_id="test001")
        print(f"A: {answer}\n")
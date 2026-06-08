import os
import sys

# HuggingFace's new "Xet" download backend (hf_xet) triggers
# "WinError 10054: connection forcibly closed" on some Windows setups, which
# crashes model loading. Force the classic HTTP download path for reliability.
# Must be set BEFORE importing sentence_transformers / huggingface_hub.
os.environ.setdefault("HF_HUB_DISABLE_XET", "1")

# Ensure AI directory is always on sys.path regardless of where Python is run from
_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

import chromadb
from groq import Groq
from sentence_transformers import SentenceTransformer
from preprocess import clean_text, chunk_text
from extract import extract_text
from reference_kb import reference_documents

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
client = Groq(api_key=GROQ_API_KEY, timeout=60.0)


# --- reference knowledge base (for general-mode Q&A without a document) ---
# A small, persistent collection of LawScribe's own plain-English clause
# definitions. When a user asks a general question, we retrieve the closest
# definitions and let the LLM ground its answer in them — keeping general-mode
# answers consistent with how the app explains the same clauses on documents.
_REFERENCE_COLLECTION = "lawscribe_reference_kb"
# Cosine distance is in [0, 2]; lower means more similar. Anything above this is
# treated as "no good match" and the LLM answers from its own knowledge instead.
_REFERENCE_MAX_DISTANCE = 0.75


def _ensure_reference_kb():
    """Create and populate the reference collection once (idempotent)."""
    collection = chroma_client.get_or_create_collection(
        name=_REFERENCE_COLLECTION,
        metadata={"hnsw:space": "cosine"},
    )
    if collection.count() == 0:
        ids, docs, embeddings = [], [], []
        for clause_id, text in reference_documents():
            ids.append(clause_id)
            docs.append(text)
            embeddings.append(embedder.encode(text).tolist())
        collection.add(ids=ids, documents=docs, embeddings=embeddings)
        print(f"✅ Indexed {len(ids)} reference clause definitions")
    return collection


_reference_collection = _ensure_reference_kb()


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

    prompt = f"""You are LawScribe — a friendly, smart friend who happens to know contracts. Talk like a real person helping a friend make sense of a document, NOT like a robot reading a template. Be warm, direct, and a little opinionated when it helps.

Style rules:
- Sound human. Use "you", contractions ("you'd", "they're"), and natural phrasing. Short paragraphs are fine.
- Lead with the punchline, then back it up. No long preambles.
- Be specific — quote or paraphrase the actual numbers/terms from the contract, don't speak in abstractions.
- Be honest. If something looks bad, say it looks bad. If it looks solid, say so.
- No corporate-speak. No "it is important to note that". No bullet soup when a sentence works.

How to answer:
- **Facts** ("what is...", "who are..."): answer straight, one or two sentences.
- **Judgment** ("is this a good job?", "should I sign?"): give a real verdict — "honestly, it's decent but X would worry me" — then 2-4 specific reasons tied to the actual terms. Mention the good AND the bad.
- **Risks** ("what are the key risks?"): walk through the 3-5 biggest ones conversationally. For each: what it actually says, and what could go wrong for YOU. Rank by how much it should keep you up at night.
- **Action plan** ("what should I do?"): give 3-6 concrete moves tied to THIS contract — what to push back on, what to clarify, what to get in writing. Make it feel like advice from a friend who read it carefully.
- If the excerpts don't cover it, say that — but reason with what's there before giving up.

End judgment / risk / action answers with one short line: "Not legal advice, just a read on what's in here."

Document Excerpts:
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


def query_document_stream(question, doc_id, top_k=3):
    """
    Streaming version of query_document — yields text chunks as they arrive.
    """
    try:
        collection = chroma_client.get_collection(name=f"doc_{doc_id}")
    except Exception as e:
        print(f"[rag] query_document_stream: collection lookup failed: {e}")
        yield "Document not found. Please upload it first."
        return

    question_embedding = embedder.encode(question).tolist()
    results = collection.query(
        query_embeddings=[question_embedding],
        n_results=top_k
    )

    relevant_chunks = results['documents'][0]
    context = "\n\n".join(relevant_chunks)

    prompt = f"""You are LawScribe — a friendly, smart friend who happens to know contracts. Talk like a real person helping a friend make sense of a document, NOT like a robot reading a template. Be warm, direct, and a little opinionated when it helps.

Style rules:
- Sound human. Use "you", contractions ("you'd", "they're"), and natural phrasing. Short paragraphs are fine.
- Lead with the punchline, then back it up. No long preambles.
- Be specific — quote or paraphrase the actual numbers/terms from the contract, don't speak in abstractions.
- Be honest. If something looks bad, say it looks bad. If it looks solid, say so.
- No corporate-speak. No "it is important to note that". No bullet soup when a sentence works.

How to answer:
- **Facts** ("what is...", "who are..."): answer straight, one or two sentences.
- **Judgment** ("is this a good job?", "should I sign?"): give a real verdict — "honestly, it's decent but X would worry me" — then 2-4 specific reasons tied to the actual terms. Mention the good AND the bad.
- **Risks** ("what are the key risks?"): walk through the 3-5 biggest ones conversationally. For each: what it actually says, and what could go wrong for YOU. Rank by how much it should keep you up at night.
- **Action plan** ("what should I do?"): give 3-6 concrete moves tied to THIS contract — what to push back on, what to clarify, what to get in writing. Make it feel like advice from a friend who read it carefully.
- If the excerpts don't cover it, say that — but reason with what's there before giving up.

End judgment / risk / action answers with one short line: "Not legal advice, just a read on what's in here."

Document Excerpts:
{context}

Question: {question}

Answer:"""

    stream = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta


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


def generate_summary_stream(doc_id):
    """
    Streaming version of generate_summary — yields text chunks as they arrive.
    """
    try:
        collection = chroma_client.get_collection(name=f"doc_{doc_id}")
    except Exception as e:
        print(f"[rag] generate_summary_stream: collection lookup failed: {e}")
        yield "Document not found."
        return

    results = collection.get()
    all_text = "\n\n".join(results['documents'][:5])

    prompt = f"""You are a legal document assistant.
Summarize the following legal document in simple, plain English.
Keep it concise — 3 to 5 sentences.
Do not use legal jargon.

Document:
{all_text}

Summary:"""

    stream = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta


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


def _retrieve_reference(question, top_k=3):
    """
    Return LawScribe's own clause definitions most relevant to the question.
    Only matches closer than the distance threshold are kept, so unrelated
    questions return nothing and the LLM falls back to general knowledge.
    """
    try:
        q_emb = embedder.encode(question).tolist()
        results = _reference_collection.query(
            query_embeddings=[q_emb],
            n_results=top_k,
        )
    except Exception as e:
        print(f"[rag] _retrieve_reference: query failed: {e}")
        return []

    docs = results.get('documents', [[]])[0] or []
    dists = results.get('distances', [[]])[0] or []
    return [d for d, dist in zip(docs, dists) if dist <= _REFERENCE_MAX_DISTANCE]


def _build_general_prompt(question, reference_notes):
    """Build the general-mode prompt, grounding in reference notes when present."""
    if reference_notes:
        notes = "\n".join(f"- {n}" for n in reference_notes)
        grounding = (
            "Here are LawScribe's own plain-English notes on the most relevant "
            "clause types. If they fit the question, ground your answer in them "
            "and stay consistent with this wording:\n\n"
            f"{notes}\n"
        )
    else:
        grounding = (
            "(No specific clause definition matched — answer from your general "
            "legal knowledge.)"
        )

    return f"""You are LawScribe — a friendly, smart friend who happens to know contracts. The user hasn't uploaded a document; they're just asking a general question about contracts, clauses, or legal terms. Help them understand it like a real person would, NOT like a robot reading a template.

Style rules:
- Sound human. Use "you", contractions, and natural phrasing. Short paragraphs are fine.
- Lead with the punchline, then back it up. No long preambles.
- Explain plainly, no legal jargon. If you must use a legal term, define it in the same breath.
- Be honest and a little opinionated when it helps ("a 2-year non-compete is on the longer side").

Important:
- This is general information, NOT legal advice about anyone's specific situation.
- When it's relevant, gently nudge them: they can upload their own contract and you'll analyze exactly what THEIRS says.
- End with one short line: "Just general info, not legal advice — upload your contract and I'll check yours."

{grounding}

Question: {question}

Answer:"""


def general_query(question):
    """
    Answer a general legal question with no uploaded document (hybrid mode):
    grounded in LawScribe's clause definitions when they match, otherwise the
    LLM's own knowledge.
    """
    prompt = _build_general_prompt(question, _retrieve_reference(question))
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content


def general_query_stream(question):
    """Streaming version of general_query — yields text chunks as they arrive."""
    prompt = _build_general_prompt(question, _retrieve_reference(question))
    stream = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            yield delta


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
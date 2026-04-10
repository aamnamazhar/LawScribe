import os
import sys

_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

# all 41 clause types from CUAD
CLAUSE_TYPES = [
    "Affiliate License-Licensee", "Affiliate License-Licensor",
    "Agreement Date", "Anti-Assignment", "Audit Rights",
    "Cap On Liability", "Change Of Control",
    "Competitive Restriction Exception", "Covenant Not To Sue",
    "Document Name", "Effective Date", "Exclusivity",
    "Expiration Date", "Governing Law", "Insurance",
    "Ip Ownership Assignment", "Irrevocable Or Perpetual License",
    "Joint Ip Ownership", "License Grant", "Liquidated Damages",
    "Minimum Commitment", "Most Favored Nation",
    "No-Solicit Of Customers", "No-Solicit Of Employees",
    "Non-Compete", "Non-Disparagement", "Non-Transferable License",
    "Notice Period To Terminate Renewal", "Parties",
    "Post-Termination Services", "Price Restrictions",
    "Renewal Term", "Revenue/Profit Sharing", "Rofr/Rofo/Rofn",
    "Source Code Escrow", "Termination For Convenience",
    "Third Party Beneficiary", "Uncapped Liability",
    "Unlimited/All-You-Can-Eat-License", "Volume Restriction",
    "Warranty Duration"
]

# load model and tokenizer once — path relative to this file, not CWD
_MODEL_PATH = os.path.join(_AI_DIR, "clause_model")
print("Loading clause detection model...")
tokenizer = AutoTokenizer.from_pretrained(_MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(_MODEL_PATH)
model.eval()
print("Model loaded!")

def detect_clauses(text, chunk_size=1500, overlap=200):
    """
    Given a document text, returns a list of clauses detected
    in it with confidence scores.

    The document is split into overlapping windows so clauses
    anywhere in the document are examined (not just the first
    512 characters). For each window, all 41 clause types are
    scored in a single batched forward pass. Results are
    deduped by clause type — highest confidence wins.
    """
    if not text or not text.strip():
        return []

    # Build overlapping char windows
    if len(text) <= chunk_size:
        chunks = [text]
    else:
        chunks = []
        step = max(1, chunk_size - overlap)
        start = 0
        while start < len(text):
            chunks.append(text[start:start + chunk_size])
            start += step

    # clause_type -> highest confidence seen across all chunks
    best = {}

    for chunk in chunks:
        # Batch all 41 clause types in one forward pass per chunk
        batch_inputs = [
            clause_type + " [SEP] " + chunk for clause_type in CLAUSE_TYPES
        ]

        inputs = tokenizer(
            batch_inputs,
            max_length=512,
            padding=True,
            truncation=True,
            return_tensors="pt"
        )

        with torch.no_grad():
            outputs = model(**inputs)
            probabilities = torch.softmax(outputs.logits, dim=1)
            confidences = probabilities[:, 1].tolist()  # P("clause present")

        for clause_type, confidence in zip(CLAUSE_TYPES, confidences):
            if confidence > 0.5 and confidence > best.get(clause_type, 0.0):
                best[clause_type] = confidence

    return [
        {'clause_type': ct, 'confidence': round(conf * 100, 2)}
        for ct, conf in sorted(best.items(), key=lambda kv: -kv[1])
    ]

# --- test it ---
if __name__ == "__main__":
    from extract import extract_text
    from preprocess import clean_text

    # use any contract pdf you have
    path = "sample.pdf"
    raw_text = extract_text(path)
    cleaned = clean_text(raw_text)

    print("\nDetecting clauses...\n")
    results = detect_clauses(cleaned)

    print(f"Found {len(results)} clauses:\n")
    for r in results:
        print(f"  ✅ {r['clause_type']} — {r['confidence']}% confidence")
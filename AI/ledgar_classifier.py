import os
import sys

_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)

from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

# Load the LEDGAR provision classifier once — path relative to this file.
# This model classifies a single contractual provision into one of 100
# LEDGAR categories (e.g., "Governing Laws", "Limitation of Liability").
# It complements clause_detector.py: that model scans a whole contract for
# clause presence, whereas this one labels a single provided clause.
_MODEL_PATH = os.path.join(_AI_DIR, "ledgar_model")
print("Loading LEDGAR provision classifier...")
_tokenizer = AutoTokenizer.from_pretrained(_MODEL_PATH)
_model = AutoModelForSequenceClassification.from_pretrained(_MODEL_PATH)
_model.eval()

# The 100 category names were saved into the model config (id2label) at
# training time. JSON keys load back as strings, so normalise to int keys.
_ID2LABEL = {int(k): v for k, v in _model.config.id2label.items()}
print("LEDGAR classifier loaded!")


def classify_provision(text, top_k=3):
    """
    Classify a single contractual provision into LEDGAR categories.

    Returns the top_k predictions as a list of
    {'category': str, 'confidence': float} dicts, sorted by confidence.
    """
    if not text or not text.strip():
        return []

    inputs = _tokenizer(
        text,
        max_length=512,
        truncation=True,
        padding=True,
        return_tensors="pt",
    )

    with torch.no_grad():
        logits = _model(**inputs).logits
        probs = torch.softmax(logits, dim=1)[0]

    k = min(top_k, probs.shape[0])
    top = torch.topk(probs, k)
    return [
        {"category": _ID2LABEL[int(idx)], "confidence": round(float(p) * 100, 2)}
        for p, idx in zip(top.values, top.indices)
    ]


# --- test it ---
if __name__ == "__main__":
    samples = [
        "This Agreement shall be governed by and construed in accordance with "
        "the laws of the State of New York.",
        "In no event shall either party be liable for any indirect, incidental, "
        "or consequential damages arising out of this Agreement.",
    ]
    for s in samples:
        print(f"\nProvision: {s[:70]}...")
        for r in classify_provision(s):
            print(f"  {r['category']} — {r['confidence']}%")
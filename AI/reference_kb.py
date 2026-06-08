"""
Curated, plain-English definitions for the 41 CUAD clause types.

This mirrors the `_clauseInfo` map in the Flutter app (chat_screen.dart) so that
"general mode" answers stay consistent with how the app explains the same clauses
on the document side. If you change the wording here, update it there too.

Used by rag.py to build a small reference vector store. When a user asks a
general question (no document uploaded), we retrieve the most relevant
definitions and ground the LLM's answer in them — falling back to the model's
own knowledge for anything outside these 41 types.
"""

# clause_type: (plain_name, lay_explanation, risk_level)
CLAUSE_DEFINITIONS = {
    # ── Key details ──────────────────────────────────────────────────────────
    "Document Name":   ("Type of contract", "Tells you what kind of agreement this actually is.", "low"),
    "Parties":         ("Who's involved", "The names of everyone signing this contract.", "low"),
    "Agreement Date":  ("Date signed", "The day this contract was put together.", "low"),
    "Effective Date":  ("Start date", "When the contract actually kicks in.", "low"),
    "Expiration Date": ("End date", "When the contract is set to end.", "low"),
    "Renewal Term":    ("Auto-renewal", "Whether the contract automatically renews itself.", "medium"),

    # ── Money & obligations ──────────────────────────────────────────────────
    "License Grant":           ("What you can use", "The specific rights you are being given (e.g. to use software or IP).", "low"),
    "Revenue/Profit Sharing":  ("Profit split", "How money or profits get divided between the parties.", "medium"),
    "Minimum Commitment":      ("Minimum you must spend", "A guaranteed minimum amount you have to pay or buy.", "medium"),
    "Volume Restriction":      ("Volume limits", "Caps on how much you can buy, sell or use.", "medium"),
    "Price Restrictions":      ("Pricing rules", "Limits on what you can charge or how prices can change.", "medium"),
    "Most Favored Nation":     ("Best-deal guarantee", "Promise that you get the best terms anyone else gets.", "medium"),
    "Unlimited/All-You-Can-Eat-License": ("Unlimited use", "Use as much as you want with no caps.", "low"),

    # ── Risk & liability ─────────────────────────────────────────────────────
    "Cap On Liability":    ("Damages limit", "Maximum amount you could be sued for if something goes wrong.", "medium"),
    "Uncapped Liability":  ("UNLIMITED liability", "No limit on how much you could owe — read this carefully.", "high"),
    "Liquidated Damages":  ("Pre-set penalties", "Specific dollar amounts you owe if you break the contract.", "high"),
    "Insurance":           ("Insurance required", "Type and amount of insurance you must carry.", "medium"),
    "Warranty Duration":   ("Warranty length", "How long the product or service is guaranteed for.", "low"),
    "Covenant Not To Sue": ("Can't sue", "You agree not to take legal action over certain things.", "high"),

    # ── Restrictions ─────────────────────────────────────────────────────────
    "Anti-Assignment":                   ("Can't transfer", "You may not give your contract rights to someone else.", "medium"),
    "Non-Compete":                       ("Can't compete", "You can't work for competitors or start a similar business.", "high"),
    "Exclusivity":                       ("Exclusive deal", "You must work only with this party — no competitors allowed.", "high"),
    "Non-Disparagement":                 ("No bad-mouthing", "You can't publicly criticize the other party.", "medium"),
    "No-Solicit Of Customers":           ("Can't poach customers", "You can't try to take their customers after the deal ends.", "medium"),
    "No-Solicit Of Employees":           ("Can't poach staff", "You can't try to hire away their employees.", "medium"),
    "Non-Transferable License":          ("License is yours alone", "You can't share or transfer the rights you got.", "medium"),
    "Competitive Restriction Exception": ("Compete-ban exception", "A specific carve-out from the non-compete rule.", "low"),

    # ── Ending the contract ──────────────────────────────────────────────────
    "Termination For Convenience":        ("Easy exit option", "Either side can end the contract for any reason with notice.", "medium"),
    "Notice Period To Terminate Renewal": ("Cancellation notice", "How early you must tell them you want out before auto-renewal.", "medium"),
    "Post-Termination Services":          ("After-end obligations", "What you still have to do after the contract ends.", "medium"),

    # ── Legal & governance ───────────────────────────────────────────────────
    "Governing Law":                   ("Which laws apply", "The state or country whose laws govern any disputes.", "medium"),
    "Audit Rights":                    ("Right to inspect records", "They can check your books or records for compliance.", "medium"),
    "Change Of Control":               ("What happens if sold", "What happens to the contract if your company is acquired.", "medium"),
    "Third Party Beneficiary":         ("Outside parties involved", "Someone not signing has rights under this contract.", "medium"),
    "Joint Ip Ownership":              ("Shared IP ownership", "Both parties co-own intellectual property created together.", "medium"),
    "Ip Ownership Assignment":         ("IP ownership transfer", "Who ends up owning the intellectual property.", "high"),
    "Source Code Escrow":              ("Code held by 3rd party", "Source code is kept by an escrow agent in case of issues.", "low"),
    "Affiliate License-Licensee":      ("Affiliate use", "Whether the licensee's affiliates can use the rights too.", "low"),
    "Affiliate License-Licensor":      ("Affiliate scope", "Whether the licensor's affiliates are part of the deal.", "low"),
    "Irrevocable Or Perpetual License": ("Forever license", "License that can't be taken back, ever.", "low"),
    "Rofr/Rofo/Rofn":                  ("First-right options", "Right to be offered something first before anyone else.", "medium"),
}


def reference_documents():
    """
    Yield (id, text) pairs for indexing into the reference vector store.

    Each text blob includes the formal clause name, the plain-English alias and
    the explanation so semantic search matches both "non-compete" and
    "can't work for competitors" style questions.
    """
    for clause_type, (plain_name, explanation, risk) in CLAUSE_DEFINITIONS.items():
        text = (
            f"{clause_type} (also called '{plain_name}'): {explanation} "
            f"Typical risk level: {risk}."
        )
        yield clause_type, text

// ── Layman-friendly clause metadata ─────────────────────────────────────────
//
// For each of the 41 CUAD clause types the model can detect, we store:
//   - a plain-English name (no legal jargon)
//   - a one-line explanation a non-lawyer can understand
//   - a risk level (low/medium/high) used to render a 🟢/🟡/🔴 dot
//   - a category used to group clauses into sections
//
// Shared by the chat screen (clause display) and the PDF report builder.
// Mirrors AI/reference_kb.py on the backend — keep the wording in sync.
// Edit these freely — they only affect how clauses are displayed, not how
// they're detected.

class ClauseInfo {
  final String plainName;
  final String layExplanation;
  final String category; // key | money | risk | restrict | exit | legal
  final String risk;     // low | medium | high
  const ClauseInfo(this.plainName, this.layExplanation, this.category, this.risk);
}

const Map<String, ClauseInfo> clauseInfo = {
  // ── Key details ──────────────────────────────────────────────────────────
  'Document Name':   ClauseInfo('Type of contract',  'Tells you what kind of agreement this actually is.', 'key', 'low'),
  'Parties':         ClauseInfo("Who's involved",    'The names of everyone signing this contract.', 'key', 'low'),
  'Agreement Date':  ClauseInfo('Date signed',       'The day this contract was put together.', 'key', 'low'),
  'Effective Date':  ClauseInfo('Start date',        'When the contract actually kicks in.', 'key', 'low'),
  'Expiration Date': ClauseInfo('End date',          'When the contract is set to end.', 'key', 'low'),
  'Renewal Term':    ClauseInfo('Auto-renewal',      'Whether the contract automatically renews itself.', 'key', 'medium'),

  // ── Money & obligations ──────────────────────────────────────────────────
  'License Grant':           ClauseInfo('What you can use',         'The specific rights you are being given (e.g. to use software or IP).', 'money', 'low'),
  'Revenue/Profit Sharing':  ClauseInfo('Profit split',             'How money or profits get divided between the parties.', 'money', 'medium'),
  'Minimum Commitment':      ClauseInfo('Minimum you must spend',   'A guaranteed minimum amount you have to pay or buy.', 'money', 'medium'),
  'Volume Restriction':      ClauseInfo('Volume limits',            'Caps on how much you can buy, sell or use.', 'money', 'medium'),
  'Price Restrictions':      ClauseInfo('Pricing rules',            'Limits on what you can charge or how prices can change.', 'money', 'medium'),
  'Most Favored Nation':     ClauseInfo('Best-deal guarantee',      'Promise that you get the best terms anyone else gets.', 'money', 'medium'),
  'Unlimited/All-You-Can-Eat-License': ClauseInfo('Unlimited use',  'Use as much as you want with no caps.', 'money', 'low'),

  // ── Risk & liability ─────────────────────────────────────────────────────
  'Cap On Liability':    ClauseInfo('Damages limit',         'Maximum amount you could be sued for if something goes wrong.', 'risk', 'medium'),
  'Uncapped Liability':  ClauseInfo('UNLIMITED liability',   'No limit on how much you could owe — read this carefully.', 'risk', 'high'),
  'Liquidated Damages':  ClauseInfo('Pre-set penalties',     'Specific dollar amounts you owe if you break the contract.', 'risk', 'high'),
  'Insurance':           ClauseInfo('Insurance required',    'Type and amount of insurance you must carry.', 'risk', 'medium'),
  'Warranty Duration':   ClauseInfo('Warranty length',       'How long the product or service is guaranteed for.', 'risk', 'low'),
  'Covenant Not To Sue': ClauseInfo("Can't sue",             'You agree not to take legal action over certain things.', 'risk', 'high'),

  // ── Restrictions ─────────────────────────────────────────────────────────
  'Anti-Assignment':                  ClauseInfo("Can't transfer",          "You may not give your contract rights to someone else.", 'restrict', 'medium'),
  'Non-Compete':                      ClauseInfo("Can't compete",           "You can't work for competitors or start a similar business.", 'restrict', 'high'),
  'Exclusivity':                      ClauseInfo('Exclusive deal',          'You must work only with this party — no competitors allowed.', 'restrict', 'high'),
  'Non-Disparagement':                ClauseInfo('No bad-mouthing',         "You can't publicly criticize the other party.", 'restrict', 'medium'),
  'No-Solicit Of Customers':          ClauseInfo("Can't poach customers",   "You can't try to take their customers after the deal ends.", 'restrict', 'medium'),
  'No-Solicit Of Employees':          ClauseInfo("Can't poach staff",       "You can't try to hire away their employees.", 'restrict', 'medium'),
  'Non-Transferable License':         ClauseInfo('License is yours alone',  "You can't share or transfer the rights you got.", 'restrict', 'medium'),
  'Competitive Restriction Exception':ClauseInfo('Compete-ban exception',   'A specific carve-out from the non-compete rule.', 'restrict', 'low'),

  // ── Ending the contract ──────────────────────────────────────────────────
  'Termination For Convenience':       ClauseInfo('Easy exit option',     'Either side can end the contract for any reason with notice.', 'exit', 'medium'),
  'Notice Period To Terminate Renewal':ClauseInfo('Cancellation notice',  'How early you must tell them you want out before auto-renewal.', 'exit', 'medium'),
  'Post-Termination Services':         ClauseInfo('After-end obligations','What you still have to do after the contract ends.', 'exit', 'medium'),

  // ── Legal & governance ───────────────────────────────────────────────────
  'Governing Law':                  ClauseInfo('Which laws apply',         'The state or country whose laws govern any disputes.', 'legal', 'medium'),
  'Audit Rights':                   ClauseInfo('Right to inspect records', 'They can check your books or records for compliance.', 'legal', 'medium'),
  'Change Of Control':              ClauseInfo('What happens if sold',     'What happens to the contract if your company is acquired.', 'legal', 'medium'),
  'Third Party Beneficiary':        ClauseInfo('Outside parties involved', 'Someone not signing has rights under this contract.', 'legal', 'medium'),
  'Joint Ip Ownership':             ClauseInfo('Shared IP ownership',      'Both parties co-own intellectual property created together.', 'legal', 'medium'),
  'Ip Ownership Assignment':        ClauseInfo('IP ownership transfer',    'Who ends up owning the intellectual property.', 'legal', 'high'),
  'Source Code Escrow':             ClauseInfo('Code held by 3rd party',   'Source code is kept by an escrow agent in case of issues.', 'legal', 'low'),
  'Affiliate License-Licensee':     ClauseInfo('Affiliate use',            "Whether the licensee's affiliates can use the rights too.", 'legal', 'low'),
  'Affiliate License-Licensor':     ClauseInfo('Affiliate scope',          "Whether the licensor's affiliates are part of the deal.", 'legal', 'low'),
  'Irrevocable Or Perpetual License':ClauseInfo('Forever license',         "License that can't be taken back, ever.", 'legal', 'low'),
  'Rofr/Rofo/Rofn':                 ClauseInfo('First-right options',      'Right to be offered something first before anyone else.', 'legal', 'medium'),
};
